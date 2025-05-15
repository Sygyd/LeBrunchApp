const express = require("express");
const pool = require("./db");
const router = express.Router();
const { FOOD_CATEGORIES, DRINK_CATEGORIES } = require("./constants");

// Obtener todos los pedidos con filtros opcionales
router.get("/pedidos", async (req, res) => {
  try {
    const { startDate, endDate, estado } = req.query;
    
    // Base de la consulta
    let query = `
      SELECT p.idpedido, p.idpersona, p.estado, 
             TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha, 
             TO_CHAR(p.fecha, 'HH24:MI') as hora,
             pe.nombre || ' ' || pe.apellido as cliente
      FROM pedidos p
      INNER JOIN personas pe ON p.idpersona = pe.idpersonas
      WHERE 1=1
    `;
    
    const queryParams = [];
    
    // Agregar filtros a la consulta si se proporcionan
    if (startDate) {
      queryParams.push(startDate);
      query += ` AND p.fecha >= $${queryParams.length}::date`;
    }
    
    if (endDate) {
      queryParams.push(endDate);
      query += ` AND p.fecha <= $${queryParams.length}::date + interval '1 day'`;
    }
    
    if (estado) {
      queryParams.push(estado);
      query += ` AND p.estado = $${queryParams.length}`;
    }
    
    // Ordenar por fecha descendente (más recientes primero)
    query += ` ORDER BY p.fecha DESC`;
    
    // Ejecutar la consulta
    const { rows: pedidos } = await pool.query(query, queryParams);
    
    // Si no hay pedidos, devolver arreglo vacío
    if (pedidos.length === 0) {
      return res.status(200).json([]);
    }
    
    // Obtener detalles de cada pedido en un solo paso
    const pedidosIds = pedidos.map(p => p.idpedido);
    const { rows: detalles } = await pool.query(
      `SELECT pd.idpedido, pd.idplato, pd.cantidad, pd.precio_unitario, 
              m.nombre as nombre
       FROM pedido_detalle pd
       INNER JOIN menu m ON pd.idplato = m.idplato
       WHERE pd.idpedido = ANY($1)`,
      [pedidosIds]
    );
    
    // Agrupar detalles por pedido y calcular totales
    const resultado = pedidos.map(pedido => {
      const itemsPedido = detalles.filter(d => d.idpedido === pedido.idpedido);
      
      // Calcular total
      let total = 0;
      itemsPedido.forEach(item => {
        total += item.cantidad * item.precio_unitario;
      });
      
      // Formatear los items
      const items = itemsPedido.map(item => ({
        nombre: item.nombre,
        cantidad: item.cantidad,
        precio_unitario: parseFloat(item.precio_unitario)
      }));
      
      return {
        ...pedido,
        total: parseFloat(total.toFixed(2)),
        items
      };
    });
    
    return res.status(200).json(resultado);
    
  } catch (error) {
    console.error("❌ Error al obtener pedidos:", error);
    return res.status(500).json({
      error: "Error al obtener pedidos",
      details: error.message
    });
  }
});

