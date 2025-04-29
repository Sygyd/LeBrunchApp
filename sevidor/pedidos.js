const express = require("express");
const pool = require("./db");
const router = express.Router();

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

// Obtener un pedido específico por ID
router.get("/pedidos/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    // Obtener datos del pedido
    const pedidoResult = await pool.query(
      `SELECT p.idpedido, p.idpersona, p.estado, 
              TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha, 
              TO_CHAR(p.fecha, 'HH24:MI') as hora,
              pe.nombre || ' ' || pe.apellido as cliente
       FROM pedidos p
       INNER JOIN personas pe ON p.idpersona = pe.idpersonas
       WHERE p.idpedido = $1`,
      [id]
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
      [id]
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
      "SELECT estado FROM pedidos WHERE idpedido = $1",
      [id]
    );
    
    if (currentStateResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ error: "Pedido no encontrado" });
    }
    
    const currentState = currentStateResult.rows[0].estado;
    
    // Actualizar el estado
    const updateResult = await pool.query(
      "UPDATE pedidos SET estado = $1 WHERE idpedido = $2 RETURNING *",
      [estado, id]
    );
    
    // Si el pedido está cambiando de pendiente a completado o cancelado,
    // añadir entrada en la tabla de tiempos de procesamiento
    if (currentState === 'pendiente' && (estado === 'completado' || estado === 'cancelado')) {
      console.log(`📝 Registrando tiempo de procesamiento para pedido #${id}: ${currentState} -> ${estado}`);
      
      try {
        // Verificar si la tabla pedido_tiempos existe, crearla si no
        await pool.query(`
          CREATE TABLE IF NOT EXISTS pedido_tiempos (
            id SERIAL PRIMARY KEY,
            idpedido INTEGER NOT NULL,
            estado_inicial VARCHAR(50) NOT NULL,
            estado_final VARCHAR(50) NOT NULL,
            timestamp_inicial TIMESTAMP NOT NULL,
            timestamp_final TIMESTAMP NOT NULL,
            tiempo_procesamiento INTERVAL NOT NULL
          );
        `);
        
        // Obtener timestamp original del pedido
        const timestampResult = await pool.query(
          "SELECT fecha FROM pedidos WHERE idpedido = $1",
          [id]
        );
        
        if (timestampResult.rows.length > 0) {
          const fechaInicial = timestampResult.rows[0].fecha;
          const fechaFinal = new Date();
          
          // Calcular el tiempo de procesamiento
          await pool.query(`
            INSERT INTO pedido_tiempos (
              idpedido, 
              estado_inicial, 
              estado_final, 
              timestamp_inicial, 
              timestamp_final, 
              tiempo_procesamiento
            ) VALUES (
              $1, $2, $3, $4, $5, $5 - $4
            )`,
            [id, currentState, estado, fechaInicial, fechaFinal]
          );
          
          console.log('✅ Tiempo de procesamiento registrado exitosamente');
        }
      } catch (timeError) {
        console.error('❌ Error al registrar tiempo de procesamiento:', timeError);
        // No hacemos rollback en caso de error aquí, ya que la actualización del estado
        // es más importante que el registro del tiempo
      }
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
      "SELECT COALESCE(SUM(pd.precio_unitario * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido WHERE DATE(p.fecha) = CURRENT_DATE"
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

// Eliminar un pedido
router.delete("/pedidos/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    // Iniciar transacción
    await pool.query('BEGIN');
    
    // Primero eliminar detalles del pedido
    await pool.query(
      "DELETE FROM pedido_detalle WHERE idpedido = $1",
      [id]
    );
    
    // Luego eliminar el pedido principal
    const result = await pool.query(
      "DELETE FROM pedidos WHERE idpedido = $1 RETURNING idpedido",
      [id]
    );
    
    // Confirmar transacción
    await pool.query('COMMIT');
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Pedido no encontrado" });
    }
    
    return res.status(200).json({
      message: "Pedido eliminado correctamente",
      idpedido: result.rows[0].idpedido
    });
    
  } catch (error) {
    // Rollback en caso de error
    await pool.query('ROLLBACK');
    console.error("❌ Error al eliminar pedido:", error);
    return res.status(500).json({
      error: "Error al eliminar el pedido",
      details: error.message
    });
  }
});

