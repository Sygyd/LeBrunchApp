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
      `SELECT pd.idpedido, pd.idplato, pd.cantidad, 
              m.nombre as nombre, m.precio as precio_unitario
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
      const { idplato, cantidad, notas } = item;
      
      if (!idplato || !cantidad) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ 
          error: "Cada item debe tener idplato y cantidad" 
        });
      }
      
      console.log(`📝 Insertando item: plato=${idplato}, cantidad=${cantidad}, notas="${notas || ''}"`);
      
      await pool.query(
        "INSERT INTO pedido_detalle (idpedido, idplato, cantidad, notas) VALUES ($1, $2, $3, $4)",
        [idpedido, idplato, cantidad, notas || '']
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
      "SELECT COALESCE(SUM(m.precio * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido JOIN menu m ON pd.idplato = m.idplato WHERE DATE(p.fecha) = CURRENT_DATE AND p.estado = 'completado'"
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
        COALESCE(SUM(m.precio * pd.cantidad), 0) as total,
        COUNT(DISTINCT p.idpedido) as cantidad_pedidos
      FROM 
        pedidos p 
      JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido 
      JOIN 
        menu m ON pd.idplato = m.idplato
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

// Obtener los platos más vendidos - VERSIÓN OPTIMIZADA
router.get("/pedidos/stats/mas-vendidos", async (req, res) => {
  try {
    const { limit = 5, startDate, endDate, period, categoria } = req.query;
    
    console.log(`📊 [OPTIMIZADO] Solicitud de platos populares recibida:`);
    console.log(`   📅 Fechas recibidas: ${startDate} a ${endDate}`);
    console.log(`   📅 Período: ${period}`);
    console.log(`   🎯 Categoría: ${categoria}`);
    
    // PASO 1: Obtener el rango de fechas reales de la base de datos
    const fechasRealesQuery = `
      SELECT 
        MIN(DATE(fecha)) as fecha_minima,
        MAX(DATE(fecha)) as fecha_maxima,
        COUNT(*) as total_pedidos
      FROM pedidos 
      WHERE estado = 'completado'
    `;
    
    const fechasRealesResult = await pool.query(fechasRealesQuery);
    const { fecha_minima, fecha_maxima, total_pedidos } = fechasRealesResult.rows[0];
    
    console.log(`📊 [OPTIMIZADO] Datos reales en BD:`);
    console.log(`   📅 Rango real: ${fecha_minima} a ${fecha_maxima}`);
    console.log(`   📊 Total pedidos completados: ${total_pedidos}`);
    
    // Si no hay datos, devolver array vacío
    if (!fecha_minima || !fecha_maxima || total_pedidos === '0') {
      console.log(`📊 [OPTIMIZADO] No hay datos de ventas en la base de datos`);
      return res.status(200).json([]);
    }
    
    // PASO 2: Determinar fechas de consulta basadas en datos reales
    let fechaInicio, fechaFin;
    const fechaMaxReal = new Date(fecha_maxima);
    const fechaMinReal = new Date(fecha_minima);
    
    // Si se proporcionan fechas específicas, validarlas contra datos reales
    if (startDate && endDate) {
      const startDateObj = new Date(startDate);
      const endDateObj = new Date(endDate);
      
      // Ajustar fechas al rango real disponible
      fechaInicio = startDateObj < fechaMinReal ? fechaMinReal : startDateObj;
      fechaFin = endDateObj > fechaMaxReal ? fechaMaxReal : endDateObj;
      
      console.log(`📊 [OPTIMIZADO] Fechas ajustadas al rango real: ${fechaInicio.toISOString().split('T')[0]} a ${fechaFin.toISOString().split('T')[0]}`);
    } else {
      // Usar período basado en datos reales
      fechaFin = fechaMaxReal;
      
      switch (period) {
        case 'day':
        case 'hoy':
          fechaInicio = fechaMaxReal;
          break;
        case 'week':
        case 'semana':
          fechaInicio = new Date(fechaMaxReal);
          fechaInicio.setDate(fechaInicio.getDate() - 7);
          if (fechaInicio < fechaMinReal) fechaInicio = fechaMinReal;
          break;
        case 'month':
        case 'mes':
          fechaInicio = new Date(fechaMaxReal);
          fechaInicio.setDate(fechaInicio.getDate() - 30);
          if (fechaInicio < fechaMinReal) fechaInicio = fechaMinReal;
          break;
        case 'year':
        case 'año':
          fechaInicio = new Date(fechaMaxReal);
          fechaInicio.setDate(fechaInicio.getDate() - 365);
          if (fechaInicio < fechaMinReal) fechaInicio = fechaMinReal;
          break;
        default:
          // Para 'all' o sin período, usar todo el rango disponible
          fechaInicio = fechaMinReal;
          fechaFin = fechaMaxReal;
      }
      
      console.log(`📊 [OPTIMIZADO] Período '${period}' convertido a fechas reales: ${fechaInicio.toISOString().split('T')[0]} a ${fechaFin.toISOString().split('T')[0]}`);
    }
    
    // PASO 3: Construir consulta optimizada
    let query = `
      WITH ventas_reales AS (
        SELECT 
          pd.idplato,
          SUM(pd.cantidad) as cantidad_vendida,
          COUNT(DISTINCT p.idpedido) as pedidos_distintos,
          AVG(m.precio) as precio_promedio,
          SUM(pd.cantidad * m.precio) as ingresos_totales
        FROM 
          pedido_detalle pd
        INNER JOIN 
          pedidos p ON pd.idpedido = p.idpedido
        INNER JOIN 
          menu m ON pd.idplato = m.idplato
        WHERE 
          p.estado = 'completado'
          AND DATE(p.fecha) >= $1
          AND DATE(p.fecha) <= $2
          AND m.isDelete = FALSE
    `;

    const queryParams = [
      fechaInicio.toISOString().split('T')[0],
      fechaFin.toISOString().split('T')[0]
    ];
    let paramCounter = 3;

    // Agregar filtro de categoría optimizado
    if (categoria === 'comida') {
      query += ` AND m.tipo = 'comida'`;
    } else if (categoria === 'bebida') {
      query += ` AND m.tipo = 'bebida'`;
    } else if (categoria && categoria !== 'todos' && categoria !== 'null') {
      // Filtro por categoría específica (ej: "Omelettes")
      queryParams.push(categoria);
      query += ` AND m.categoria = $${paramCounter}`;
      paramCounter++;
    }

    // Completar la consulta
    query += `
        GROUP BY 
          pd.idplato, m.precio
      )
      SELECT 
        m.idplato,
        m.nombre,
        m.categoria,
        m.precio,
        m.imagen_url,
        m.tipo,
        COALESCE(vr.cantidad_vendida, 0) as cantidad_vendida,
        COALESCE(vr.pedidos_distintos, 0) as pedidos_distintos,
        COALESCE(vr.precio_promedio, m.precio) as precio_promedio,
        COALESCE(vr.ingresos_totales, 0) as ingresos_totales
      FROM 
        menu m
      LEFT JOIN 
        ventas_reales vr ON m.idplato = vr.idplato
      WHERE 
        m.isDelete = FALSE
        AND m.disponibilidad = TRUE
        AND COALESCE(vr.cantidad_vendida, 0) > 0
    `;

    // Agregar filtro de categoría también en la segunda parte
    if (categoria === 'comida') {
      query += ` AND m.tipo = 'comida'`;
    } else if (categoria === 'bebida') {
      query += ` AND m.tipo = 'bebida'`;
    } else if (categoria && categoria !== 'todos' && categoria !== 'null') {
      query += ` AND m.categoria = $${queryParams.length}`;
    }

    // Ordenamiento y límite
    queryParams.push(limit);
    query += `
      ORDER BY 
        vr.cantidad_vendida DESC NULLS LAST,
        vr.ingresos_totales DESC NULLS LAST,
        m.nombre ASC
      LIMIT $${queryParams.length}
    `;

    console.log(`📊 [OPTIMIZADO] Ejecutando consulta optimizada con ${queryParams.length} parámetros`);
    console.log(`📊 [OPTIMIZADO] Parámetros: [${queryParams.join(', ')}]`);
    
    // PASO 4: Ejecutar consulta
    const { rows } = await pool.query(query, queryParams);
    
    // PASO 5: Formatear resultados
    const formattedRows = rows.map(row => ({
      idplato: parseInt(row.idplato),
      nombre: row.nombre,
      categoria: row.categoria,
      precio: parseFloat(row.precio),
      imagen_url: row.imagen_url,
      tipo: row.tipo,
      cantidad_vendida: parseInt(row.cantidad_vendida),
      pedidos_distintos: parseInt(row.pedidos_distintos),
      precio_promedio: parseFloat(row.precio_promedio),
      ingresos_totales: parseFloat(row.ingresos_totales)
    }));
    
    console.log(`📊 [OPTIMIZADO] Resultados encontrados: ${formattedRows.length} platos`);
    console.log(`📊 [OPTIMIZADO] Rango de fechas usado: ${fechaInicio.toISOString().split('T')[0]} a ${fechaFin.toISOString().split('T')[0]}`);
    
    if (formattedRows.length > 0) {
      console.log(`📊 [OPTIMIZADO] Top 3 platos:`);
      formattedRows.slice(0, 3).forEach((plato, index) => {
        console.log(`   ${index + 1}. ${plato.nombre}: ${plato.cantidad_vendida} vendidos, $${plato.ingresos_totales.toFixed(2)} ingresos`);
      });
    }
    
    // PASO 6: Agregar metadatos de la consulta
    const response = {
      platos: formattedRows,
      metadata: {
        rango_consultado: {
          inicio: fechaInicio.toISOString().split('T')[0],
          fin: fechaFin.toISOString().split('T')[0]
        },
        rango_disponible: {
          inicio: fecha_minima,
          fin: fecha_maxima
        },
        total_pedidos_periodo: total_pedidos,
        filtros_aplicados: {
          categoria: categoria || 'todos',
          periodo: period || 'personalizado',
          limite: parseInt(limit)
        },
        timestamp: new Date().toISOString()
      }
    };
    
    // Para mantener compatibilidad, devolver solo el array de platos
    return res.status(200).json(formattedRows);
    
  } catch (error) {
    console.error("❌ [OPTIMIZADO] Error al obtener platos más vendidos:", error);
    return res.status(500).json({
      error: "Error al obtener platos más vendidos",
      details: error.message,
      timestamp: new Date().toISOString()
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
        SUM(pd.cantidad * m.precio) as total_ventas
      FROM 
        pedidos p
      JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      JOIN 
        menu m ON pd.idplato = m.idplato
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
    
    // Si se proporcionan fechas específicas
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
        case 'all':
        case 'todos':
          // Para "todos", obtener desde el primer pedido en la BD
          console.log('📊 Período "todos" detectado - obteniendo rango completo de la BD');
          try {
            const rangoResult = await pool.query(`
              SELECT 
                MIN(DATE(fecha)) as fecha_minima,
                MAX(DATE(fecha)) as fecha_maxima
              FROM pedidos 
              WHERE estado = 'completado'
            `);
            
            if (rangoResult.rows[0].fecha_minima && rangoResult.rows[0].fecha_maxima) {
              fechaInicio = new Date(`${rangoResult.rows[0].fecha_minima}T00:00:00`);
              fechaFin = new Date(`${rangoResult.rows[0].fecha_maxima}T23:59:59`);
              console.log(`📊 Rango completo encontrado: ${fechaInicio.toISOString()} a ${fechaFin.toISOString()}`);
            } else {
              // Si no hay datos, usar el día actual
              fechaInicio = new Date(hoy);
              fechaInicio.setHours(0, 0, 0, 0);
              console.log('📊 No hay datos en la BD, usando día actual');
            }
          } catch (error) {
            console.error('❌ Error al obtener rango de fechas de la BD:', error);
            // Fallback: usar todos los datos hasta hoy
            fechaInicio = new Date('2000-01-01T00:00:00'); // Fecha muy antigua
            fechaFin = new Date(hoy);
            fechaFin.setHours(23, 59, 59, 999);
          }
          break;
        default:
          // Para período no especificado o desconocido, también usar todos los datos
          console.log(`📊 Período no reconocido "${period}" - usando todos los datos disponibles`);
          try {
            const rangoResult = await pool.query(`
              SELECT 
                MIN(DATE(fecha)) as fecha_minima,
                MAX(DATE(fecha)) as fecha_maxima
              FROM pedidos 
              WHERE estado = 'completado'
            `);
            
            if (rangoResult.rows[0].fecha_minima && rangoResult.rows[0].fecha_maxima) {
              fechaInicio = new Date(`${rangoResult.rows[0].fecha_minima}T00:00:00`);
              fechaFin = new Date(`${rangoResult.rows[0].fecha_maxima}T23:59:59`);
              console.log(`📊 Rango completo (default): ${fechaInicio.toISOString()} a ${fechaFin.toISOString()}`);
            } else {
              // Si no hay datos, usar últimos 30 días como antes
          fechaInicio = new Date(hoy);
              fechaInicio.setDate(hoy.getDate() - 30);
          fechaInicio.setHours(0, 0, 0, 0);
              console.log('📊 No hay datos, usando últimos 30 días como fallback');
            }
          } catch (error) {
            console.error('❌ Error al obtener rango default:', error);
            // Fallback final: últimos 30 días
            fechaInicio = new Date(hoy);
            fechaInicio.setDate(hoy.getDate() - 30);
            fechaInicio.setHours(0, 0, 0, 0);
          }
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
          SUM(pd.cantidad * m.precio) as total_pedido
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
        COALESCE(SUM(pd.cantidad * m.precio), 0) as total_ventas
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
        COALESCE(SUM(pd.cantidad * m.precio), 0) as total_ventas
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
        SUM(pd.cantidad * m.precio) as total_ventas,
        ROUND(AVG(subquery.total_pedido), 2) as ticket_promedio
      FROM 
        pedidos p
        INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
        INNER JOIN menu m ON pd.idplato = m.idplato
        INNER JOIN (
          SELECT 
            pd2.idpedido,
            SUM(pd2.cantidad * m2.precio) as total_pedido
          FROM 
            pedido_detalle pd2
          INNER JOIN menu m2 ON pd2.idplato = m2.idplato
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
      `SELECT pd.idplato, pd.cantidad, pd.notas,
              m.nombre as nombre, m.imagen_url, m.precio as precio_unitario
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

