const express = require("express");
const router = express.Router();
const pool = require("./db");

// Middleware para parsear JSON
router.use(express.json());

// Guardar mensaje de chat
router.post("/chat", async (req, res) => {
  try {
    const { userId, message, response } = req.body;
    
    const result = await pool.query(
      "INSERT INTO historial_chat (IDpersona, mensaje, respuesta) VALUES ($1, $2, $3) RETURNING *",
      [userId, message, response || 'En proceso...']
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error("Error al guardar chat:", error);
    res.status(500).json({ error: "Error en el servidor" });
  }
});

// Procesar pedido desde chat
router.post("/process-order", async (req, res) => {
  try {
    const { userId, items } = req.body;
    
    if (!userId || !items) {
      return res.status(400).json({ error: "Datos incompletos" });
    }

    // 1. Crear pedido
    const order = await pool.query(
      "INSERT INTO pedidos (IDpersona, estado) VALUES ($1, 'pendiente') RETURNING IDpedido",
      [userId]
    );
    
    const orderId = order.rows[0].idpedido;
    
    // 2. Agregar items
    for (const item of items) {
      await pool.query(
        `INSERT INTO pedido_detalle 
        (IDplato, IDpedido, cantidad, precio_unitario) 
        VALUES ($1, $2, $3, (SELECT precio FROM menu WHERE IDplato = $1))`,
        [item.dishId, orderId, item.quantity || 1]
      );
    }
    
    res.status(201).json({ 
      orderId, 
      message: "Pedido creado exitosamente",
      status: "pendiente"
    });
  } catch (error) {
    console.error("Error al procesar pedido:", error);
    res.status(500).json({ error: "Error en el servidor" });
  }
});

module.exports = router;