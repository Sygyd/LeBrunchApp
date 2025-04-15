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
    
    const estadosValidos = ['pendiente', 'preparando', 'listo', 'entregado', 'cancelado'];
    if (!estadosValidos.includes(estado)) {
      return res.status(400).json({ 
        error: `Estado no válido. Debe ser uno de: ${estadosValidos.join(', ')}` 
      });
    }
    
    const result = await pool.query(
      "UPDATE pedidos SET estado = $1 WHERE idpedido = $2 RETURNING idpedido, estado",
      [estado, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Pedido no encontrado" });
    }
    
    return res.status(200).json({
      message: "Estado del pedido actualizado correctamente",
      pedido: result.rows[0]
    });
    
  } catch (error) {
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
        COUNT(CASE WHEN estado = 'entregado' THEN 1 END) as entregados,
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
        p.estado = 'entregado'
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

module.exports = router; 