// Crear nuevo pedido
router.post("/pedidos", async (req, res) => {
  try {
    const { idpersona, estado, items } = req.body;
    
    console.log("📝 Recibida solicitud de creación de pedido");
    console.log(`📝 Usuario ID: ${idpersona}`);
    console.log(`📝 Estado inicial: ${estado || 'pendiente'}`);
    console.log(`📝 Items: ${items ? items.length : 0}`);
    
    // Validaciones básicas
    if (!idpersona) {
      return res.status(400).json({ error: "ID de persona es requerido" });
    }
    
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: "Se requiere al menos un item en el pedido" });
    }
    
    // Iniciar transacción
    await pool.query('BEGIN');
    
    // 1. Insertar el pedido principal
    const pedidoResult = await pool.query(
      "INSERT INTO pedidos (idpersona, estado, fecha) VALUES ($1, $2, NOW()) RETURNING idpedido",
      [idpersona, estado || 'pendiente']
    );
    
    if (pedidoResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(500).json({ error: "Error al crear el pedido" });
    }
    
    const idpedido = pedidoResult.rows[0].idpedido;
    console.log(`📝 Pedido creado con ID: ${idpedido}`);
    
    // 2. Insertar cada detalle del pedido
    for (const item of items) {
      const { idplato, cantidad, precio_unitario } = item;
      
      if (!idplato || !cantidad || !precio_unitario) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ 
          error: "Cada item debe tener idplato, cantidad y precio_unitario" 
        });
      }
      
      console.log(`📝 Insertando item: plato=${idplato}, cantidad=${cantidad}, precio=${precio_unitario}`);
      
      await pool.query(
        "INSERT INTO pedido_detalle (idpedido, idplato, cantidad, precio_unitario) VALUES ($1, $2, $3, $4)",
        [idpedido, idplato, cantidad, precio_unitario]
      );
    }
    
    // Confirmar transacción
    await pool.query('COMMIT');
    console.log(`✅ Pedido ${idpedido} creado exitosamente`);
    
    // Devolver datos del pedido creado
    return res.status(201).json({
      idpedido,
      idpersona,
      estado: estado || 'pendiente',
      fecha: new Date().toISOString(),
      items: items.length
    });
    
  } catch (error) {
    // Rollback en caso de error
    await pool.query('ROLLBACK');
    console.error("❌ Error al crear pedido:", error);
    return res.status(500).json({
      error: "Error al crear el pedido",
      details: error.message
    });
  }
});

// Actualizar estado de un pedido
router.patch("/pedidos/:id/estado", async (req, res) => {
  try {
    const { id } = req.params;
    const { estado } = req.body;
    
    if (!estado) {
      return res.status(400).json({ error: "Se requiere el estado del pedido" });
    }
    
    const estadosValidos = ['pendiente', 'completado', 'cancelado'];
    if (!estadosValidos.includes(estado)) {
      return res.status(400).json({ 
        error: `Estado no válido. Debe ser uno de: ${estadosValidos.join(', ')}` 
      });
    }
    
    // Iniciar transacción
    await pool.query('BEGIN');
    
    // Obtener el estado actual del pedido
    const currentStateResult = await pool.query(
      "SELECT estado, fecha FROM pedidos WHERE idpedido = $1",
      [id]
    );
    
    if (currentStateResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ error: "Pedido no encontrado" });
    }
    
    const currentState = currentStateResult.rows[0].estado;
    const fechaInicial = currentStateResult.rows[0].fecha;
    
    let updateResult;
    
    // Si el pedido está cambiando de pendiente a completado o cancelado,
    // registrar el tiempo de procesamiento
    if (currentState === 'pendiente' && (estado === 'completado' || estado === 'cancelado')) {
      console.log(`📝 Registrando tiempo de procesamiento para pedido #${id}: ${currentState} -> ${estado}`);
      
      // Actualizar estado y calcular tiempo de procesamiento en la misma consulta
      updateResult = await pool.query(
        `UPDATE pedidos SET 
          estado = $1,
          tiempo_procesamiento = NOW() - fecha::timestamp
         WHERE idpedido = $2 
         RETURNING *`,
        [estado, id]
      );
      
      console.log('✅ Estado actualizado y tiempo de procesamiento registrado');
    } else {
      // Para otros cambios de estado, solo actualizar el estado
      updateResult = await pool.query(
        "UPDATE pedidos SET estado = $1 WHERE idpedido = $2 RETURNING *",
        [estado, id]
      );
    }
    
    // Confirmar transacción
    await pool.query('COMMIT');
    
    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: "Pedido no encontrado" });
    }
    
    return res.status(200).json({
      message: "Estado del pedido actualizado correctamente",
      pedido: updateResult.rows[0],
      tiempoRegistrado: currentState === 'pendiente' && (estado === 'completado' || estado === 'cancelado')
    });
    
  } catch (error) {
    // Rollback en caso de error
    await pool.query('ROLLBACK');
    console.error("❌ Error al actualizar estado del pedido:", error);
    return res.status(500).json({
      error: "Error al actualizar estado del pedido",
      details: error.message
    });
  }
});