// Obtener los platos más vendidos
router.get("/pedidos/stats/mas-vendidos", async (req, res) => {
  try {
    const { limit = 5 } = req.query;
    
    const { rows } = await pool.query(
      `SELECT 
        m.idplato, 
        m.nombre, 
        m.imagen_url,
        SUM(pd.cantidad) as cantidad_vendida,
        AVG(pd.precio_unitario) as precio_promedio
      FROM 
        pedido_detalle pd
      JOIN 
        menu m ON pd.idplato = m.idplato
      JOIN 
        pedidos p ON pd.idpedido = p.idpedido
      WHERE 
        p.estado = 'completado'
      GROUP BY 
        m.idplato, m.nombre, m.imagen_url
      ORDER BY 
        cantidad_vendida DESC
      LIMIT $1`,
      [limit]
    );
    
    // Formatear resultados
    const formattedRows = rows.map(row => ({
      ...row,
      precio_promedio: parseFloat(row.precio_promedio),
      cantidad_vendida: parseInt(row.cantidad_vendida)
    }));
    
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
    const { period, startDate, endDate } = req.query;
    
    console.log(`📊 Solicitud de resumen de pedidos: período=${period}, fechas=${startDate || 'N/A'} a ${endDate || 'N/A'}`);

    // Para pruebas, vamos a incluir todas las fechas a menos que se especifique un rango
    let fechaInicio, fechaFin;

    if (startDate && endDate) {
      // Si se proporcionan fechas específicas, usarlas
      fechaInicio = new Date(`${startDate}T00:00:00`);
      fechaFin = new Date(`${endDate}T23:59:59`);
      console.log('📅 Usando rango de fechas proporcionado');
    } else {
      // Si no, usar un rango amplio (1 año anterior hasta hoy) para incluir todos los datos de prueba
      const hoy = new Date();
      
      // Para datos de prueba: fecha suficientemente en el futuro para incluir todos los datos
      if (process.env.NODE_ENV === 'development' || true) { // Siempre usar fechas amplias por ahora
        fechaInicio = new Date('2020-01-01');
        fechaFin = new Date('2030-12-31');
        console.log('📅 Usando rango amplio para datos de desarrollo/prueba');
      } else {
        // En producción, usar el período solicitado
        switch (period) {
          case 'day':
            fechaInicio = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
            fechaFin = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 23, 59, 59);
            break;
          case 'week':
            const diaSemana = hoy.getDay() || 7;
            const diasAtras = diaSemana - 1;
            fechaInicio = new Date(hoy);
            fechaInicio.setDate(hoy.getDate() - diasAtras);
            fechaInicio.setHours(0, 0, 0, 0);
            fechaFin = new Date(hoy);
            fechaFin.setHours(23, 59, 59, 999);
            break;
          case 'month':
            fechaInicio = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
            fechaFin = new Date(hoy);
            fechaFin.setHours(23, 59, 59, 999);
            break;
          case 'year':
            fechaInicio = new Date(hoy.getFullYear(), 0, 1);
            fechaFin = new Date(hoy);
            fechaFin.setHours(23, 59, 59, 999);
            break;
          case 'custom':
            return res.status(400).json({ 
              error: "Se requieren fechas de inicio y fin para el período personalizado" 
            });
          default:
            return res.status(400).json({ error: "Período no válido" });
        }
      }
    }
    
    const formatoFecha = fecha => fecha.toISOString().split('T')[0];
    console.log(`📅 Rango de fechas calculado: ${formatoFecha(fechaInicio)} a ${formatoFecha(fechaFin)}`);
    
    // 1. Consultar total de pedidos y ventas en el período
    const resumenQuery = `
      SELECT 
        COUNT(DISTINCT p.idpedido) as total_pedidos,
        COALESCE(SUM(pd.cantidad * pd.precio_unitario), 0) as total_ventas
      FROM 
        pedidos p
      LEFT JOIN 
        pedido_detalle pd ON p.idpedido = pd.idpedido
      WHERE 
        p.fecha >= $1 AND p.fecha <= $2
        AND p.estado = 'completado'
    `;
    
    console.log(`📊 Ejecutando consulta de resumen: ${resumenQuery}`);
    console.log(`📊 Parámetros: fechaInicio=${fechaInicio.toISOString()}, fechaFin=${fechaFin.toISOString()}`);
    
    const resumenResult = await pool.query(resumenQuery, [fechaInicio, fechaFin]);
    console.log(`📊 Resultado resumen: ${JSON.stringify(resumenResult.rows[0])}`);
    
    // 2. Consultar todos los pedidos para registrar en logs
    const pedidosQuery = `
      SELECT 
        p.idpedido, p.estado, TO_CHAR(p.fecha, 'YYYY-MM-DD HH24:MI:SS') as fecha
      FROM 
        pedidos p
      ORDER BY 
        p.fecha DESC
    `;
    
    const pedidosResult = await pool.query(pedidosQuery);
    console.log(`🧾 Pedidos en la base de datos: ${pedidosResult.rows.length}`);
    pedidosResult.rows.forEach(row => {
      console.log(`   - #${row.idpedido} | ${row.estado} | ${row.fecha}`);
    });
    
    // 3. Inicializar el objeto de respuesta
    const resumen = {
      totalPedidos: parseInt(resumenResult.rows[0].total_pedidos) || 0,
      totalVentas: parseFloat(resumenResult.rows[0].total_ventas) || 0,
      ticketPromedio: 0
    };
    
    // Calcular ticket promedio si hay pedidos
    if (resumen.totalPedidos > 0) {
      resumen.ticketPromedio = parseFloat((resumen.totalVentas / resumen.totalPedidos).toFixed(2));
    }
    
    // 4. Añadir distribución específica según el período
    if (period === 'day') {
      // Distribución por horas del día
      const horasQuery = `
        SELECT 
          EXTRACT(HOUR FROM p.fecha) as hora,
          COUNT(DISTINCT p.idpedido) as pedidos
        FROM 
          pedidos p
        WHERE 
          p.fecha >= $1 AND p.fecha <= $2
          AND p.estado = 'completado'
        GROUP BY 
          hora
        ORDER BY 
          hora
      `;
      
      const horasResult = await pool.query(horasQuery, [fechaInicio, fechaFin]);
      
      resumen.horasPico = horasResult.rows.map(row => ({
        hora: `${Math.floor(row.hora).toString().padStart(2, '0')}:00`,
        pedidos: parseInt(row.pedidos)
      }));
    } 
    else if (period === 'week') {
      // Distribución por días de la semana
      const diasQuery = `
        SELECT 
          CASE 
            WHEN EXTRACT(DOW FROM p.fecha) = 0 THEN 'Domingo'
            WHEN EXTRACT(DOW FROM p.fecha) = 1 THEN 'Lunes'
            WHEN EXTRACT(DOW FROM p.fecha) = 2 THEN 'Martes'
            WHEN EXTRACT(DOW FROM p.fecha) = 3 THEN 'Miércoles'
            WHEN EXTRACT(DOW FROM p.fecha) = 4 THEN 'Jueves'
            WHEN EXTRACT(DOW FROM p.fecha) = 5 THEN 'Viernes'
            WHEN EXTRACT(DOW FROM p.fecha) = 6 THEN 'Sábado'
          END as dia,
          COUNT(DISTINCT p.idpedido) as pedidos
        FROM 
          pedidos p
        WHERE 
          p.fecha >= $1 AND p.fecha <= $2
          AND p.estado = 'completado'
        GROUP BY 
          EXTRACT(DOW FROM p.fecha)
        ORDER BY 
          EXTRACT(DOW FROM p.fecha)
      `;
      
      const diasResult = await pool.query(diasQuery, [fechaInicio, fechaFin]);
      
      resumen.diasPico = diasResult.rows.map(row => ({
        dia: row.dia,
        pedidos: parseInt(row.pedidos)
      }));

      console.log(`🗓️ Distribución por días:`, resumen.diasPico);
    }
    else if (period === 'month') {
      // Distribución por semanas del mes
      const semanasQuery = `
        SELECT 
          CASE 
            WHEN EXTRACT(DAY FROM p.fecha) BETWEEN 1 AND 7 THEN '1-7'
            WHEN EXTRACT(DAY FROM p.fecha) BETWEEN 8 AND 14 THEN '8-14'
            WHEN EXTRACT(DAY FROM p.fecha) BETWEEN 15 AND 21 THEN '15-21'
            ELSE '22-31'
          END as semana,
          COUNT(DISTINCT p.idpedido) as pedidos
        FROM 
          pedidos p
        WHERE 
          p.fecha >= $1 AND p.fecha <= $2
          AND p.estado = 'completado'
        GROUP BY 
          semana
        ORDER BY 
          semana
      `;
      
      const semanasResult = await pool.query(semanasQuery, [fechaInicio, fechaFin]);
      
      resumen.semanasPico = semanasResult.rows.map(row => ({
        semana: row.semana,
        pedidos: parseInt(row.pedidos)
      }));

      console.log(`📅 Distribución por semanas:`, resumen.semanasPico);
    }
    else if (period === 'year') {
      // Distribución por meses del año
      const mesesQuery = `
        SELECT 
          CASE 
            WHEN EXTRACT(MONTH FROM p.fecha) = 1 THEN 'Enero'
            WHEN EXTRACT(MONTH FROM p.fecha) = 2 THEN 'Febrero'
            WHEN EXTRACT(MONTH FROM p.fecha) = 3 THEN 'Marzo'
            WHEN EXTRACT(MONTH FROM p.fecha) = 4 THEN 'Abril'
            WHEN EXTRACT(MONTH FROM p.fecha) = 5 THEN 'Mayo'
            WHEN EXTRACT(MONTH FROM p.fecha) = 6 THEN 'Junio'
            WHEN EXTRACT(MONTH FROM p.fecha) = 7 THEN 'Julio'
            WHEN EXTRACT(MONTH FROM p.fecha) = 8 THEN 'Agosto'
            WHEN EXTRACT(MONTH FROM p.fecha) = 9 THEN 'Septiembre'
            WHEN EXTRACT(MONTH FROM p.fecha) = 10 THEN 'Octubre'
            WHEN EXTRACT(MONTH FROM p.fecha) = 11 THEN 'Noviembre'
            WHEN EXTRACT(MONTH FROM p.fecha) = 12 THEN 'Diciembre'
          END as mes,
          COUNT(DISTINCT p.idpedido) as pedidos
        FROM 
          pedidos p
        WHERE 
          p.fecha >= $1 AND p.fecha <= $2
          AND p.estado = 'completado'
        GROUP BY 
          EXTRACT(MONTH FROM p.fecha)
        ORDER BY 
          EXTRACT(MONTH FROM p.fecha)
      `;
      
      const mesesResult = await pool.query(mesesQuery, [fechaInicio, fechaFin]);
      
      resumen.mesesPico = mesesResult.rows.map(row => ({
        mes: row.mes,
        pedidos: parseInt(row.pedidos)
      }));

      console.log(`📆 Distribución por meses:`, resumen.mesesPico);
    }
    
    console.log(`✅ Resumen generado con éxito: ${resumen.totalPedidos} pedidos por valor de ${resumen.totalVentas}`);
    return res.status(200).json(resumen);
    
  } catch (error) {
    console.error("❌ Error al generar resumen de pedidos:", error);
    return res.status(500).json({
      error: "Error al generar resumen de pedidos",
      details: error.message
    });
  }
});