// Obtener historial de pedidos de un cliente específico
router.get("/pedidos/cliente/:clienteId/historial", async (req, res) => {
  try {
    const { clienteId } = req.params;
    const { limit = 20 } = req.query;
    
    console.log(`📋 Obteniendo historial para cliente ${clienteId}`);
    
    // Validar que el clienteId sea un número válido
    if (!clienteId || isNaN(parseInt(clienteId))) {
      return res.status(400).json({ 
        error: "ID de cliente inválido" 
      });
    }
    
    const query = `
      SELECT 
        m.idplato,
        m.nombre,
        m.categoria,
        m.precio,
        m.tipo,
        COUNT(pd.idplato) as veces_pedido,
        MAX(p.fecha) as ultimo_pedido,
        AVG(m.precio) as precio_promedio
      FROM 
        pedidos p
      INNER JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      INNER JOIN 
        menu m ON pd.idplato = m.idplato
      WHERE 
        p.idpersona = $1 
        AND p.estado = 'completado'
        AND m.isDelete = FALSE
      GROUP BY 
        m.idplato, m.nombre, m.categoria, m.precio, m.tipo
      ORDER BY 
        veces_pedido DESC, ultimo_pedido DESC
      LIMIT $2
    `;
    
    const { rows } = await pool.query(query, [clienteId, limit]);
    
    const formattedRows = rows.map(row => ({
      ...row,
      veces_pedido: parseInt(row.veces_pedido),
      precio_promedio: parseFloat(row.precio_promedio),
      ultimo_pedido: row.ultimo_pedido
    }));
    
    console.log(`📋 Historial encontrado: ${formattedRows.length} platos únicos`);
    
    return res.status(200).json({
      clienteId: parseInt(clienteId),
      historial: formattedRows,
      total_platos_unicos: formattedRows.length
    });
    
  } catch (error) {
    console.error("❌ Error al obtener historial del cliente:", error);
    return res.status(500).json({
      error: "Error al obtener historial del cliente",
      details: error.message
    });
  }
});