// Conteo de pedidos por estado
router.get("/pedidos/stats/count", async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN estado = 'pendiente' THEN 1 END) as pendientes,
        COUNT(CASE WHEN estado = 'preparando' THEN 1 END) as preparando,
        COUNT(CASE WHEN estado = 'listo' THEN 1 END) as listos,
        COUNT(CASE WHEN estado = 'completado' THEN 1 END) as completados,
        COUNT(CASE WHEN estado = 'cancelado' THEN 1 END) as cancelados
      FROM pedidos
    `);
    
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error("❌ Error al obtener estadísticas de pedidos:", error);
    return res.status(500).json({
      error: "Error al obtener estadísticas de pedidos",
      details: error.message
    });
  }
});

// Obtener número de pedidos pendientes
router.get("/pedidos/pendientes/count", async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT COUNT(*) as count FROM pedidos WHERE estado = 'pendiente'"
    );
    
    return res.status(200).json({
      count: parseInt(rows[0].count),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("❌ Error al obtener número de pedidos pendientes:", error);
    return res.status(500).json({ 
      error: "Error al obtener número de pedidos pendientes",
      details: error.message 
    });
  }
});

// Obtener ventas del día actual
router.get("/pedidos/ventas/hoy", async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT COALESCE(SUM(pd.precio_unitario * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido WHERE DATE(p.fecha) = CURRENT_DATE AND p.estado = 'completado'"
    );
    
    return res.status(200).json({
      total: parseFloat(rows[0].total),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("❌ Error al obtener ventas del día:", error);
    return res.status(500).json({ 
      error: "Error al obtener ventas del día",
      details: error.message 
    });
  }
});

// Obtener ventas por rango de fechas
router.get("/pedidos/ventas/rango", async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    if (!startDate || !endDate) {
      return res.status(400).json({ 
        error: "Se requieren las fechas de inicio y fin" 
      });
    }
    
    const { rows } = await pool.query(
      `SELECT 
        COALESCE(SUM(pd.precio_unitario * pd.cantidad), 0) as total,
        COUNT(DISTINCT p.idpedido) as cantidad_pedidos
      FROM 
        pedidos p 
      JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido 
      WHERE 
        DATE(p.fecha) >= $1::date AND DATE(p.fecha) <= $2::date`,
      [startDate, endDate]
    );
    
    return res.status(200).json({
      total: parseFloat(rows[0].total),
      cantidad_pedidos: parseInt(rows[0].cantidad_pedidos),
      rango: {
        inicio: startDate,
        fin: endDate
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("❌ Error al obtener ventas por rango:", error);
    return res.status(500).json({ 
      error: "Error al obtener ventas por rango de fechas",
      details: error.message 
    });
  }
});

// Obtener los platos más vendidos
router.get("/pedidos/stats/mas-vendidos", async (req, res) => {
  try {
    const { limit = 5, startDate, endDate, period, categoria } = req.query;
    
    // Construir la consulta base
    let query = `
      WITH ventas_platos AS (
        SELECT 
          pd.idplato,
          SUM(pd.cantidad) as cantidad_vendida,
          AVG(pd.precio_unitario) as precio_promedio
        FROM 
          pedido_detalle pd
        INNER JOIN 
          pedidos p ON pd.idpedido = p.idpedido
        INNER JOIN 
          menu m ON pd.idplato = m.idplato
        WHERE 
          p.estado = 'completado'
    `;

    const queryParams = [];
    let paramCounter = 1;

    // Agregar filtros de fecha
    if (startDate) {
      queryParams.push(startDate);
      query += ` AND p.fecha >= $${paramCounter}::date`;
      paramCounter++;
    }
    
    if (endDate) {
      queryParams.push(endDate);
      query += ` AND p.fecha <= $${paramCounter}::date + interval '1 day'`;
      paramCounter++;
    }

    // Agregar filtro de categoría
    if (categoria === 'comida') {
      query += ` AND LOWER(m.categoria) IN ('tablas', 'panquecas', 'tostadas francesas', 'gofres', 'omelettes')`;
    } else if (categoria === 'bebida') {
      query += ` AND m.categoria IN ('Expresos', 'Frapuccinos', 'Cold Brew', 'Jugos')`;
    }

    // Completar la primera parte de la consulta
    query += `
        GROUP BY 
          pd.idplato
      )
      SELECT 
        m.idplato,
        m.nombre,
        m.categoria,
        m.precio,
        COALESCE(vp.cantidad_vendida, 0) as cantidad_vendida,
        COALESCE(vp.precio_promedio, m.precio) as precio_promedio
      FROM 
        menu m
      LEFT JOIN 
        ventas_platos vp ON m.idplato = vp.idplato
      WHERE 
        COALESCE(vp.cantidad_vendida, 0) > 0
    `;

    // Agregar el mismo filtro de categoría en la segunda parte
    if (categoria === 'comida') {
      query += ` AND LOWER(m.categoria) IN ('tablas', 'panquecas', 'tostadas francesas', 'gofres', 'omelettes')`;
    } else if (categoria === 'bebida') {
      query += ` AND m.categoria IN ('Expresos', 'Frapuccinos', 'Cold Brew', 'Jugos')`;
    }

    // Agregar ordenamiento y límite
    queryParams.push(limit);
    query += `
      ORDER BY 
        vp.cantidad_vendida DESC NULLS LAST
      LIMIT $${paramCounter}
    `;

    console.log('📊 Consulta de platos populares:', query);
    console.log('📊 Parámetros:', queryParams);
    
    const { rows } = await pool.query(query, queryParams);
    
    // Formatear resultados
    const formattedRows = rows.map(row => ({
      ...row,
      precio_promedio: parseFloat(row.precio_promedio),
      cantidad_vendida: parseInt(row.cantidad_vendida)
    }));
    
    console.log(`📊 Platos populares encontrados: ${formattedRows.length}`);
    
    return res.status(200).json(formattedRows);
  } catch (error) {
    console.error("❌ Error al obtener platos más vendidos:", error);
    return res.status(500).json({
      error: "Error al obtener platos más vendidos",
      details: error.message
    });
  }
});

// Obtener ventas por hora del día
router.get("/pedidos/stats/ventas-por-hora", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT 
        EXTRACT(HOUR FROM p.fecha) as hora,
        COUNT(DISTINCT p.idpedido) as cantidad_pedidos,
        SUM(pd.cantidad * pd.precio_unitario) as total_ventas
      FROM 
        pedidos p
      JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      WHERE 
        DATE(p.fecha) = CURRENT_DATE
      GROUP BY 
        hora
      ORDER BY 
        hora`
    );
    
    // Formatear resultados
    const formattedRows = rows.map(row => ({
      hora: parseInt(row.hora),
      cantidad_pedidos: parseInt(row.cantidad_pedidos),
      total_ventas: parseFloat(row.total_ventas)
    }));
    
    return res.status(200).json(formattedRows);
  } catch (error) {
    console.error("❌ Error al obtener ventas por hora:", error);
    return res.status(500).json({
      error: "Error al obtener ventas por hora",
      details: error.message
    });
  }
});