// Obtener estadísticas de tiempo de procesamiento de pedidos
router.get("/pedidos/tiempo-procesamiento", async (req, res) => {
  try {
    const { period, startDate, endDate } = req.query;
    
    console.log(`⏱️ Solicitud de estadísticas de tiempo de procesamiento: período=${period}, fechas=${startDate || 'N/A'} a ${endDate || 'N/A'}`);

    // Para pruebas, vamos a incluir todas las fechas a menos que se especifique un rango
    let fechaInicio, fechaFin;
    let whereClause = "";

    if (startDate && endDate) {
      // Si se proporcionan fechas específicas, usarlas
      fechaInicio = new Date(`${startDate}T00:00:00`);
      fechaFin = new Date(`${endDate}T23:59:59`);
      whereClause = `pt.timestamp_inicial >= '${fechaInicio.toISOString()}' AND pt.timestamp_final <= '${fechaFin.toISOString()}'`;
      console.log('📅 Usando rango de fechas proporcionado');
    } else {
      // Si no, usar un período según se indique
      const hoy = new Date();
      
      switch (period) {
        case 'day':
          fechaInicio = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
          fechaFin = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 23, 59, 59);
          break;
        case 'week':
          const diaSemana = hoy.getDay() || 7;
          const diasAtras = diaSemana - 1;
          fechaInicio = new Date(hoy);
          fechaInicio.setDate(hoy.getDate() - diasAtras);
          fechaInicio.setHours(0, 0, 0, 0);
          fechaFin = new Date(hoy);
          break;
        case 'month':
          fechaInicio = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
          fechaFin = new Date(hoy);
          break;
        case 'year':
          fechaInicio = new Date(hoy.getFullYear(), 0, 1);
          fechaFin = new Date(hoy);
          break;
        default:
          // Por defecto, usar todo el rango de datos
          fechaInicio = new Date('2020-01-01');
          fechaFin = new Date('2030-12-31');
      }
      
      whereClause = `pt.timestamp_inicial >= '${fechaInicio.toISOString()}' AND pt.timestamp_final <= '${fechaFin.toISOString()}'`;
    }

    // Comprobar si la tabla pedido_tiempos existe
    const tableExistsQuery = `
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'pedido_tiempos'
      );
    `;
    
    const tableExists = await pool.query(tableExistsQuery);
    
    if (!tableExists.rows[0].exists) {
      return res.status(200).json({
        mensaje: "No hay datos de tiempos de procesamiento disponibles aún",
        datos_disponibles: false,
        tiempo_promedio: null,
        tiempo_minimo: null,
        tiempo_maximo: null,
        total_pedidos_analizados: 0
      });
    }

    // Consulta para obtener estadísticas de tiempo de procesamiento
    const query = `
      SELECT 
        COUNT(*) as total_pedidos,
        AVG(EXTRACT(EPOCH FROM tiempo_procesamiento)) as tiempo_promedio_segundos,
        MIN(EXTRACT(EPOCH FROM tiempo_procesamiento)) as tiempo_minimo_segundos,
        MAX(EXTRACT(EPOCH FROM tiempo_procesamiento)) as tiempo_maximo_segundos
      FROM 
        pedido_tiempos pt
      WHERE 
        ${whereClause}
    `;
    
    console.log("⏱️ Ejecutando consulta:", query);
    
    const result = await pool.query(query);
    
    if (result.rows.length === 0 || result.rows[0].total_pedidos === 0) {
      return res.status(200).json({
        mensaje: "No hay datos de tiempos de procesamiento para el período seleccionado",
        datos_disponibles: true,
        tiempo_promedio: null,
        tiempo_minimo: null,
        tiempo_maximo: null,
        total_pedidos_analizados: 0
      });
    }
    
    // Formatear minutos y segundos para mejor legibilidad
    const formatTiempo = (segundos) => {
      if (segundos === null) return null;
      
      const minutos = Math.floor(segundos / 60);
      const segundosRestantes = Math.round(segundos % 60);
      
      return {
        segundos: segundos,
        formato: `${minutos}m ${segundosRestantes}s`
      };
    };
    
    const stats = result.rows[0];
    
    // Obtener distribución por estado final
    const distribucionQuery = `
      SELECT 
        estado_final, 
        COUNT(*) as cantidad,
        AVG(EXTRACT(EPOCH FROM tiempo_procesamiento)) as tiempo_promedio_segundos
      FROM 
        pedido_tiempos pt
      WHERE 
        ${whereClause}
      GROUP BY 
        estado_final
      ORDER BY 
        cantidad DESC
    `;
    
    const distribucionResult = await pool.query(distribucionQuery);
    
    // Consulta para obtener la distribución por rango de tiempo
    const rangosTiempoQuery = `
      SELECT
        CASE
          WHEN EXTRACT(EPOCH FROM tiempo_procesamiento) < 300 THEN 'menos_5min'
          WHEN EXTRACT(EPOCH FROM tiempo_procesamiento) < 600 THEN '5_10min'
          WHEN EXTRACT(EPOCH FROM tiempo_procesamiento) < 900 THEN '10_15min'
          WHEN EXTRACT(EPOCH FROM tiempo_procesamiento) < 1200 THEN '15_20min'
          WHEN EXTRACT(EPOCH FROM tiempo_procesamiento) < 1800 THEN '20_30min'
          ELSE 'mas_30min'
        END as rango_tiempo,
        COUNT(*) as cantidad
      FROM
        pedido_tiempos pt
      WHERE
        ${whereClause}
      GROUP BY
        rango_tiempo
      ORDER BY
        CASE
          WHEN rango_tiempo = 'menos_5min' THEN 1
          WHEN rango_tiempo = '5_10min' THEN 2
          WHEN rango_tiempo = '10_15min' THEN 3
          WHEN rango_tiempo = '15_20min' THEN 4
          WHEN rango_tiempo = '20_30min' THEN 5
          WHEN rango_tiempo = 'mas_30min' THEN 6
        END
    `;
    
    const rangosTiempoResult = await pool.query(rangosTiempoQuery);
    
    // Construir respuesta
    return res.status(200).json({
      mensaje: "Estadísticas de tiempo de procesamiento obtenidas correctamente",
      datos_disponibles: true,
      tiempo_promedio: formatTiempo(stats.tiempo_promedio_segundos),
      tiempo_minimo: formatTiempo(stats.tiempo_minimo_segundos),
      tiempo_maximo: formatTiempo(stats.tiempo_maximo_segundos),
      total_pedidos_analizados: parseInt(stats.total_pedidos),
      distribucion_por_estado: distribucionResult.rows.map(row => ({
        estado: row.estado_final,
        cantidad: parseInt(row.cantidad),
        porcentaje: parseFloat(((parseInt(row.cantidad) / parseInt(stats.total_pedidos)) * 100).toFixed(2)),
        tiempo_promedio: formatTiempo(row.tiempo_promedio_segundos)
      })),
      distribucion_por_tiempo: rangosTiempoResult.rows.map(row => ({
        rango: row.rango_tiempo.replace('menos_', 'Menos de ').replace('mas_', 'Más de ')
          .replace('5_10min', '5-10 min').replace('10_15min', '10-15 min')
          .replace('15_20min', '15-20 min').replace('20_30min', '20-30 min'),
        cantidad: parseInt(row.cantidad),
        porcentaje: parseFloat(((parseInt(row.cantidad) / parseInt(stats.total_pedidos)) * 100).toFixed(2))
      })),
      periodo: {
        desde: fechaInicio.toISOString(),
        hasta: fechaFin.toISOString(),
        nombre: period || 'personalizado'
      }
    });
    
  } catch (error) {
    console.error("❌ Error al obtener estadísticas de tiempo de procesamiento:", error);
    return res.status(500).json({
      error: "Error al obtener estadísticas de tiempo de procesamiento",
      details: error.message
    });
  }
});

module.exports = router; 