// Obtener recomendaciones personalizadas para un cliente
router.get("/pedidos/cliente/:clienteId/recomendaciones", async (req, res) => {
  try {
    const { clienteId } = req.params;
    const { limit = 5 } = req.query;
    
    console.log(`🤖 Generando recomendaciones para cliente ${clienteId}`);
    
    // Validar que el clienteId sea un número válido
    if (!clienteId || isNaN(parseInt(clienteId))) {
      return res.status(400).json({ 
        error: "ID de cliente inválido" 
      });
    }
    
    // Obtener platos favoritos del cliente (los que más ha pedido)
    const historialQuery = `
      SELECT 
        m.idplato,
        m.nombre,
        m.categoria,
        m.precio,
        m.tipo,
        COUNT(pd.idplato) as veces_pedido
      FROM 
        pedidos p
      INNER JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      INNER JOIN 
        menu m ON pd.idplato = m.idplato
      WHERE 
        p.idpersona = $1 
        AND p.estado = 'completado'
        AND m.isDelete = FALSE
        AND m.disponibilidad = TRUE
      GROUP BY 
        m.idplato, m.nombre, m.categoria, m.precio, m.tipo
      ORDER BY 
        veces_pedido DESC
      LIMIT 10
    `;
    
    // Obtener platos populares generales que el cliente no ha probado
    const popularesNoProbadasQuery = `
      WITH cliente_platos AS (
        SELECT DISTINCT pd.idplato
        FROM pedidos p
        INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
        WHERE p.idpersona = $1 AND p.estado = 'completado'
      ),
      platos_populares AS (
        SELECT 
          pd.idplato,
          SUM(pd.cantidad) as total_vendido
        FROM 
          pedido_detalle pd
        INNER JOIN 
          pedidos p ON pd.idpedido = p.idpedido
        WHERE 
          p.estado = 'completado'
        GROUP BY 
          pd.idplato
        ORDER BY 
          total_vendido DESC
      )
      SELECT 
        m.idplato,
        m.nombre,
        m.categoria,
        m.precio,
        m.tipo,
        pp.total_vendido
      FROM 
        menu m
      INNER JOIN 
        platos_populares pp ON m.idplato = pp.idplato
      WHERE 
        m.isDelete = FALSE
        AND m.disponibilidad = TRUE
        AND m.idplato NOT IN (SELECT idplato FROM cliente_platos)
      ORDER BY 
        pp.total_vendido DESC
      LIMIT $2
    `;
    
    // Obtener platos similares (misma categoría) a los que le gustan al cliente
    const similaresQuery = `
      WITH categorias_favoritas AS (
        SELECT 
          m.categoria,
          m.tipo,
          COUNT(*) as preferencia
        FROM 
          pedidos p
        INNER JOIN 
          pedido_detalle pd ON p.idpedido = pd.idpedido
        INNER JOIN 
          menu m ON pd.idplato = m.idplato
        WHERE 
          p.idpersona = $1 
          AND p.estado = 'completado'
        GROUP BY 
          m.categoria, m.tipo
        ORDER BY 
          preferencia DESC
        LIMIT 3
      ),
      cliente_platos AS (
        SELECT DISTINCT pd.idplato
        FROM pedidos p
        INNER JOIN pedido_detalle pd ON p.idpedido = pd.idpedido
        WHERE p.idpersona = $1 AND p.estado = 'completado'
      )
      SELECT 
        m.idplato,
        m.nombre,
        m.categoria,
        m.precio,
        m.tipo,
        cf.preferencia as categoria_score
      FROM 
        menu m
      INNER JOIN 
        categorias_favoritas cf ON (m.categoria = cf.categoria AND m.tipo = cf.tipo)
      WHERE 
        m.isDelete = FALSE
        AND m.disponibilidad = TRUE
        AND m.idplato NOT IN (SELECT idplato FROM cliente_platos)
      ORDER BY 
        cf.preferencia DESC, RANDOM()
      LIMIT $2
    `;
    
    // Ejecutar todas las consultas
    const [historialResult, popularesResult, similaresResult] = await Promise.all([
      pool.query(historialQuery, [clienteId]),
      pool.query(popularesNoProbadasQuery, [clienteId, limit]),
      pool.query(similaresQuery, [clienteId, limit])
    ]);
    
    // Combinar y formatear resultados
    const recomendaciones = {
      clienteId: parseInt(clienteId),
      favoritos_cliente: historialResult.rows.map(row => ({
        ...row,
        veces_pedido: parseInt(row.veces_pedido),
        motivo: "Tu plato favorito"
      })),
      populares_nuevos: popularesResult.rows.map(row => ({
        ...row,
        total_vendido: parseInt(row.total_vendido),
        motivo: "Popular entre otros clientes"
      })),
      similares_gustos: similaresResult.rows.map(row => ({
        ...row,
        categoria_score: parseInt(row.categoria_score),
        motivo: `Te gusta la categoría ${row.categoria}`
      }))
    };
    
    // Crear una lista unificada de recomendaciones
    const recomendacionesUnificadas = [];
    
    // Agregar hasta 2 favoritos del cliente
    recomendaciones.favoritos_cliente.slice(0, 2).forEach(plato => {
      recomendacionesUnificadas.push(plato);
    });
    
    // Agregar hasta 2 populares nuevos
    recomendaciones.populares_nuevos.slice(0, 2).forEach(plato => {
      recomendacionesUnificadas.push(plato);
    });
    
    // Agregar hasta 1 similar a sus gustos
    recomendaciones.similares_gustos.slice(0, 1).forEach(plato => {
      recomendacionesUnificadas.push(plato);
    });
    
    // Limitar al número solicitado
    const recomendacionesFinales = recomendacionesUnificadas.slice(0, parseInt(limit));
    
    console.log(`🤖 Recomendaciones generadas: ${recomendacionesFinales.length} platos`);
    
    return res.status(200).json({
      ...recomendaciones,
      recomendaciones_unificadas: recomendacionesFinales,
      total_recomendaciones: recomendacionesFinales.length
    });
    
  } catch (error) {
    console.error("❌ Error al generar recomendaciones:", error);
    return res.status(500).json({
      error: "Error al generar recomendaciones",
      details: error.message
    });
  }
});