// Obtener resumen de pedidos por período
router.get("/pedidos/resumen", async (req, res) => {
  try {
    const { period, startDate, endDate, categoria } = req.query;
    
    console.log(`📊 Solicitud de resumen de pedidos: período=${period || 'N/A'}, fechas=${startDate || 'N/A'} a ${endDate || 'N/A'}, categoría=${categoria || 'todos'}`);

    // Determinar fechas según el periodo
    let fechaInicio, fechaFin;
    const hoy = new Date();
    
    // Si se proporcionan fechas futuras, mostrar datos históricos de los últimos 30 días
    if (startDate) {
      fechaInicio = new Date(`${startDate}T00:00:00`);
      if (fechaInicio > hoy) {
        console.log('⚠️ Fecha de inicio futura detectada, ajustando a los últimos 30 días');
        fechaInicio = new Date(hoy);
        fechaInicio.setDate(hoy.getDate() - 30);
      }
    }
    
    if (endDate) {
      fechaFin = new Date(`${endDate}T23:59:59`);
      if (fechaFin > hoy) {
        console.log('⚠️ Fecha fin futura detectada, ajustando al día actual');
        fechaFin = new Date(hoy);
        fechaFin.setHours(23, 59, 59, 999);
      }
    } else {
      fechaFin = new Date(hoy);
      fechaFin.setHours(23, 59, 59, 999);
    }

    // Si no se proporcionaron fechas, usar el periodo
    if (!startDate && !endDate) {
      switch (period) {
        case 'day':
          fechaInicio = new Date(hoy);
          fechaInicio.setHours(0, 0, 0, 0);
          break;
        case 'week':
          fechaInicio = new Date(hoy);
          fechaInicio.setDate(hoy.getDate() - 7);
          break;
        case 'month':
          fechaInicio = new Date(hoy);
          fechaInicio.setMonth(hoy.getMonth() - 1);
          break;
        case 'year':
          fechaInicio = new Date(hoy);
          fechaInicio.setFullYear(hoy.getFullYear() - 1);
          break;
        default:
          fechaInicio = new Date(hoy);
          fechaInicio.setDate(hoy.getDate() - 30); // Por defecto mostrar últimos 30 días
          fechaInicio.setHours(0, 0, 0, 0);
      }
    }

    console.log(`📅 Fechas ajustadas: inicio=${fechaInicio.toISOString()}, fin=${fechaFin.toISOString()}`);

    // Condición para filtrar por categoría
    const categoriaCondition = categoria && categoria !== 'todos'
      ? `AND LOWER(m.tipo) = '${categoria.toLowerCase()}'`
      : '';

    // Consulta para el resumen general
    const resumenQuery = `
      WITH pedidos_totales AS (
        SELECT 
          p.idpedido,
          SUM(pd.cantidad * pd.precio_unitario) as total_pedido
        FROM 
          pedidos p
          INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
          INNER JOIN menu m ON pd.idplato = m.idplato
        WHERE 
          p.fecha >= $1 AND p.fecha <= $2
          AND p.estado = 'completado'
          ${categoriaCondition}
        GROUP BY 
          p.idpedido
      )
      SELECT 
        COUNT(DISTINCT pt.idpedido) as total_pedidos,
        COALESCE(SUM(pt.total_pedido), 0) as total_ventas,
        COALESCE(MIN(pt.total_pedido), 0) as min_pedido,
        COALESCE(MAX(pt.total_pedido), 0) as max_pedido
      FROM 
        pedidos_totales pt`;

    // Consulta para ventas por hora
    const ventasPorHoraQuery = `
      SELECT 
        EXTRACT(HOUR FROM p.fecha)::integer as hora,
        COUNT(DISTINCT p.idpedido) as total_pedidos,
        COALESCE(SUM(pd.cantidad * pd.precio_unitario), 0) as total_ventas
      FROM 
        pedidos p
        INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
        INNER JOIN menu m ON pd.idplato = m.idplato
      WHERE 
        p.fecha >= $1 AND p.fecha <= $2
        AND p.estado = 'completado'
        ${categoriaCondition}
      GROUP BY 
        hora
      ORDER BY 
        hora`;

    // Consulta para ventas por categoría
    const ventasPorCategoriaQuery = `
      SELECT 
        m.categoria,
        COUNT(DISTINCT p.idpedido) as total_pedidos,
        COALESCE(SUM(pd.cantidad * pd.precio_unitario), 0) as total_ventas
      FROM 
        pedidos p
        INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
        INNER JOIN menu m ON pd.idplato = m.idplato
      WHERE 
        p.fecha >= $1 AND p.fecha <= $2
        AND p.estado = 'completado'
        ${categoriaCondition}
      GROUP BY 
        m.categoria
      ORDER BY 
        total_ventas DESC`;

    // Consulta para ticket promedio por día
    const ticketPromedioPorDiaQuery = `
      SELECT 
        EXTRACT(DOW FROM p.fecha) as dia_semana,
        COUNT(DISTINCT p.idpedido) as total_pedidos,
        SUM(pd.cantidad * pd.precio_unitario) as total_ventas,
        ROUND(AVG(subquery.total_pedido), 2) as ticket_promedio
      FROM 
        pedidos p
        INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
        INNER JOIN menu m ON pd.idplato = m.idplato
        INNER JOIN (
          SELECT 
            pd2.idpedido,
            SUM(pd2.cantidad * pd2.precio_unitario) as total_pedido
          FROM 
            pedido_detalle pd2
          GROUP BY 
            pd2.idpedido
        ) subquery ON p.idpedido = subquery.idpedido
      WHERE 
        p.fecha >= $1 AND p.fecha <= $2
        AND p.estado = 'completado'
        ${categoriaCondition}
      GROUP BY 
        dia_semana
      ORDER BY 
        dia_semana`;

    // Ejecutar todas las consultas
    const [resumenResult, ventasPorHora, ventasPorCategoria, ticketPromedioPorDia] = await Promise.all([
      pool.query(resumenQuery, [fechaInicio, fechaFin]),
      pool.query(ventasPorHoraQuery, [fechaInicio, fechaFin]),
      pool.query(ventasPorCategoriaQuery, [fechaInicio, fechaFin]),
      pool.query(ticketPromedioPorDiaQuery, [fechaInicio, fechaFin])
    ]);

    // Función auxiliar para formatear fechas
    const formatoFecha = (fecha) => {
      return fecha.toISOString().split('T')[0];
    };

    // Inicializar el objeto de respuesta
    const resumen = {
      totalPedidos: parseInt(resumenResult.rows[0].total_pedidos) || 0,
      totalVentas: parseFloat(resumenResult.rows[0].total_ventas) || 0,
      ticketPromedio: 0,
      minPedido: parseFloat(resumenResult.rows[0].min_pedido) || 0,
      maxPedido: parseFloat(resumenResult.rows[0].max_pedido) || 0,
      periodo: {
        inicio: formatoFecha(fechaInicio),
        fin: formatoFecha(fechaFin),
        tipo: period || 'custom'
      },
      ventasPorHora: ventasPorHora.rows,
      ventasPorCategoria: ventasPorCategoria.rows,
      ticketPromedioPorDia: ticketPromedioPorDia.rows
    };

    // Calcular ticket promedio si hay pedidos
    if (resumen.totalPedidos > 0) {
      resumen.ticketPromedio = parseFloat((resumen.totalVentas / resumen.totalPedidos).toFixed(2));
    }

    console.log('✅ Resumen generado con éxito:', resumen);
    return res.status(200).json(resumen);

  } catch (error) {
    console.error('❌ Error al generar resumen:', error);
    return res.status(500).json({ error: 'Error al generar resumen de pedidos' });
  }
});

