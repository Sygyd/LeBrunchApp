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
// NO usar puerto 5678 bajo ninguna circunstancia

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

// Endpoint del chat (respuesta directa sin procesamiento externo)
app.post('/chat', (req, res) => {
  try {
    const { message, sessionId } = req.body;

    console.log('Mensaje recibido en el servidor:', message);
    console.log('Session ID:', sessionId || 'No proporcionado');
    
    // Lógica simple para generar respuestas útiles en lugar de hacer eco
    let respuesta = '';
    
    // Respuestas predefinidas para preguntas comunes
    if (message.toLowerCase().includes('menu') || message.toLowerCase().includes('carta')) {
      respuesta = "Nuestro menú incluye:\n" +
                 "• Desayunos: Huevos revueltos, Tostadas Francesas, Pancakes\n" +
                 "• Brunch: Avocado Toast, Bagel con salmón, Ensalada César\n" +
                 "• Bebidas: Café, Té, Jugos naturales, Mimosas\n" +
                 "• Postres: Cheesecake, Brownie, Frutas frescas\n\n" +
                 "¿Te gustaría ordenar algo en particular?";
    } 
    else if (message.toLowerCase().includes('hola') || message.toLowerCase().includes('buenos días') || message.toLowerCase().includes('buenas')) {
      respuesta = "¡Hola! Bienvenido a Le Brunch. Soy Brunchy, tu mesero virtual. ¿En qué puedo ayudarte hoy?";
    }
    else if (message.toLowerCase().includes('gracias') || message.toLowerCase().includes('thank')) {
      respuesta = "¡De nada! Es un placer atenderte. ¿Hay algo más en lo que pueda ayudarte?";
    }
    else if (message.toLowerCase().includes('precio') || message.toLowerCase().includes('costo') || message.toLowerCase().includes('cuánto')) {
      respuesta = "Nuestros precios son muy accesibles. La mayoría de nuestros desayunos están entre $8-12, los brunch entre $12-15, y las bebidas entre $3-6. Los precios exactos están disponibles en nuestro menú completo.";
    }
    else if (message.toLowerCase().includes('especial') || message.toLowerCase().includes('recomendación') || message.toLowerCase().includes('recomiendas')) {
      respuesta = "¡Claro! Hoy te recomendaría nuestro Avocado Toast con huevo pochado, es el favorito de nuestros clientes. También tenemos un especial de Pancakes con frutas frescas de temporada que está delicioso.";
    }
    else if (message.toLowerCase().includes('ubicación') || message.toLowerCase().includes('dirección') || message.toLowerCase().includes('dónde')) {
      respuesta = "Estamos ubicados en el centro de la ciudad, en Avenida Principal #123. Tenemos estacionamiento gratuito para nuestros clientes.";
    }
    else if (message.toLowerCase().includes('horario') || message.toLowerCase().includes('hora') || message.toLowerCase().includes('abierto')) {
      respuesta = "Nuestro horario es de Martes a Domingo, de 8:00 AM a 4:00 PM. Los lunes permanecemos cerrados.";
    }
    else {
      // Para cualquier otro mensaje, dar una respuesta genérica útil
      const respuestasGenericas = [
        "Como mesero virtual de Le Brunch, estoy aquí para ayudarte con nuestro menú y servicios. ¿Te gustaría conocer nuestras especialidades?",
        "¡Gracias por tu mensaje! Si tienes preguntas sobre nuestro menú o servicios, estoy aquí para ayudarte.",
        "En Le Brunch nos especializamos en desayunos y brunch. ¿Puedo recomendarte algo de nuestra carta?",
        "¿Hay algo específico de nuestro menú que te gustaría conocer? Estoy aquí para ayudarte con cualquier duda.",
        "Nuestros chefs preparan cada plato con ingredientes frescos y de calidad. ¿Te gustaría conocer la especialidad del día?"
      ];
      
      // Seleccionar una respuesta aleatoria
      respuesta = respuestasGenericas[Math.floor(Math.random() * respuestasGenericas.length)];
    }

    console.log('Enviando respuesta personalizada en lugar de eco');

    // Respuesta personalizada
    const response = {
      response: respuesta
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
  console.log('NO se está utilizando el puerto 5678');
});