// Obtener estadísticas de preferencias del cliente
router.get("/pedidos/cliente/:clienteId/estadisticas", async (req, res) => {
  try {
    const { clienteId } = req.params;
    
    console.log(`📊 Obteniendo estadísticas para cliente ${clienteId}`);
    
    // Validar que el clienteId sea un número válido
    if (!clienteId || isNaN(parseInt(clienteId))) {
      return res.status(400).json({ 
        error: "ID de cliente inválido" 
      });
    }
    
    // Estadísticas generales del cliente
    const estadisticasQuery = `
      SELECT 
        COUNT(DISTINCT p.idpedido) as total_pedidos,
        COUNT(pd.idplato) as total_items_pedidos,
        SUM(m.precio * pd.cantidad) as gasto_total,
        AVG(m.precio * pd.cantidad) as gasto_promedio_por_item,
        MAX(p.fecha) as ultimo_pedido
      FROM 
        pedidos p
      INNER JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      INNER JOIN 
        menu m ON pd.idplato = m.idplato
      WHERE 
        p.idpersona = $1 
        AND p.estado = 'completado'
    `;
    
    // Preferencias por tipo (comida vs bebida)
    const preferenciasTipoQuery = `
      SELECT 
        m.tipo,
        COUNT(pd.idplato) as cantidad_pedidos,
        SUM(m.precio * pd.cantidad) as gasto_en_tipo
      FROM 
        pedidos p
      INNER JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      INNER JOIN 
        menu m ON pd.idplato = m.idplato
      WHERE 
        p.idpersona = $1 
        AND p.estado = 'completado'
      GROUP BY 
        m.tipo
      ORDER BY 
        cantidad_pedidos DESC
    `;
    
    // Preferencias por categoría
    const preferenciasCategoriaQuery = `
      SELECT 
        m.categoria,
        m.tipo,
        COUNT(pd.idplato) as cantidad_pedidos,
        SUM(m.precio * pd.cantidad) as gasto_en_categoria
      FROM 
        pedidos p
      INNER JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      INNER JOIN 
        menu m ON pd.idplato = m.idplato
      WHERE 
        p.idpersona = $1 
        AND p.estado = 'completado'
      GROUP BY 
        m.categoria, m.tipo
      ORDER BY 
        cantidad_pedidos DESC
    `;
    
    // Ejecutar todas las consultas
    const [estadisticasResult, tipoResult, categoriaResult] = await Promise.all([
      pool.query(estadisticasQuery, [clienteId]),
      pool.query(preferenciasTipoQuery, [clienteId]),
      pool.query(preferenciasCategoriaQuery, [clienteId])
    ]);
    
    const estadisticas = {
      clienteId: parseInt(clienteId),
      resumen: {
        total_pedidos: parseInt(estadisticasResult.rows[0]?.total_pedidos || 0),
        total_items_pedidos: parseInt(estadisticasResult.rows[0]?.total_items_pedidos || 0),
        gasto_total: parseFloat(estadisticasResult.rows[0]?.gasto_total || 0),
        gasto_promedio_por_item: parseFloat(estadisticasResult.rows[0]?.gasto_promedio_por_item || 0),
        ultimo_pedido: estadisticasResult.rows[0]?.ultimo_pedido
      },
      preferencias_tipo: tipoResult.rows.map(row => ({
        tipo: row.tipo,
        cantidad_pedidos: parseInt(row.cantidad_pedidos),
        gasto_en_tipo: parseFloat(row.gasto_en_tipo),
        porcentaje: tipoResult.rows.length > 0 ? 
          Math.round((parseInt(row.cantidad_pedidos) / tipoResult.rows.reduce((sum, r) => sum + parseInt(r.cantidad_pedidos), 0)) * 100) : 0
      })),
      preferencias_categoria: categoriaResult.rows.map(row => ({
        categoria: row.categoria,
        tipo: row.tipo,
        cantidad_pedidos: parseInt(row.cantidad_pedidos),
        gasto_en_categoria: parseFloat(row.gasto_en_categoria)
      }))
    };
    
    console.log(`📊 Estadísticas generadas para cliente ${clienteId}`);
    
    return res.status(200).json(estadisticas);
    
  } catch (error) {
    console.error("❌ Error al obtener estadísticas del cliente:", error);
    return res.status(500).json({
      error: "Error al obtener estadísticas del cliente",
      details: error.message
    });
  }
});