// Obtener tiempo promedio de procesamiento de pedidos por día
router.get("/pedidos/tiempo/promedio", async (req, res) => {
  try {
    console.log("⏱️ Solicitud de tiempo promedio de procesamiento recibida");
    
    // Consulta optimizada para obtener el tiempo promedio de hoy
    const { rows } = await pool.query(`
      SELECT 
        COUNT(*) as count,
        EXTRACT(EPOCH FROM AVG(
          CASE 
            WHEN tiempo_procesamiento IS NOT NULL THEN tiempo_procesamiento
            ELSE interval '15 minutes'
          END
        )) as promedio_segundos
      FROM 
        pedidos
      WHERE 
        estado = 'completado' 
        AND DATE(fecha) = CURRENT_DATE
    `);
    
    if (rows.length > 0) {
      const count = parseInt(rows[0].count, 10) || 0;
      const promedioSegundos = parseFloat(rows[0].promedio_segundos) || 0;
      const promedioMinutos = promedioSegundos / 60;
      
      console.log(`⏱️ Encontrados ${count} pedidos completados hoy`);
      console.log(`⏱️ Tiempo promedio: ${promedioMinutos.toFixed(2)} minutos`);
      
      return res.status(200).json({
        count,
        promedio_segundos: promedioSegundos,
        promedio_minutos: promedioMinutos
      });
    }
    
    // Si no hay resultados, devolver valores por defecto
    return res.status(200).json({
      count: 0,
      promedio_segundos: 0,
      promedio_minutos: 0
    });
    
  } catch (error) {
    console.error("❌ Error al obtener tiempo promedio:", error);
    return res.status(500).json({
      error: "Error al obtener tiempo promedio de procesamiento",
      details: error.message
    });
  }
});

