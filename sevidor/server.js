require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const bodyParser = require("body-parser");
const menuRoutes = require("./menu");

// Configuración del servidor
const ip = '192.168.1.121';
const port = 3000;
// NO usar puerto 5678 (n8n) bajo ninguna circunstancia

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(bodyParser.json());
app.use(userRoutes);
app.use(menuRoutes);

// Endpoint para verificar el estado del servidor
app.get('/status', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Servidor en línea' });
});

// Endpoint del chat (sin usar n8n ni webhooks)
app.post('/chat', (req, res) => {
  try {
    const { message, sessionId } = req.body;
    
    console.log('Mensaje recibido en el servidor:', message);
    console.log('Session ID:', sessionId || 'No proporcionado');
    console.log('Respondiendo directamente sin reenviar a otros servicios');
    
    // Respuesta estática directa desde el servidor Node.js
    const response = {
      response: `Respuesta del servidor: "${message}"`
    };
    
    // Responder directamente sin intentar reenviar a ningún otro servicio
    return res.status(200).json(response);
  } catch (error) {
    console.error('Error en el endpoint de chat:', error);
    return res.status(500).json({ 
      error: 'Error al procesar el mensaje',
      details: error.message 
    });
  }
});

// Endpoint para verificar la conexión a la base de datos
app.get('/db-status', async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    res.status(200).json({ 
      status: 'ok',
      message: 'Conexión a PostgreSQL correcta',
      timestamp: result.rows[0].now
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'error',
      message: 'Error en la conexión a PostgreSQL',
      error: error.message
    });
  }
});

// Verificar la conexión a PostgreSQL inmediatamente
(async () => {
  try {
    const result = await pool.query("SELECT NOW()");
    console.log("Conexión a PostgreSQL funcionando:", result.rows[0]);
  } catch (error) {
    console.error("Error en la conexión a PostgreSQL:", error);
  }
})();

// Iniciar el servidor
app.listen(port, ip, () => {
  console.log(`Servidor corriendo en http://${ip}:${port}`);
  console.log(`Endpoint de chat disponible en http://${ip}:${port}/chat`);
  console.log('NO se está utilizando n8n ni el puerto 5678');
}); 