// Obtener información sobre el rango de fechas disponibles en la base de datos
router.get("/pedidos/stats/fechas-disponibles", async (req, res) => {
  try {
    console.log("📅 [INFO] Solicitud de información de fechas disponibles");
    
    const query = `
      SELECT 
        MIN(DATE(fecha)) as fecha_minima,
        MAX(DATE(fecha)) as fecha_maxima,
        COUNT(*) as total_pedidos,
        COUNT(CASE WHEN estado = 'completado' THEN 1 END) as pedidos_completados,
        COUNT(DISTINCT DATE(fecha)) as dias_con_actividad,
        MIN(fecha) as timestamp_minimo,
        MAX(fecha) as timestamp_maximo
      FROM pedidos
    `;
    
    const { rows } = await pool.query(query);
    const info = rows[0];
    
    // Calcular estadísticas adicionales
    const fechaMin = new Date(info.fecha_minima);
    const fechaMax = new Date(info.fecha_maxima);
    const diasTotales = Math.ceil((fechaMax - fechaMin) / (1000 * 60 * 60 * 24)) + 1;
    
    const response = {
      rango_disponible: {
        fecha_minima: info.fecha_minima,
        fecha_maxima: info.fecha_maxima,
        timestamp_minimo: info.timestamp_minimo,
        timestamp_maximo: info.timestamp_maximo
      },
      estadisticas: {
        total_pedidos: parseInt(info.total_pedidos),
        pedidos_completados: parseInt(info.pedidos_completados),
        dias_con_actividad: parseInt(info.dias_con_actividad),
        dias_totales: diasTotales,
        porcentaje_actividad: diasTotales > 0 ? Math.round((parseInt(info.dias_con_actividad) / diasTotales) * 100) : 0
      },
      periodos_sugeridos: {
        ultima_semana: {
          inicio: new Date(fechaMax.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          fin: info.fecha_maxima
        },
        ultimo_mes: {
          inicio: new Date(fechaMax.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          fin: info.fecha_maxima
        },
        todo_disponible: {
          inicio: info.fecha_minima,
          fin: info.fecha_maxima
        }
      },
      timestamp: new Date().toISOString()
    };
    
    console.log(`📅 [INFO] Rango disponible: ${info.fecha_minima} a ${info.fecha_maxima}`);
    console.log(`📅 [INFO] Total pedidos: ${info.total_pedidos} (${info.pedidos_completados} completados)`);
    
    return res.status(200).json(response);
  } catch (error) {
    console.error("❌ Error al obtener información de fechas:", error);
    return res.status(500).json({
      error: "Error al obtener información de fechas disponibles",
      details: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router; 