// Obtener un pedido específico por ID - ESTA RUTA DEBE IR AL FINAL DE TODAS LAS DEMÁS RUTAS DE PEDIDOS
router.get("/pedidos/:id", async (req, res) => {
  try {
    const { id } = req.params;

    // Verificar explícitamente si la ruta es para 'resumen' y rechazarla apropiadamente
    if (id === 'resumen') {
      console.error("❌ Error: Intentando acceder a /pedidos/resumen a través de la ruta de ID");
      return res.status(400).json({ 
        error: `Parece que estás intentando acceder a la ruta de resumen. Usa /pedidos/resumen en lugar de /pedidos/:id`
      });
    }
    
    // Intentar convertir el ID a un número entero
    const pedidoId = parseInt(id);
    if (isNaN(pedidoId)) {
      console.error(`❌ ID de pedido inválido recibido: "${id}"`);
      return res.status(400).json({ 
        error: `ID de pedido inválido: "${id}". Se esperaba un número entero.`
      });
    }
    
    // Obtener datos del pedido
    const pedidoResult = await pool.query(
      `SELECT p.idpedido, p.idpersona, p.estado, 
              TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha, 
              TO_CHAR(p.fecha, 'HH24:MI') as hora,
              pe.nombre || ' ' || pe.apellido as cliente
       FROM pedidos p
       INNER JOIN personas pe ON p.idpersona = pe.idpersonas
       WHERE p.idpedido = $1`,
      [pedidoId]
    );
    
    if (pedidoResult.rows.length === 0) {
      return res.status(404).json({ error: "Pedido no encontrado" });
    }
    
    const pedido = pedidoResult.rows[0];
    
    // Obtener detalles del pedido
    const detallesResult = await pool.query(
      `SELECT pd.idplato, pd.cantidad, pd.precio_unitario, pd.notas,
              m.nombre as nombre, m.imagen_url
       FROM pedido_detalle pd
       INNER JOIN menu m ON pd.idplato = m.idplato
       WHERE pd.idpedido = $1`,
      [pedidoId]
    );
    
    // Calcular total y formatear items
    let total = 0;
    const items = detallesResult.rows.map(item => {
      const subtotal = item.cantidad * item.precio_unitario;
      total += subtotal;
      
      return {
        nombre: item.nombre,
        cantidad: item.cantidad,
        precio_unitario: parseFloat(item.precio_unitario),
        notas: item.notas,
        imagen_url: item.imagen_url,
        subtotal: parseFloat(subtotal.toFixed(2))
      };
    });
    
    return res.status(200).json({
      ...pedido,
      total: parseFloat(total.toFixed(2)),
      items
    });
    
  } catch (error) {
    console.error("❌ Error al obtener pedido:", error);
    return res.status(500).json({
      error: "Error al obtener pedido",
      details: error.message
    });
  }
});

module.exports = router; 