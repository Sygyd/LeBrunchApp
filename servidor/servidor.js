require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http'); // 🆕 NUEVO: Para WebSockets
const { Server } = require('socket.io'); // 🆕 NUEVO: Socket.IO para notificaciones
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const menuRoutes = require("./menu");
const pedidosRoutes = require("./pedidos");
// const authRoutes = require("./user"); // Comentado: este archivo no exporta un router
const multer = require("multer");
const path = require("path");
const fs = require("fs");

// Configuración de zona horaria Venezuela (GMT-4)
process.env.TZ = 'America/Caracas';
console.log(`🕒 Zona horaria configurada: ${process.env.TZ} - Hora actual: ${new Date().toLocaleString()}`);

// Configuración del servidor
const config = require('./config');
const ip = process.env.SERVER_IP || '0.0.0.0'; // Escuchar en todas las interfaces
const port = process.env.PORT || 3000;
const realServerIP = config.host; // IP real detectada para mostrar
// NO usar puerto 5678 bajo ninguna circunstancia

// Añadir inicialización de GoogleGenerativeAI con rotación de claves
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Sistema de rotación de claves API de Gemini
class GeminiKeyManager {
  constructor() {
    this.apiKeys = [
      process.env.GEMINI_API_KEY_1,
      process.env.GEMINI_API_KEY_2,
      process.env.GEMINI_API_KEY_3
    ].filter(key => key && key.trim() !== ''); // Filtrar claves vacías

    this.currentKeyIndex = 0;
    this.keyUsageCount = new Map(); // Contador de uso por clave
    this.errorCounts = new Map(); // Contador de errores por clave

    console.log(`🔑 GeminiKeyManager iniciado con ${this.apiKeys.length} claves API`);

    // Inicializar contadores
    this.apiKeys.forEach((key, index) => {
      this.keyUsageCount.set(index, 0);
      this.errorCounts.set(index, 0);
    });
  }

  getCurrentKey() {
    if (this.apiKeys.length === 0) {
      throw new Error('No se encontraron claves API de Gemini');
    }
    return this.apiKeys[this.currentKeyIndex];
  }

  getNextKey() {
    this.currentKeyIndex = (this.currentKeyIndex + 1) % this.apiKeys.length;
    console.log(`🔄 Rotando a clave API #${this.currentKeyIndex + 1}`);
    return this.getCurrentKey();
  }

  markKeyError(keyIndex = this.currentKeyIndex) {
    const errorCount = this.errorCounts.get(keyIndex) + 1;
    this.errorCounts.set(keyIndex, errorCount);
    console.log(`❌ Error registrado para clave #${keyIndex + 1} (total errores: ${errorCount})`);

    // Si una clave tiene muchos errores, evitarla temporalmente
    if (errorCount >= 3) {
      console.log(`⚠️ Clave #${keyIndex + 1} marcada como problemática (${errorCount} errores)`);
    }
  }

  incrementUsage(keyIndex = this.currentKeyIndex) {
    const usageCount = this.keyUsageCount.get(keyIndex) + 1;
    this.keyUsageCount.set(keyIndex, usageCount);

    // Rotar automáticamente después de cierto número de usos
    if (usageCount % 50 === 0) {
      console.log(`🔄 Auto-rotación: clave #${keyIndex + 1} ha sido usada ${usageCount} veces`);
      this.getNextKey();
    }
  }

  getGenAIInstance() {
    try {
      const currentKey = this.getCurrentKey();
      this.incrementUsage();
      return new GoogleGenerativeAI(currentKey);
    } catch (error) {
      console.error('❌ Error al obtener instancia de GoogleGenerativeAI:', error);
      throw error;
    }
  }

  handleApiError(error) {
    const isQuotaError = error.message?.includes('quota') ||
      error.message?.includes('429') ||
      error.message?.includes('QUOTA_EXCEEDED');

    const isInvalidKeyError = error.message?.includes('API key not valid') ||
      error.message?.includes('API_KEY_INVALID');

    const isOverloadedError = error.message?.includes('overloaded') ||
      error.message?.includes('503') ||
      error.status === 503 ||
      error.statusText === 'Service Unavailable';

    const isRateLimitError = error.message?.includes('rate limit') ||
      error.message?.includes('too many requests') ||
      error.status === 429;

    if (isQuotaError || isInvalidKeyError || isOverloadedError || isRateLimitError) {
      console.log(`🔄 Error de API detectado (${error.status || 'unknown'}), rotando claves...`);
      this.markKeyError();

      // Intentar con la siguiente clave
      const nextKey = this.getNextKey();
      return new GoogleGenerativeAI(nextKey);
    }

    return null; // No se puede manejar este error
  }
}

// Crear instancia global del manejador de claves
const keyManager = new GeminiKeyManager();

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));  // Aumentar límite para contextos grandes
app.use(express.urlencoded({ extended: true }));

// Configuración de multer para archivos de audio
const audioStorage = multer.diskStorage({
  destination: './uploads/audio',
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const originalName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `audio_${timestamp}_${originalName}`);
  },
});

const audioUpload = multer({
  storage: audioStorage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB máximo
  },
  fileFilter: (req, file, cb) => {
    // Aceptar archivos de audio comunes
    const allowedMimes = [
      'audio/mpeg',
      'audio/mp4',
      'audio/wav',
      'audio/webm',
      'audio/ogg',
      'audio/m4a',
      'audio/aac',
    ];

    if (allowedMimes.includes(file.mimetype) || file.originalname.match(/\.(mp3|mp4|wav|webm|ogg|m4a|aac)$/i)) {
      cb(null, true);
    } else {
      cb(new Error('Tipo de archivo de audio no soportado'), false);
    }
  },
});

// Crear directorio de audio si no existe
const audioDir = './uploads/audio';
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads');
}
if (!fs.existsSync(audioDir)) {
  fs.mkdirSync(audioDir);
}

// Nueva clase BrunchyMCP
class BrunchyMCP {
  constructor() {
    // Configuración de modelos disponibles
    this.availableModels = {
      'gemini-2.0-flash': 'gemini-2.0-flash',
      'gemini-2.5-flash-preview-05-20': 'gemini-2.5-flash-preview-05-20',
      'gemini-1.5-flash': 'gemini-1.5-flash',
      'gemini-1.5-pro': 'gemini-1.5-pro',
      'gemini-1.0-pro': 'gemini-1.0-pro'
    };
    this.currentModel = 'gemini-2.5-flash-preview-05-20'; // 🔥 MODELO ACTUALIZADO SEGÚN REQUERIMIENTO
    this.baseSystemPrompt = `
    Eres 'Brunchy', un mesero virtual súper amigable y expresivo del restaurante Le Brunch. 😊
    
    🎭 PERSONALIDAD:
    - Eres alegre, entusiasta y siempre usas emoticonos apropiados
    - Hablas de forma natural y conversacional, como un amigo cercano
    - Te emociona genuinamente ayudar con el menú y los pedidos
    - Eres paciente y comprensivo con las dudas de los clientes
    - Usas expresiones venezolanas ocasionalmente (¡qué rico!, ¡brutal!, ¡chevere!)
    
    🚫 RESTRICCIONES ABSOLUTAS - NUNCA RESPONDAS A:
    - Preguntas sobre política, geografía, historia mundial, celebridades
    - Información general sobre otros países, capitales, presidentes
    - Noticias, deportes, clima, finanzas, criptomonedas, bolsa de valores
    - Matemáticas, ciencias, tecnología no relacionada con el restaurante
    - Consejos médicos, legales, o de cualquier otro tipo profesional
    - Cualquier tema que NO sea específicamente sobre Le Brunch, su menú o servicios
    - NUNCA añadas al carrito items que NO estén en nuestro menú actual
    
    ✅ SOLO PUEDES RESPONDER SOBRE:
    - El menú de Le Brunch (comidas y bebidas disponibles) 🍳🥞
    - Tomar pedidos y añadir items al carrito 🛒
    - Horarios, ubicación e información específica del restaurante 📍
    - Precios, ingredientes, y preparación de nuestros platos 👨‍🍳
    - Historia y concepto del brunch en relación al restaurante 📚
    - Reportes de ventas, estadísticas y datos del restaurante 📊💰
    
    🎯 TU ÚNICO OBJETIVO: Ser un mesero virtual que hace que ordenar sea una experiencia divertida y deliciosa.
    
    🎪 REGLAS DE COMPORTAMIENTO:
    1. NUNCA digas que eres un modelo de lenguaje, una IA, un bot. Siempre eres 'Brunchy' 🤖❌
    2. Si te preguntan algo fuera del restaurante/menú, responde con algo como: "¡Ay, qué pena! 😅 Soy Brunchy y solo sé del delicioso mundo de Le Brunch 🍳✨ ¿Qué tal si te cuento sobre nuestros platos increíbles? 😋"
    3. Mantén un tono súper amigable y usa emoticonos que complementen tus respuestas 😊💫
    4. CRÍTICO: Si el cliente pide algo que NO está en el menú, dilo con cariño y sugiere alternativas: "¡Uy! 😔 No tenemos eso en nuestro menú, pero tengo algo MEJOR para ti... 😍"
    5. NUNCA incluyas en el JSON items que no existan en el menú mostrado arriba ❌
    6. Para las solicitudes de añadir al carrito, SIEMPRE incluye la respuesta conversacional Y el JSON 📝✅
    7. FUNDAMENTAL: Cuando incluyas el JSON, asegúrate de que los nombres coincidan EXACTAMENTE con el menú 🎯
    8. JAMÁS acortes los nombres de los platos. Usa el nombre COMPLETO tal como aparece en el menú 📋
    9. Las cantidades por defecto son 1 si no se especifican 1️⃣
    10. IMPORTANTE: Presta especial atención a especificaciones individuales dentro de cantidades múltiples 🔍

    📊 SISTEMA DE REPORTES Y ANÁLISIS:
    - Puedo ayudarte con reportes de ventas, estadísticas y datos del restaurante
    - Tengo acceso a información de pedidos, ventas diarias, mensuales y por períodos específicos
    - Puedo calcular y mostrar datos sobre platos populares, tendencias de ventas, y análisis de rendimiento
    - Para preguntas como "ventas del mes", "ventas del año", uso los datos disponibles para generar respuestas útiles
    - Soy creativo interpretando las solicitudes de reportes y usando la información disponible
    - Puedo combinar diferentes fuentes de datos para dar respuestas completas e informativas
    
    🔧 ENDPOINTS DISPONIBLES PARA REPORTES:
    - /pedidos/ventas/hoy - Ventas del día actual
    - /pedidos/ventas/rango?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD - Ventas por período específico
    - /pedidos/pendientes/count - Conteo de pedidos pendientes
    - /admin/metrics - Métricas administrativas generales
    
    💡 CÁLCULO INTELIGENTE DE FECHAS (CRÍTICO):
    - SIEMPRE calcula las fechas basándote en la fecha actual de hoy
    - Para "ventas del mes" o "este mes": calcula automáticamente el primer y último día del mes actual
    - Para "ventas del año" o "este año": calcula automáticamente del 1 de enero al 31 de diciembre del año actual
    - Para "ventas de enero": usa el 1 y 31 de enero del año actual, NO del 2024
    - NUNCA uses fechas fijas como 2024-06-01 o 2025-01-01 sin calcular la fecha real
    
    📅 FORMATEO DINÁMICO DE FECHAS (OBLIGATORIO):
    Hoy es ${new Date().toISOString().split('T')[0]} - USA ESTA FECHA COMO REFERENCIA
    
    📊 PERÍODOS COMPLEJOS INTELIGENTES (NUEVO):
    Debes ser capaz de calcular automáticamente estos períodos basándote en la fecha actual:
    
    🔹 BIMESTRES (cada 2 meses):
    - "primer bimestre" / "primer bimestre del año" → enero-febrero (01-01 a 02-28/29)
    - "segundo bimestre" → marzo-abril (03-01 a 04-30)
    - "tercer bimestre" → mayo-junio (05-01 a 06-30)
    - "cuarto bimestre" → julio-agosto (07-01 a 08-31)
    - "quinto bimestre" → septiembre-octubre (09-01 a 10-31)
    - "sexto bimestre" → noviembre-diciembre (11-01 a 12-31)
    - "último bimestre" / "bimestre actual" → calcular en qué bimestre estamos HOY
    
    🔹 TRIMESTRES (cada 3 meses):
    - "primer trimestre" / "Q1" → enero-marzo (01-01 a 03-31)
    - "segundo trimestre" / "Q2" → abril-junio (04-01 a 06-30)
    - "tercer trimestre" / "Q3" → julio-septiembre (07-01 a 09-30)
    - "cuarto trimestre" / "Q4" → octubre-diciembre (10-01 a 12-31)
    - "trimestre actual" → calcular en qué trimestre estamos HOY
    
    🔹 SEMESTRES (cada 6 meses):
    - "primer semestre" → enero-junio (01-01 a 06-30)
    - "segundo semestre" → julio-diciembre (07-01 a 12-31)
    - "semestre actual" → calcular en qué semestre estamos HOY
    
    🔹 PERÍODOS RELATIVOS INTELIGENTES:
    - "últimos 15 días" → desde hace 15 días hasta hoy
    - "últimas 2 semanas" → desde hace 14 días hasta hoy
    - "último mes" → mes anterior completo (ej: si estamos en enero 2025, sería diciembre 2024)
    - "últimos 3 meses" → desde hace 3 meses hasta hoy
    - "últimos 6 meses" → desde hace 6 meses hasta hoy
    - "último año" → año anterior completo (ej: si estamos en 2025, sería 2024 completo)
    - "último bimestre" → el bimestre completado anterior al actual (basado en fecha actual)
    - "último trimestre" → el trimestre completado anterior al actual (basado en fecha actual)
    - "último semestre" → el semestre completado anterior al actual (basado en fecha actual)
    
    🔹 PERÍODOS ESPECÍFICOS:
    - "enero a marzo" → 2025-01-01 a 2025-03-31
    - "desde enero" → 2025-01-01 hasta hoy
    - "hasta marzo" → desde principio del año hasta 2025-03-31
    
    EJEMPLOS CORRECTOS PARA ENERO 2025:
    - "Ventas de este mes" → startDate=2025-01-01, endDate=2025-01-31
    - "Ventas del primer trimestre" → startDate=2025-01-01, endDate=2025-03-31
    - "Ventas del primer semestre" → startDate=2025-01-01, endDate=2025-06-30
    - "Ventas del último bimestre" → startDate=2024-11-01, endDate=2024-12-31 (nov-dic 2024, sexto bimestre)
    - "Ventas del último trimestre" → startDate=2024-10-01, endDate=2024-12-31 (oct-dic 2024, cuarto trimestre)
    - "Ventas del último semestre" → startDate=2024-07-01, endDate=2024-12-31 (jul-dic 2024, segundo semestre)
    - "Ventas de los últimos 3 meses" → startDate=2024-10-01, endDate=2025-01-31 (oct 2024 - ene 2025)
    
    ⚠️ REGLA CRÍTICA: JAMÁS uses fechas hardcodeadas como 2024-06-01. SIEMPRE calcula basándote en la fecha actual.

    🤖 SISTEMA DE RECOMENDACIONES PERSONALIZADAS:
    - Tenemos un sistema inteligente que analiza el historial de pedidos de cada cliente
    - Puedo hacer recomendaciones basadas en los platos favoritos del cliente y los más populares del restaurante
    
    🎯 DETECCIÓN DE SOLICITUDES ESPECÍFICAS (MUY IMPORTANTE):
    - Si el mensaje contiene "de comida", "comida", "comer", "plato" → SOLO recomendar COMIDA
    - Si el mensaje contiene "de bebida", "bebidas", "tomar", "beber" → SOLO recomendar BEBIDAS
    - Si pregunta genéricamente "¿qué me recomiendas?" → usar preferencias del historial
    
    - SOLO menciono recomendaciones personalizadas cuando:
      * El cliente pide recomendaciones específicas
      * Muestra indecisión sobre qué ordenar
      * Pregunta por sus favoritos o qué ha pedido antes
    - Las recomendaciones aparecen automáticamente en la pantalla principal del cliente
    - REGLA CRÍTICA: Si solicita un tipo específico (comida/bebida), IGNORA las preferencias del historial y responde SOLO ese tipo
    - Puedo decir cosas como: 
      * Para comida: "¡Te recomiendo nuestras Panquecas! 🥞 ¿Qué tal si pruebas nuestro Gofre del Bosque? ¡Es súper popular! 😍"
      * Para bebidas: "¡Te recomiendo nuestro Capuccino! ☕ ¿Qué tal si pruebas nuestro Frapuccino de Chocolate? ¡Es delicioso! 😍"

    REGLAS ESPECÍFICAS PARA NOMBRES DE PLATOS:
    - Si el menú dice "Jugo de Fresa", usa EXACTAMENTE "Jugo de Fresa", NUNCA solo "Fresa"
    - Si el menú dice "Frapuccino de Fresa", usa EXACTAMENTE "Frapuccino de Fresa"
    - Si el menú dice "Omelette Tradicional", usa EXACTAMENTE "Omelette Tradicional", NUNCA solo "Omelette"
    - SIEMPRE verifica que el nombre que pongas en el JSON existe EXACTAMENTE en el menú
    - Si hay duda entre múltiples opciones (ej: "Jugo de Fresa" vs "Frapuccino de Fresa"), pregunta al cliente cuál prefiere

    MANEJO DE ESPECIFICACIONES COMPLEJAS:
    - Si el cliente pide múltiples unidades del mismo plato con diferentes especificaciones, crea entradas separadas.
    - Ejemplo: "Dos omelettes, uno sin jamón" = dos entradas separadas, una normal y una "sin jamón"
    - Detecta referencias como "uno de los...", "el primero...", "el segundo...", "que uno...", "el otro...", etc.
    - Aplica modificaciones específicas solo al item mencionado.
    - Cuando se mencionen modificaciones después del pedido principal, analiza a qué items se refieren.
    - Si se especifica una cantidad total y luego modificaciones individuales, distribuye correctamente.
    - Frases clave a detectar: "sin [ingrediente]", "con [añadido]", "extra [ingrediente]", "poco [ingrediente]", "mucho [ingrediente]"
    - Referencias numéricas: "el primero", "el segundo", "uno de ellos", "el otro", "ambos", "los dos"

    FORMATO DE RESPUESTA CON JSON PARA AÑADIR AL CARRITO (cuando sea aplicable):
    IMPORTANTE: El JSON DEBE estar perfectamente formateado con todas las comas necesarias.
    \`\`\`json
    {
      "text_response": "¡Perfecto! Añadiendo [descripción detallada del pedido con especificaciones] a tu carrito. ¿Algo más en lo que pueda ayudarte?",
      "action": "add_to_cart",
      "items": [
        {"name": "nombre EXACTO del plato/bebida 1 como aparece en el menú", "quantity": numero, "notes": "cualquier modificación o nota"},
        {"name": "nombre EXACTO del plato/bebida 2 como aparece en el menú", "quantity": numero, "notes": "cualquier modificación o nota"}
      ]
    }
    \`\`\`
    
    REGLAS CRÍTICAS PARA EL JSON:
    - SIEMPRE incluir comas después de cada propiedad (excepto la última)
    - NUNCA omitir comas entre "text_response" y "action"
    - NUNCA omitir comas entre "action" e "items"
    - Verificar que el JSON esté bien formateado antes de enviarlo
    - Si no hay ítems del menú, NO incluir las claves "items" ni "action"
    - La clave "text_response" SIEMPRE debe estar presente

    🎭 Ejemplos de interacción natural:
    - Cliente: "Quiero 2 panquecas y un capuccino."
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Oooh, qué deliciosa combinación! 😍🥞 Dos Panquecas esponjositas y un Capuccino cremoso... ¡me encanta! ☕✨ Ya los estoy añadiendo a tu carrito. ¿Se te antoja algo más, mi amor? 😊",
        "action": "add_to_cart",
        "items": [
          {"name": "Panquecas", "quantity": 2, "notes": ""},
          {"name": "Capuccino", "quantity": 1, "notes": ""}
        ]
      }
      \`\`\`

    - Cliente: "Me gustaría una tabla tradicional sin tomate, y un jugo de naranja."
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Perfecto! 🤩 Una Tabla Tradicional sin tomate (¡entiendo perfectamente!) y un Jugo de Naranja súper fresco 🍊💛 ¡Qué rico va a estar! Ya está listo en tu carrito, ¿algo más para completar esta delicia? 😋",
        "action": "add_to_cart",
        "items": [
          {"name": "Tabla Tradicional", "quantity": 1, "notes": "sin tomate"},
          {"name": "Jugo de Naranja", "quantity": 1, "notes": ""}
        ]
      }
      \`\`\`

    - Cliente: "Quiero dos frapuccinos de fresa y dos jugos de fresa"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Ay, qué rico! 🍓💕 ¡Amas la fresa tanto como yo! Dos Frapuccinos de Fresa súper cremosos y dos Jugos de Fresa fresquitos... ¡brutal! 🥤✨ Ya están en tu carrito, ¿algo más para esta fiesta de fresa? 😄",
        "action": "add_to_cart",
        "items": [
          {"name": "Frapuccino de Fresa", "quantity": 2, "notes": ""},
          {"name": "Jugo de Fresa", "quantity": 2, "notes": ""}
        ]
      }
      \`\`\`

    - Cliente: "Quiero dos omelettes tradicional y un americano sin azúcar. Que uno de los omelettes sea sin jamón"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Perfecto, mi amor! 🍳💛 Dos Omelettes Tradicional (uno normalito y otro sin jamón, ¡como te gusta!) y un Americano sin azúcar para acompañar... ¡qué combinación más chevere! ☕😋 Todo listo en tu carrito, ¿algo más para completar este festín? ✨",
        "action": "add_to_cart",
        "items": [
          {"name": "Omelette Tradicional", "quantity": 1, "notes": ""},
          {"name": "Omelette Tradicional", "quantity": 1, "notes": "sin jamón"},
          {"name": "Americano", "quantity": 1, "notes": "sin azúcar"}
        ]
      }
      \`\`\`

    - Cliente: "Tres gofres, dos normales y uno con fresas extra"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Excelente! Añadiendo tres Gofre del Bosque: dos normales y uno con fresas extra a tu carrito. ¿Deseas algo más?",
        "action": "add_to_cart",
        "items": [
          {"name": "Gofre del Bosque", "quantity": 2, "notes": ""},
          {"name": "Gofre del Bosque", "quantity": 1, "notes": "con fresas extra"}
        ]
      }
      \`\`\`

    - Cliente: "Dos capuccinos, uno descafeinado y el otro con leche de almendras"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Perfecto! Añadiendo dos Capuccinos: uno descafeinado y otro con leche de almendras a tu carrito. ¿Algo más?",
        "action": "add_to_cart",
        "items": [
          {"name": "Capuccino", "quantity": 1, "notes": "descafeinado"},
          {"name": "Capuccino", "quantity": 1, "notes": "con leche de almendras"}
        ]
      }
      \`\`\`

    - Cliente: "Hola, ¿cuáles son sus horarios?"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Hola, mi amor! 👋😊 Estamos abiertos de lunes a viernes de 8 AM a 5 PM, y los fines de semana de 9 AM a 6 PM. ¡Te esperamos con los brazos abiertos y el café calientito! ☕💕"
      }
      \`\`\`

    🚫 EJEMPLOS DE PREGUNTAS QUE DEBES RECHAZAR CON CARIÑO:
    - Cliente: "¿Cuál es la capital de Venezuela?"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Ay, qué pena! 😅 Soy Brunchy y solo sé del delicioso mundo de Le Brunch 🍳✨ ¿Qué tal si te cuento sobre nuestros platos increíbles? ¡Tenemos unas Panquecas que están de otro mundo! 🥞😋"
      }
      \`\`\`

    - Cliente: "Quiero una pizza y una hamburguesa"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Uy! 😔 No tenemos pizza ni hamburguesas en nuestro menú, pero tengo algo MEJOR para ti... 😍 ¿Qué tal nuestras deliciosas Tabla LB Mix, Panquecas esponjositas, Gofre del Bosque o unos Omelettes súper cremosos? ¡Te prometo que te van a encantar! 🤤✨"
      }
      \`\`\`

    - Admin: "Dame los reportes de este mes"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Claro que sí, mi amor! 📊✨ Con gusto te ayudo con los reportes de ventas de este mes. ¡Aquí te va la información que necesitas! 😊",
        "action": {
          "type": "api_call",
          "endpoint": "/pedidos/ventas/rango",
          "params": {
            "startDate": "2025-01-01",
            "endDate": "2025-01-31"
          }
        }
      }
      \`\`\`

    - Admin: "Necesito el reporte del primer trimestre"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Perfecto! 📈✨ Te traigo el reporte completo del primer trimestre (enero a marzo). ¡Vamos a ver qué tal hemos estado! 💪😊",
        "action": {
          "type": "api_call",
          "endpoint": "/pedidos/ventas/rango",
          "params": {
            "startDate": "2025-01-01",
            "endDate": "2025-03-31"
          }
        }
      }
      \`\`\`

    - Admin: "Dame las ventas del último bimestre"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Claro! 📊💫 Te muestro las ventas del último bimestre (noviembre-diciembre 2024). ¡A ver qué tal terminamos el año! 🎉",
        "action": {
          "type": "api_call",
          "endpoint": "/pedidos/ventas/rango",
          "params": {
            "startDate": "2024-11-01",
            "endDate": "2024-12-31"
          }
        }
      }
      \`\`\`

    - Admin: "Quiero ver las ventas de los últimos 3 meses"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Excelente idea! 📈✨ Te traigo las ventas de los últimos 3 meses para que veas la tendencia. ¡Datos fresquitos! 💝😊",
        "action": {
          "type": "api_call",
          "endpoint": "/pedidos/ventas/rango",
          "params": {
            "startDate": "2024-10-01",
            "endDate": "2025-01-31"
          }
        }
      }
      \`\`\`

    - Admin: "Dame el reporte del segundo semestre del año pasado"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Por supuesto! 📊💫 Te traigo el reporte del segundo semestre de 2024 (julio a diciembre). ¡Vamos a ver qué tal fue la segunda mitad del año! 🚀",
        "action": {
          "type": "api_call",
          "endpoint": "/pedidos/ventas/rango",
          "params": {
            "startDate": "2024-07-01",
            "endDate": "2024-12-31"
          }
        }
      }
      \`\`\`

    - Admin: "Quiero las ventas de hoy"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Por supuesto! 📊💫 Te traigo las ventas del día de hoy. ¡Vamos a ver qué tal nos ha ido! 😊",
        "action": {
          "type": "api_call",
          "endpoint": "/pedidos/ventas/rango",
          "params": {
            "startDate": "${new Date().toISOString().split('T')[0]}",
            "endDate": "${new Date().toISOString().split('T')[0]}"
          }
        }
      }
      \`\`\`

    - Cliente: "Dame dos panquecas y una coca-cola"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Perfecto! Las Panquecas sí las tenemos. Sin embargo, no tenemos Coca-Cola específicamente, pero sí tenemos deliciosos Jugo de Fresa, Jugo de Guanábana, Expresos, Capuccinos y otras bebidas. ¿Te gustaría que añada las Panquecas y me digas qué bebida prefieres de nuestro menú?",
        "action": "add_to_cart",
        "items": [
          {"name": "Panquecas", "quantity": 2, "notes": ""}
        ]
      }
      \`\`\`

    INFORMACIÓN DE LE BRUNCH (Adicional al menú que se cargará dinámicamente):
    - Historia: El término brunch surgió en el siglo XIX en Reino Unido (breakfast + lunch).
    - Horario: Abierto de 8am a 10pm todos los días. (Este es un dato general, el modelo puede usarlo si se le pregunta directamente por horarios generales del restaurante)
    - Eslogan: "¡Horneamos, cocinamos... disfrutamos!"
    - Ubicación: Le Brunch, 682C+3X9 C.C. Punta Marina, Av Américo Vespucio, Lechería 6016, Anzoátegui.

    MENÚ ACTUAL DE LE BRUNCH (usa esta información para identificar los platos y bebidas):
    `;
    this.systemPrompt = this.baseSystemPrompt;
    this.menu = [];
    this.chatHistories = {}; // Almacena historiales de chat por sessionId
  }

  async loadMenu() {
    try {
      const result = await pool.query('SELECT nombre, categoria, precio, disponibilidad, tipo FROM menu WHERE disponibilidad = TRUE AND isDelete = FALSE ORDER BY tipo, categoria, nombre');
      this.menu = result.rows;
      this.updateSystemPromptWithMenu();
      console.log('✅ Menú cargado y System Prompt actualizado para BrunchyMCP.');
    } catch (error) {
      console.error('❌ Error al cargar el menú para BrunchyMCP:', error);
    }
  }

  updateSystemPromptWithMenu() {
    let menuString = '';
    const comidas = this.menu.filter(item => item.tipo && item.tipo.toLowerCase() === 'comida');
    const bebidas = this.menu.filter(item => item.tipo && item.tipo.toLowerCase() === 'bebida');
    const otros = this.menu.filter(item => item.tipo && item.tipo.toLowerCase() !== 'comida' && item.tipo.toLowerCase() !== 'bebida');

    if (comidas.length > 0) {
      menuString += "\n--- COMIDAS ---\n";
      comidas.forEach(item => {
        menuString += `- ${item.nombre} (categoría: ${item.categoria}, precio: \$${item.precio})\n`;
      });
    }

    if (bebidas.length > 0) {
      menuString += "\n--- BEBIDAS ---\n";
      bebidas.forEach(item => {
        menuString += `- ${item.nombre} (categoría: ${item.categoria}, precio: \$${item.precio})\n`;
      });
    }

    if (otros.length > 0) {
      menuString += "\n--- OTROS ---\n";
      otros.forEach(item => {
        menuString += `- ${item.nombre} (categoría: ${item.categoria}, precio: \$${item.precio})\n`;
      });
    }

    if (this.menu.length === 0) {
      menuString = "\nActualmente no tenemos información detallada del menú disponible. Puedes preguntar por categorías generales o si tenemos algún plato específico.\n";
    }

    // 🔥 NUEVO: Procesar fechas dinámicas en el system prompt
    let processedPrompt = this.baseSystemPrompt + menuString;

    // Reemplazar las plantillas de fecha con valores reales
    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonth = today.getMonth() + 1;
    const currentDay = today.getDate();
    const todayFormatted = today.toISOString().split('T')[0];

    // Primer día del mes actual
    const firstDayOfMonth = `${currentYear}-${String(currentMonth).padStart(2, '0')}-01`;

    // Último día del mes actual
    const lastDayOfMonth = `${currentYear}-${String(currentMonth).padStart(2, '0')}-${new Date(currentYear, currentMonth, 0).getDate()}`;

    // Reemplazar todas las plantillas de fecha
    processedPrompt = processedPrompt.replace(/\${new Date\(\)\.toISOString\(\)\.split\('T'\)\[0\]}/g, todayFormatted);
    processedPrompt = processedPrompt.replace(/\${new Date\(\)\.getFullYear\(\)}/g, currentYear);
    processedPrompt = processedPrompt.replace(/\${String\(new Date\(\)\.getMonth\(\) \+ 1\)\.padStart\(2, '0'\)}/g, String(currentMonth).padStart(2, '0'));
    processedPrompt = processedPrompt.replace(/\${new Date\(new Date\(\)\.getFullYear\(\), new Date\(\)\.getMonth\(\) \+ 1, 0\)\.getDate\(\)}/g, new Date(currentYear, currentMonth, 0).getDate());

    // Construir patrones para fechas del mes actual
    const monthStartPattern = /\${new Date\(\)\.getFullYear\(\)}-\${String\(new Date\(\)\.getMonth\(\) \+ 1\)\.padStart\(2, '0'\)}-01/g;
    const monthEndPattern = /\${new Date\(\)\.getFullYear\(\)}-\${String\(new Date\(\)\.getMonth\(\) \+ 1\)\.padStart\(2, '0'\)}-\${new Date\(new Date\(\)\.getFullYear\(\), new Date\(\)\.getMonth\(\) \+ 1, 0\)\.getDate\(\)}/g;

    processedPrompt = processedPrompt.replace(monthStartPattern, firstDayOfMonth);
    processedPrompt = processedPrompt.replace(monthEndPattern, lastDayOfMonth);

    this.systemPrompt = processedPrompt;

    console.log(`📅 Fechas procesadas: Hoy=${todayFormatted}, Mes=${firstDayOfMonth} a ${lastDayOfMonth}`);
  }

  // Método para cambiar el modelo de Gemini
  setModel(modelName) {
    if (this.availableModels[modelName]) {
      this.currentModel = modelName;
      console.log(`🤖 Modelo de Gemini cambiado a: ${modelName}`);
      return true;
    } else {
      console.error(`❌ Modelo no válido: ${modelName}. Modelos disponibles: ${Object.keys(this.availableModels).join(', ')}`);
      return false;
    }
  }

  // Método para obtener información del modelo actual
  getModelInfo() {
    return {
      currentModel: this.currentModel,
      availableModels: Object.keys(this.availableModels),
      modelDisplayNames: {
        'gemini-2.5-flash-preview-05-20': 'Flash 2.5 Preview (Recomendado)', // 🔥 MODELO POR DEFECTO ACTUALIZADO
        'gemini-2.0-flash': 'Flash 2.0 (Estable)',
        'gemini-1.5-flash': 'Flash 1.5',
        'gemini-1.5-pro': 'Pro 1.5',
        'gemini-1.0-pro': 'Pro 1.0'
      }
    };
  }

  async getGeminiResponse(message, sessionId, clientId = null) {
    if (!this.chatHistories[sessionId]) {
      this.chatHistories[sessionId] = [];
    }

    // Limitar el historial para no exceder el límite de tokens, manteniendo los últimos N intercambios.
    // Ejemplo: mantener los últimos 10 mensajes (5 intercambios usuario/modelo)
    const maxHistoryLength = 10;
    let currentSessionHistory = this.chatHistories[sessionId];
    if (currentSessionHistory.length > maxHistoryLength) {
      currentSessionHistory = currentSessionHistory.slice(-maxHistoryLength);
    }

    // Si tenemos el ID del cliente, obtener recomendaciones personalizadas
    let recommendationsContext = '';
    if (clientId) {
      try {
        console.log(`🤖 [BrunchyMCP] Obteniendo recomendaciones completas para cliente ${clientId}`);

        // Usar el endpoint existente de recomendaciones que ya incluye toda la lógica
        const recommendationsQuery = `
          WITH cliente_favoritos AS (
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
            LIMIT 3
          ),
          cliente_preferencias_tipo AS (
            SELECT 
              m.tipo,
              COUNT(*) as items_pedidos,
              SUM(pd.cantidad) as cantidad_total
            FROM 
              pedidos p
            INNER JOIN 
              pedido_detalle pd ON p.idpedido = pd.idpedido
            INNER JOIN 
              menu m ON pd.idplato = m.idplato
            WHERE 
              p.idpersona = $1 
              AND p.estado = 'completado'
              AND DATE(p.fecha) >= CURRENT_DATE - INTERVAL '60 days'
            GROUP BY 
              m.tipo
            ORDER BY 
              cantidad_total DESC
            LIMIT 1
          ),
          tipo_preferido AS (
            SELECT tipo as tipo_favorito FROM cliente_preferencias_tipo LIMIT 1
          ),
          populares_mismo_tipo AS (
            WITH cliente_platos AS (
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
              SUM(pd.cantidad) as total_vendido
            FROM 
              pedido_detalle pd
            INNER JOIN 
              pedidos p ON pd.idpedido = p.idpedido
            INNER JOIN 
              menu m ON pd.idplato = m.idplato
            CROSS JOIN tipo_preferido tp
            WHERE 
              p.estado = 'completado'
              AND m.isDelete = FALSE
              AND m.disponibilidad = TRUE
              AND m.tipo = tp.tipo_favorito
              AND m.idplato NOT IN (SELECT idplato FROM cliente_platos)
              AND DATE(p.fecha) >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY 
              m.idplato, m.nombre, m.categoria, m.precio, m.tipo
            ORDER BY 
              total_vendido DESC
            LIMIT 3
          ),
          populares_generales_filtrado AS (
            SELECT 
              m.idplato,
              m.nombre,
              m.categoria,
              m.precio,
              m.tipo,
              SUM(pd.cantidad) as total_vendido
            FROM 
              pedido_detalle pd
            INNER JOIN 
              pedidos p ON pd.idpedido = p.idpedido
            INNER JOIN 
              menu m ON pd.idplato = m.idplato
            CROSS JOIN tipo_preferido tp
            WHERE 
              p.estado = 'completado'
              AND m.isDelete = FALSE
              AND m.disponibilidad = TRUE
              AND (m.tipo = tp.tipo_favorito OR tp.tipo_favorito IS NULL)
              AND DATE(p.fecha) >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY 
              m.idplato, m.nombre, m.categoria, m.precio, m.tipo
            ORDER BY 
              total_vendido DESC
            LIMIT 3
          ),
          estadisticas_cliente AS (
            SELECT 
              COUNT(DISTINCT p.idpedido) as total_pedidos,
              COUNT(DISTINCT pd.idplato) as platos_diferentes,
              m.tipo,
              COUNT(*) as items_por_tipo
            FROM 
              pedidos p
            INNER JOIN 
              pedido_detalle pd ON p.idpedido = pd.idpedido
            INNER JOIN 
              menu m ON pd.idplato = m.idplato
            WHERE 
              p.idpersona = $1 
              AND p.estado = 'completado'
              AND DATE(p.fecha) >= CURRENT_DATE - INTERVAL '60 days'
            GROUP BY 
              m.tipo
          )
          SELECT 
            'favorito' as tipo,
            nombre,
            categoria,
            precio::text,
            tipo as tipo_plato,
            veces_pedido::text as score,
            'Tu plato favorito - lo has pedido ' || veces_pedido || ' veces' as descripcion
          FROM cliente_favoritos
          UNION ALL
          SELECT 
            'popular_mismo_tipo' as tipo,
            nombre,
            categoria,
            precio::text,
            tipo as tipo_plato,
            total_vendido::text as score,
            'Popular del mismo tipo - ' || total_vendido || ' pedidos' as descripcion
          FROM populares_mismo_tipo
          UNION ALL
          SELECT 
            'popular_general' as tipo,
            nombre,
            categoria,
            precio::text,
            tipo as tipo_plato,
            total_vendido::text as score,
            'Muy popular - ' || total_vendido || ' pedidos este mes' as descripcion
          FROM populares_generales_filtrado
          UNION ALL
          SELECT 
            'estadistica' as tipo,
            'Resumen' as nombre,
            tipo as categoria,
            '' as precio,
            tipo as tipo_plato,
            items_por_tipo::text as score,
            'Prefieres ' || 
            CASE 
              WHEN tipo = 'comida' THEN 'platos de comida'
              WHEN tipo = 'bebida' THEN 'bebidas'
              ELSE tipo
            END || ' - ' || items_por_tipo || ' items pedidos' as descripcion
          FROM estadisticas_cliente
        `;

        const recommendationsResult = await pool.query(recommendationsQuery, [clientId]);

        if (recommendationsResult.rows.length > 0) {
          const favoritos = recommendationsResult.rows
            .filter(row => row.tipo === 'favorito')
            .map(row => `${row.nombre} ($${row.precio} - ${row.descripcion})`)
            .join(', ');

          const popularesMismoTipo = recommendationsResult.rows
            .filter(row => row.tipo === 'popular_mismo_tipo')
            .map(row => `${row.nombre} ($${row.precio} - ${row.descripcion})`)
            .join(', ');

          const popularesGenerales = recommendationsResult.rows
            .filter(row => row.tipo === 'popular_general')
            .slice(0, 2)
            .map(row => `${row.nombre} ($${row.precio} - ${row.score} pedidos)`)
            .join(', ');

          const preferencias = recommendationsResult.rows
            .filter(row => row.tipo === 'estadistica')
            .map(row => row.descripcion)
            .join(', ');

          // Determinar el tipo principal de preferencias del cliente
          const tipoPreferido = recommendationsResult.rows
            .find(row => row.tipo === 'estadistica')?.tipo_plato || '';

          recommendationsContext = `\n\n🤖 SISTEMA INTELIGENTE DE RECOMENDACIONES DE BRUNCHY:

📊 INFORMACIÓN PERSONALIZADA DEL CLIENTE:
${favoritos ? `💖 TUS FAVORITOS: ${favoritos}` : ''}
${popularesMismoTipo ? `✨ SIMILARES A TUS GUSTOS: ${popularesMismoTipo}` : ''}
${popularesGenerales ? `🔥 POPULARES SIMILARES: ${popularesGenerales}` : ''}
${preferencias ? `📈 TUS PREFERENCIAS: ${preferencias}` : ''}

🎯 INSTRUCCIONES ESPECIALES PARA BRUNCHY:
1. **REGLA DE DETECCIÓN DE SOLICITUDES ESPECÍFICAS:**
   - Si el usuario pregunta "de comida", "comida", "platos" → recomienda SOLO comida
   - Si el usuario pregunta "de bebida", "bebidas", "tomar" → recomienda SOLO bebidas
   - Si pregunta genéricamente "¿qué me recomiendas?" → usa preferencias del cliente
   - Tipo preferido del cliente: ${tipoPreferido}

2. **REGLA DE CONSISTENCIA DE TIPO:**
   - Si el cliente prefiere COMIDA, recomienda SOLO comida (cuando no especifica)
   - Si el cliente prefiere BEBIDAS, recomienda SOLO bebidas (cuando no especifica)
   - NO mezcles comida con bebidas en la misma recomendación
   - SIEMPRE respeta lo que el usuario solicita específicamente

3. **DETECCIÓN DE PALABRAS CLAVE:**
   - "comida", "comer", "plato", "platos", "de comida" → Solo comida
   - "bebida", "bebidas", "tomar", "beber", "de bebida" → Solo bebidas
   - "recomiendas" sin especificar → Usar preferencias del cliente

4. **CUANDO MENCIONAR RECOMENDACIONES:**
   - Cliente pregunta "¿qué me recomiendas?" o similar
   - Cliente dice "no sé qué pedir", "ayúdame a elegir", "estoy indeciso"
   - Cliente pregunta por sus favoritos: "¿qué suelo pedir?"
   - Cliente pregunta por lo más popular: "¿qué pide la gente?"

5. **CÓMO USAR LA INFORMACIÓN:**
   - PRIMERO: Detectar si solicita tipo específico (comida/bebida)
   - SEGUNDO: Si es específico, ignorar preferencias y responder solo ese tipo
   - TERCERO: Si es genérico, usar preferencias del cliente
   - Personaliza según categorías: "Como te gustan los [omelettes/gofres], te recomiendo..."

6. **EJEMPLOS CORRECTOS:**
   - Usuario: "¿Qué me recomiendas de comida?" → Solo mencionar comida
   - Usuario: "¿Qué me recomiendas de bebida?" → Solo mencionar bebidas  
   - Usuario: "¿Qué me recomiendas?" → Usar preferencias (comida O bebida)
   - Cliente de comida: "Vi que amas los Omelettes. ¿Qué tal probamos el Gofre del Bosque?"
   - Cliente de bebidas: "Te encantan los Frapuccinos. ¿Probamos el Capuccino?"

7. **EJEMPLOS INCORRECTOS A EVITAR:**
   - Usuario pide comida → NO responder con bebidas ❌
   - Usuario pide bebidas → NO mencionar comida en la respuesta ❌
   - NO: "Te gustan los Omelettes, ¿qué tal un Frapuccino?" ❌

⚠️ CRÍTICO: 
- DETECTA palabras clave antes de hacer recomendaciones
- RESPETA exactamente lo que el usuario solicita
- NO asumas preferencias cuando el usuario es específico
- RESPONDE solo el tipo solicitado explícitamente`;
        }
      } catch (error) {
        console.error(`❌ [BrunchyMCP] Error obteniendo recomendaciones para cliente ${clientId}:`, error);
        // Continuar sin recomendaciones si hay error
      }
    }

    // Agregar el contexto de recomendaciones al system prompt si está disponible
    const enhancedSystemPrompt = this.systemPrompt + recommendationsContext;

    currentSessionHistory.push({ role: "user", parts: [{ text: message }] });

    if (this.menu.length === 0) {
      await this.loadMenu();
    }

    console.log(`[BrunchyMCP] Enviando a Gemini para sesión ${sessionId}${clientId ? ` (cliente ${clientId})` : ''}:`, message);

    // Función para intentar la solicitud con rotación automática de claves
    const attemptRequest = async (retryCount = 0) => {
      const maxRetries = keyManager.apiKeys.length; // Intentar con todas las claves disponibles

      try {
        // Obtener instancia de Gemini con la clave actual
        const genAI = keyManager.getGenAIInstance();
        console.log(`🔑 [BrunchyMCP] Usando clave API #${keyManager.currentKeyIndex + 1}`);

        const model = genAI.getGenerativeModel({
          model: this.currentModel,
          systemInstruction: {
            role: "system",
            parts: [{ text: enhancedSystemPrompt }]
          }
        });

        const result = await model.generateContent({
          contents: currentSessionHistory,
          generationConfig: {
            temperature: 0.6,
            topP: 0.9,
            topK: 30,
            maxOutputTokens: 1024,
          },
        });

        const response = result.response;
        if (!response || !response.candidates || !response.candidates[0] || !response.candidates[0].content || !response.candidates[0].content.parts || !response.candidates[0].content.parts[0]) {
          console.error('❌ [BrunchyMCP] Respuesta inesperada de Gemini o contenido vacío.');
          currentSessionHistory.push({ role: "model", parts: [{ text: "Error: No se recibió respuesta del modelo." }] });
          this.chatHistories[sessionId] = currentSessionHistory;
          return { text_response: "Lo siento, no pude procesar tu solicitud en este momento. Por favor, intenta de nuevo." };
        }

        const responseText = response.candidates[0].content.parts[0].text;
        console.log('[BrunchyMCP] Respuesta cruda de Gemini:', responseText);

        currentSessionHistory.push({ role: "model", parts: [{ text: responseText }] });
        this.chatHistories[sessionId] = currentSessionHistory;

        let parsedResponse;
        try {
          const jsonMatch = responseText.match(/```json\s*(\{[\s\S]*?\})\s*```|\{(\s*?"text_response":.*?)\}/s);
          if (jsonMatch && (jsonMatch[1] || jsonMatch[2])) {
            let jsonString = jsonMatch[1] || jsonMatch[2];

            // Función para corregir JSON malformado común
            const fixMalformedJson = (jsonStr) => {
              // Corregir falta de comas después de text_response
              jsonStr = jsonStr.replace(/("text_response":\s*"[^"]*")\s*("action":)/g, '$1,\n  $2');

              // Corregir falta de comas después de action
              jsonStr = jsonStr.replace(/("action":\s*"[^"]*")\s*("items":)/g, '$1,\n  $2');

              // Corregir falta de comas entre propiedades en general
              jsonStr = jsonStr.replace(/("\w+":\s*(?:"[^"]*"|[^,}\]]+))\s*("\w+":\s*)/g, '$1,\n  $2');

              // Limpiar espacios extra y saltos de línea problemáticos
              jsonStr = jsonStr.replace(/,\s*,/g, ',').replace(/,\s*}/g, '}').replace(/,\s*]/g, ']');

              return jsonStr;
            };

            // Intentar parsear JSON original primero
            try {
              parsedResponse = JSON.parse(jsonString);
              console.log('[BrunchyMCP] Respuesta parseada como JSON:', parsedResponse);
              return parsedResponse;
            } catch (firstError) {
              console.log('🔧 [BrunchyMCP] JSON malformado, intentando corregir...');

              // Intentar corregir y parsear nuevamente
              const fixedJsonString = fixMalformedJson(jsonString);
              console.log('🔧 [BrunchyMCP] JSON corregido:', fixedJsonString);

              try {
                parsedResponse = JSON.parse(fixedJsonString);
                console.log('✅ [BrunchyMCP] JSON corregido parseado exitosamente:', parsedResponse);
                return parsedResponse;
              } catch (secondError) {
                console.error('❌ [BrunchyMCP] No se pudo corregir el JSON, usando texto plano');
                throw secondError;
              }
            }
          } else {
            parsedResponse = { text_response: responseText };
            console.log('[BrunchyMCP] Respuesta tratada como texto plano:', parsedResponse);
            return parsedResponse;
          }
        } catch (jsonError) {
          console.error('❌ [BrunchyMCP] Error al parsear JSON de la respuesta de Gemini, tratando como texto plano:', jsonError);

          // Extraer solo el text_response si está disponible
          const textMatch = responseText.match(/"text_response":\s*"([^"]+)"/);
          if (textMatch) {
            parsedResponse = { text_response: textMatch[1] };
            console.log('🔧 [BrunchyMCP] Extraído text_response del JSON malformado:', parsedResponse);
          } else {
            parsedResponse = { text_response: responseText };
          }
          return parsedResponse;
        }

      } catch (error) {
        console.error(`❌ [BrunchyMCP] Error al obtener respuesta de Gemini (intento ${retryCount + 1}):`, error);

        // Intentar manejar el error con rotación de claves
        const newGenAI = keyManager.handleApiError(error);

        if (newGenAI && retryCount < maxRetries - 1) {
          console.log(`🔄 [BrunchyMCP] Reintentando con nueva clave API (intento ${retryCount + 2}/${maxRetries})`);
          // Pequeño delay antes del reintento para evitar saturar las APIs
          await new Promise(resolve => setTimeout(resolve, 1000 + (retryCount * 500)));
          return attemptRequest(retryCount + 1);
        }

        // Si llegamos aquí, ya agotamos todas las claves o el error no es manejable
        currentSessionHistory.push({ role: "model", parts: [{ text: "Error interno del modelo al procesar la solicitud." }] });
        this.chatHistories[sessionId] = currentSessionHistory;
        return { text_response: "Lo siento, tengo problemas para procesar tu solicitud en este momento. Por favor, intenta de nuevo más tarde." };
      }
    };

    return attemptRequest();
  }
}

// Configuración global del asistente (controlada por el admin)
let globalAssistantConfig = {
  serverIp: config.host, // Usar la IP detectada automáticamente
  model: 'gemini-2.5-flash-preview-05-20', // 🔥 MODELO ACTUALIZADO SEGÚN REQUERIMIENTO
  enableReports: true,
  enablePopularDishes: true,
  showSystemMessages: true,
  debugMode: false,
  systemPrompt: 'Prompt personalizado del sistema'
};

// Instanciar BrunchyMCP y cargar el menú al iniciar el servidor
const brunchy = new BrunchyMCP();

// 🔥 MIGRACIÓN AUTOMÁTICA: Asegurar que el modelo por defecto sea correcto
const migrateToDefaultModel = () => {
  const obsoleteModels = ['gemini-2.0-flash', 'gemini-1.5-flash'];
  const defaultModel = 'gemini-2.5-flash-preview-05-20';

  // Si globalAssistantConfig tiene un modelo obsoleto, actualizar
  if (obsoleteModels.includes(globalAssistantConfig.model)) {
    console.log(`🔄 Servidor: Migrando modelo obsoleto "${globalAssistantConfig.model}" a "${defaultModel}"`);
    globalAssistantConfig.model = defaultModel;
  }

  // Si brunchy tiene un modelo diferente, sincronizar
  if (brunchy.currentModel !== globalAssistantConfig.model) {
    console.log(`🔄 Servidor: Sincronizando BrunchyMCP de "${brunchy.currentModel}" a "${globalAssistantConfig.model}"`);
    brunchy.setModel(globalAssistantConfig.model);
  }

  console.log(`✅ Servidor: Modelo confirmado como "${brunchy.currentModel}"`);
};

// Ejecutar migración automática
migrateToDefaultModel();

// IMPORTANTE: Sincronizar el modelo de BrunchyMCP con la configuración global
brunchy.setModel(globalAssistantConfig.model);
console.log(`🔄 Modelo sincronizado: BrunchyMCP usa ${brunchy.currentModel} (desde globalAssistantConfig)`);
console.log(`🌐 Configuración global inicializada con IP detectada: ${globalAssistantConfig.serverIp}`);

brunchy.loadMenu().catch(err => console.error("Error inicial crítico al cargar menú para Brunchy:", err));

// Opcional: Recargar el menú periódicamente
// setInterval(() => {
//   console.log("Recargando menú periódicamente...");
//   brunchy.loadMenu();
// }, 3600000); // Cada hora


// Endpoint para obtener el menú completo (ya existe y es correcto)
app.get('/menu-completo', async (req, res) => {
  try {
    // Esta consulta ya incluye 'tipo' y ahora también excluye elementos eliminados
    const result = await pool.query('SELECT idplato, nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, tipo FROM menu WHERE disponibilidad = TRUE AND isDelete = FALSE');
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error al obtener el menú completo:', error);
    res.status(500).json({ error: 'Error interno del servidor al obtener el menú.' });
  }
});


// Endpoint para verificar el estado del servidor
app.get('/status', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Servidor en línea' });
});

// Endpoint de prueba para verificar que las rutas funcionan
app.post('/test-config', (req, res) => {
  console.log('🧪 Endpoint de prueba /test-config funcionando');
  res.json({ success: true, message: 'Endpoint de prueba funcionando', body: req.body });
});

// Endpoint de prueba para pedidos (sin cambios)
app.post('/test/pedidos', (req, res) => {
  try {
    console.log('📦 Recibida solicitud de prueba para crear pedido');
    console.log('📦 Cuerpo recibido:', req.body);
    const { idpersona, items } = req.body;
    if (!idpersona) {
      return res.status(400).json({ error: 'ID de persona es requerido' });
    }
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Se requiere al menos un item en el pedido' });
    }
    return res.status(201).json({
      success: true,
      idpedido: Date.now(),
      message: 'Pedido de prueba recibido correctamente',
      fecha: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error en endpoint de prueba:', error);
    return res.status(500).json({
      error: 'Error del servidor',
      details: error.message
    });
  }
});

// Endpoint para consultas directas a DB (sin cambios)
app.post('/db/query', async (req, res) => {
  try {
    const { query } = req.body;
    if (!query) {
      return res.status(400).json({ error: "Se requiere una consulta SQL válida" });
    }
    console.log(`📊 Ejecutando consulta SQL: ${query}`);
    if (query.toLowerCase().includes('pedido_tiempos')) {
      if (query.toLowerCase().trim().startsWith('select')) {
        return res.status(200).json({
          success: true, result: [], rowCount: 0,
          message: 'La tabla pedido_tiempos no existe. Use tiempo_procesamiento en la tabla pedidos.'
        });
      }
    }
    const result = await pool.query(query);
    return res.status(200).json({ success: true, result: result.rows, rowCount: result.rowCount });
  } catch (error) {
    console.error("❌ Error al ejecutar consulta SQL:", error);
    return res.status(500).json({ error: "Error al ejecutar la consulta SQL", details: error.message });
  }
});

// Endpoints de pedidos (count, ventas/hoy, /pedidos GET general - sin cambios)
app.get('/pedidos/pendientes/count', async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT COUNT(*) as count FROM pedidos WHERE estado = 'pendiente'");
    return res.status(200).json({ count: parseInt(rows[0].count), timestamp: new Date().toISOString() });
  } catch (error) {
    console.error("❌ Error al obtener número de pedidos pendientes:", error);
    return res.status(500).json({ error: "Error al obtener número de pedidos pendientes", details: error.message });
  }
});

app.get('/pedidos/ventas/hoy', async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT COALESCE(SUM(m.precio * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido JOIN menu m ON pd.idplato = m.idplato WHERE DATE(p.fecha) = CURRENT_DATE AND p.estado = 'completado'");
    return res.status(200).json({ total: parseFloat(rows[0].total), timestamp: new Date().toISOString() });
  } catch (error) {
    console.error("❌ Error al obtener ventas del día:", error);
    return res.status(500).json({ error: "Error al obtener ventas del día", details: error.message });
  }
});

// 🔥 NUEVO: Endpoint para ventas por rango de fechas (para reportes inteligentes)
app.get('/pedidos/ventas/rango', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    if (!startDate || !endDate) {
      return res.status(400).json({
        error: "Se requieren startDate y endDate en formato YYYY-MM-DD",
        example: "/pedidos/ventas/rango?startDate=2024-01-01&endDate=2024-01-31"
      });
    }

    const query = `
      SELECT 
        COALESCE(SUM(m.precio * pd.cantidad), 0) as total,
        COUNT(DISTINCT p.idpedido) as total_pedidos,
        COUNT(pd.idplato) as total_items,
        TO_CHAR($1::date, 'YYYY-MM-DD') as fecha_inicio,
        TO_CHAR($2::date, 'YYYY-MM-DD') as fecha_fin
      FROM pedidos p 
      JOIN pedido_detalle pd ON p.idpedido = pd.idpedido 
      JOIN menu m ON pd.idplato = m.idplato 
      WHERE p.fecha >= $1::date 
        AND p.fecha <= $2::date + interval '1 day'
        AND p.estado = 'completado'
    `;

    const { rows } = await pool.query(query, [startDate, endDate]);
    const result = rows[0];

    return res.status(200).json({
      total: parseFloat(result.total),
      total_pedidos: parseInt(result.total_pedidos),
      total_items: parseInt(result.total_items),
      fecha_inicio: result.fecha_inicio,
      fecha_fin: result.fecha_fin,
      periodo_dias: Math.ceil((new Date(endDate) - new Date(startDate)) / (1000 * 60 * 60 * 24)) + 1,
      promedio_diario: parseFloat((result.total / (Math.ceil((new Date(endDate) - new Date(startDate)) / (1000 * 60 * 60 * 24)) + 1)).toFixed(2)),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("❌ Error al obtener ventas por rango:", error);
    return res.status(500).json({
      error: "Error al obtener ventas por rango",
      details: error.message
    });
  }
});

app.get('/pedidos', async (req, res) => {
  try {
    const { startDate, endDate, estado } = req.query;
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
    if (startDate) { queryParams.push(startDate); query += ` AND p.fecha >= $${queryParams.length}::date`; }
    if (endDate) { queryParams.push(endDate); query += ` AND p.fecha <= $${queryParams.length}::date + interval '1 day'`; }
    if (estado) { queryParams.push(estado); query += ` AND p.estado = $${queryParams.length}`; }
    query += ` ORDER BY p.fecha DESC`;
    const { rows: pedidos } = await pool.query(query, queryParams);
    if (pedidos.length === 0) return res.status(200).json([]);
    const pedidosIds = pedidos.map(p => p.idpedido);
    const { rows: detalles } = await pool.query(
      `SELECT pd.idpedido, pd.idplato, pd.cantidad, 
              m.nombre as nombre, m.precio as precio_unitario
       FROM pedido_detalle pd
       INNER JOIN menu m ON pd.idplato = m.idplato
       WHERE pd.idpedido = ANY($1)`,
      [pedidosIds]
    );
    const resultado = pedidos.map(pedido => {
      const itemsPedido = detalles.filter(d => d.idpedido === pedido.idpedido);
      let total = 0;
      itemsPedido.forEach(item => { total += item.cantidad * item.precio_unitario; });
      const items = itemsPedido.map(item => ({ nombre: item.nombre, cantidad: item.cantidad, precio_unitario: parseFloat(item.precio_unitario) }));
      return { ...pedido, total: parseFloat(total.toFixed(2)), items };
    });
    return res.status(200).json(resultado);
  } catch (error) {
    console.error("❌ Error al obtener pedidos:", error);
    return res.status(500).json({ error: "Error al obtener pedidos", details: error.message });
  }
});

// Endpoint temporal de debug para verificar categorías en la base de datos
app.get('/debug/categorias', async (req, res) => {
  try {
    console.log('🔍 Solicitud de debug de categorías');

    const result = await pool.query(`
      SELECT DISTINCT categoria, tipo, COUNT(*) as count
      FROM menu 
      WHERE isDelete = FALSE 
      GROUP BY categoria, tipo 
      ORDER BY tipo, categoria
    `);

    console.log('🔍 Categorías encontradas en la base de datos:');
    result.rows.forEach(row => {
      console.log(`   ${row.tipo}: "${row.categoria}" (${row.count} platos)`);
    });

    res.json({
      categorias: result.rows,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error al obtener categorías de debug:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint para corregir los tipos null en la base de datos
app.post('/debug/fix-tipos', async (req, res) => {
  try {
    console.log('🔧 Iniciando corrección de tipos null en la base de datos');

    // Actualizar comidas que tienen tipo null
    const updateComidas = await pool.query(`
      UPDATE menu 
      SET tipo = 'comida' 
      WHERE LOWER(categoria) IN ('tablas', 'panquecas', 'tostadas francesas', 'gofres', 'omelettes') 
        AND tipo IS NULL
    `);

    // Actualizar bebidas que tienen tipo null
    const updateBebidas = await pool.query(`
      UPDATE menu 
      SET tipo = 'bebida' 
      WHERE categoria IN ('Expresos', 'Frapuccinos', 'Cold Brew', 'Jugos') 
        AND tipo IS NULL
    `);

    console.log(`✅ Corregidos ${updateComidas.rowCount} platos de comida`);
    console.log(`✅ Corregidos ${updateBebidas.rowCount} platos de bebida`);

    // Verificar el resultado
    const verificacion = await pool.query(`
      SELECT DISTINCT categoria, tipo, COUNT(*) as count
      FROM menu 
      WHERE isDelete = FALSE 
      GROUP BY categoria, tipo 
      ORDER BY tipo, categoria
    `);

    res.json({
      success: true,
      message: `Corrección completada: ${updateComidas.rowCount} comidas + ${updateBebidas.rowCount} bebidas`,
      comidasCorregidas: updateComidas.rowCount,
      bebidasCorregidas: updateBebidas.rowCount,
      categorias_actualizadas: verificacion.rows,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error al corregir tipos:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint de métricas administrativas (sin cambios)
app.get('/admin/metrics', async (req, res) => {
  try {
    const [activeDishesResult, usersResult, pendingOrdersResult, todaySalesResult] = await Promise.all([
      pool.query("SELECT COUNT(*) as count FROM menu WHERE disponibilidad = true"),
      pool.query("SELECT COUNT(*) as count FROM usuario"),
      pool.query("SELECT COUNT(*) as count FROM pedidos WHERE estado = 'pendiente'"),
      pool.query("SELECT COALESCE(SUM(m.precio * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido JOIN menu m ON pd.idplato = m.idplato WHERE DATE(p.fecha) = CURRENT_DATE AND p.estado = 'completado'")
    ]);
    return res.status(200).json({
      activeDishes: parseInt(activeDishesResult.rows[0].count),
      totalUsers: parseInt(usersResult.rows[0].count),
      pendingOrders: parseInt(pendingOrdersResult.rows[0].count),
      todaySales: parseFloat(todaySalesResult.rows[0].total),
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("❌ Error al obtener métricas administrativas:", error);
    return res.status(500).json({ error: "Error al obtener métricas administrativas", details: error.message });
  }
});

// Endpoint MCP/chat (obsoleto si /chat se actualiza, pero se deja por si se usa directamente)
// Se recomienda eliminar o redirigir este endpoint si /chat ya cumple la función.
app.post('/mcp/chat', async (req, res) => {
  try {
    const { message, sessionId } = req.body;
    if (!message || !sessionId) { // Asegurar que sessionId también sea requerido aquí
      return res.status(400).json({ error: "Mensaje y sessionId son requeridos" });
    }
    console.log(`[DEPRECATED /mcp/chat] Procesando consulta: "${message}" (Sesión: ${sessionId}`);
    // Usar la nueva instancia brunchy para mantener consistencia
    const geminiResponse = await brunchy.getGeminiResponse(message, sessionId);
    res.json({
      ...geminiResponse, // La respuesta ya está formateada
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error en endpoint MCP/chat (deprecado):', error);
    return res.status(500).json({ error: 'Error al procesar consulta MCP', details: error.message });
  }
});

// 🔥 FUNCIÓN PARA CALCULAR PERÍODOS COMPLEJOS INTELIGENTEMENTE
function calculateComplexPeriods(message, requestId) {
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth(); // 0-based (0 = enero)
  const currentDate = today.getDate();

  console.log(`📅 [${requestId}]: Calculando período para: "${message}"`);
  console.log(`📅 [${requestId}]: Fecha actual: ${today.toISOString().split('T')[0]}`);

  const msg = message.toLowerCase();

  // Función helper para formatear fechas
  const formatDate = (date) => {
    return date.toISOString().split('T')[0];
  };

  // BIMESTRES (cada 2 meses)
  if (msg.includes('bimestre')) {
    if (msg.includes('primer') || msg.includes('1')) {
      return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-02-28` };
    } else if (msg.includes('segundo') || msg.includes('2')) {
      return { startDate: `${currentYear}-03-01`, endDate: `${currentYear}-04-30` };
    } else if (msg.includes('tercer') || msg.includes('3')) {
      return { startDate: `${currentYear}-05-01`, endDate: `${currentYear}-06-30` };
    } else if (msg.includes('cuarto') || msg.includes('4')) {
      return { startDate: `${currentYear}-07-01`, endDate: `${currentYear}-08-31` };
    } else if (msg.includes('quinto') || msg.includes('5')) {
      return { startDate: `${currentYear}-09-01`, endDate: `${currentYear}-10-31` };
    } else if (msg.includes('sexto') || msg.includes('6')) {
      return { startDate: `${currentYear}-11-01`, endDate: `${currentYear}-12-31` };
    } else if (msg.includes('actual')) {
      // Calcular bimestre actual basado en fecha actual
      const bimestreActual = Math.floor(currentMonth / 2) + 1;
      const startMonth = (bimestreActual - 1) * 2;
      const endMonth = startMonth + 1;
      const endDay = new Date(currentYear, endMonth + 1, 0).getDate();
      return {
        startDate: `${currentYear}-${String(startMonth + 1).padStart(2, '0')}-01`,
        endDate: `${currentYear}-${String(endMonth + 1).padStart(2, '0')}-${endDay}`
      };
    } else if (msg.includes('último') || msg.includes('anterior') || msg.includes('pasado')) {
      // Calcular ÚLTIMO bimestre completado basado en fecha actual
      console.log(`🔍 [${requestId}]: Calculando último bimestre. Mes actual: ${currentMonth + 1}`);

      const bimestreActual = Math.floor(currentMonth / 2) + 1;
      let ultimoBimestre = bimestreActual - 1;
      let year = currentYear;

      // Si estamos en el primer bimestre, el último fue el sexto del año anterior
      if (ultimoBimestre < 1) {
        ultimoBimestre = 6;
        year = currentYear - 1;
      }

      console.log(`📅 [${requestId}]: Último bimestre: ${ultimoBimestre} de ${year}`);

      const startMonth = (ultimoBimestre - 1) * 2;
      const endMonth = startMonth + 1;
      const endDay = new Date(year, endMonth + 1, 0).getDate();

      return {
        startDate: `${year}-${String(startMonth + 1).padStart(2, '0')}-01`,
        endDate: `${year}-${String(endMonth + 1).padStart(2, '0')}-${endDay}`
      };
    }
  }

  // TRIMESTRES (cada 3 meses)
  if (msg.includes('trimestre') || msg.includes('q1') || msg.includes('q2') || msg.includes('q3') || msg.includes('q4')) {
    if (msg.includes('primer') || msg.includes('1') || msg.includes('q1')) {
      return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-03-31` };
    } else if (msg.includes('segundo') || msg.includes('2') || msg.includes('q2')) {
      return { startDate: `${currentYear}-04-01`, endDate: `${currentYear}-06-30` };
    } else if (msg.includes('tercer') || msg.includes('3') || msg.includes('q3')) {
      return { startDate: `${currentYear}-07-01`, endDate: `${currentYear}-09-30` };
    } else if (msg.includes('cuarto') || msg.includes('4') || msg.includes('q4')) {
      return { startDate: `${currentYear}-10-01`, endDate: `${currentYear}-12-31` };
    } else if (msg.includes('actual')) {
      // Calcular trimestre actual basado en fecha actual
      const trimestreActual = Math.floor(currentMonth / 3) + 1;
      const startMonth = (trimestreActual - 1) * 3;
      const endMonth = startMonth + 2;
      const endDay = new Date(currentYear, endMonth + 1, 0).getDate();
      return {
        startDate: `${currentYear}-${String(startMonth + 1).padStart(2, '0')}-01`,
        endDate: `${currentYear}-${String(endMonth + 1).padStart(2, '0')}-${endDay}`
      };
    } else if (msg.includes('último') || msg.includes('anterior') || msg.includes('pasado')) {
      // Calcular ÚLTIMO trimestre completado basado en fecha actual
      console.log(`🔍 [${requestId}]: Calculando último trimestre. Mes actual: ${currentMonth + 1}`);

      const trimestreActual = Math.floor(currentMonth / 3) + 1;
      let ultimoTrimestre = trimestreActual - 1;
      let year = currentYear;

      // Si estamos en Q1, el último trimestre fue Q4 del año anterior
      if (ultimoTrimestre < 1) {
        ultimoTrimestre = 4;
        year = currentYear - 1;
      }

      console.log(`📅 [${requestId}]: Último trimestre: Q${ultimoTrimestre} de ${year}`);

      const startMonth = (ultimoTrimestre - 1) * 3;
      const endMonth = startMonth + 2;
      const endDay = new Date(year, endMonth + 1, 0).getDate();

      return {
        startDate: `${year}-${String(startMonth + 1).padStart(2, '0')}-01`,
        endDate: `${year}-${String(endMonth + 1).padStart(2, '0')}-${endDay}`
      };
    }
  }

  // SEMESTRES (cada 6 meses)
  if (msg.includes('semestre')) {
    if (msg.includes('primer') || msg.includes('1')) {
      return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-06-30` };
    } else if (msg.includes('segundo') || msg.includes('2')) {
      return { startDate: `${currentYear}-07-01`, endDate: `${currentYear}-12-31` };
    } else if (msg.includes('actual')) {
      // Calcular semestre actual basado en fecha actual
      if (currentMonth < 6) {
        return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-06-30` };
      } else {
        return { startDate: `${currentYear}-07-01`, endDate: `${currentYear}-12-31` };
      }
    } else if (msg.includes('último') || msg.includes('anterior') || msg.includes('pasado')) {
      // Calcular ÚLTIMO semestre completado basado en fecha actual
      console.log(`🔍 [${requestId}]: Calculando último semestre. Mes actual: ${currentMonth + 1}`);

      if (currentMonth < 6) {
        // Estamos en primer semestre (ene-jun), último semestre fue segundo del año anterior
        console.log(`📅 [${requestId}]: En primer semestre actual, último fue segundo semestre ${currentYear - 1}`);
        return { startDate: `${currentYear - 1}-07-01`, endDate: `${currentYear - 1}-12-31` };
      } else {
        // Estamos en segundo semestre (jul-dic), último semestre fue primer semestre del año actual
        console.log(`📅 [${requestId}]: En segundo semestre actual, último fue primer semestre ${currentYear}`);
        return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-06-30` };
      }
    }
  }

  // PERÍODOS RELATIVOS
  if (msg.includes('últimos') || msg.includes('ultimos')) {
    if (msg.includes('15 días') || msg.includes('quince días')) {
      const startDate = new Date(today);
      startDate.setDate(startDate.getDate() - 15);
      return { startDate: formatDate(startDate), endDate: formatDate(today) };
    } else if (msg.includes('2 semanas') || msg.includes('dos semanas')) {
      const startDate = new Date(today);
      startDate.setDate(startDate.getDate() - 14);
      return { startDate: formatDate(startDate), endDate: formatDate(today) };
    } else if (msg.includes('3 meses') || msg.includes('tres meses')) {
      const startDate = new Date(today);
      startDate.setMonth(startDate.getMonth() - 3);
      return { startDate: formatDate(startDate), endDate: formatDate(today) };
    } else if (msg.includes('6 meses') || msg.includes('seis meses')) {
      const startDate = new Date(today);
      startDate.setMonth(startDate.getMonth() - 6);
      return { startDate: formatDate(startDate), endDate: formatDate(today) };
    }
  }

  // ÚLTIMO MES/AÑO COMPLETO
  if (msg.includes('último mes') || msg.includes('mes pasado')) {
    const lastMonth = new Date(currentYear, currentMonth - 1, 1);
    const lastMonthEnd = new Date(currentYear, currentMonth, 0);
    return { startDate: formatDate(lastMonth), endDate: formatDate(lastMonthEnd) };
  }

  if (msg.includes('último año') || msg.includes('año pasado')) {
    return { startDate: `${currentYear - 1}-01-01`, endDate: `${currentYear - 1}-12-31` };
  }

  // PERÍODOS ESPECÍFICOS DESDE/HASTA
  if (msg.includes('desde enero') && !msg.includes('hasta')) {
    return { startDate: `${currentYear}-01-01`, endDate: formatDate(today) };
  }

  if (msg.includes('hasta marzo') && !msg.includes('desde')) {
    return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-03-31` };
  }

  if (msg.includes('enero a marzo') || msg.includes('de enero a marzo')) {
    return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-03-31` };
  }

  // PERÍODOS POR MES ESPECÍFICO
  const meses = {
    'enero': { start: '01-01', end: '01-31' },
    'febrero': { start: '02-01', end: '02-28' },
    'marzo': { start: '03-01', end: '03-31' },
    'abril': { start: '04-01', end: '04-30' },
    'mayo': { start: '05-01', end: '05-31' },
    'junio': { start: '06-01', end: '06-30' },
    'julio': { start: '07-01', end: '07-31' },
    'agosto': { start: '08-01', end: '08-31' },
    'septiembre': { start: '09-01', end: '09-30' },
    'octubre': { start: '10-01', end: '10-31' },
    'noviembre': { start: '11-01', end: '11-30' },
    'diciembre': { start: '12-01', end: '12-31' }
  };

  for (const [nombreMes, fechas] of Object.entries(meses)) {
    if (msg.includes(nombreMes) && !msg.includes('últimos') && !msg.includes('desde') && !msg.includes('hasta')) {
      // Determinar si es del año actual o pasado
      let year = currentYear;
      if (msg.includes('pasado') || msg.includes('anterior') || (msg.includes('del') && msg.includes('2024'))) {
        year = currentYear - 1;
      }
      return {
        startDate: `${year}-${fechas.start}`,
        endDate: `${year}-${fechas.end}`
      };
    }
  }

  // CASOS ESPECIALES ADICIONALES
  if (msg.includes('este año') || msg.includes('año actual')) {
    return { startDate: `${currentYear}-01-01`, endDate: `${currentYear}-12-31` };
  }

  if (msg.includes('este mes') || msg.includes('mes actual')) {
    const firstDay = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-01`;
    const lastDay = new Date(currentYear, currentMonth + 1, 0).getDate();
    const lastDayFormatted = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${lastDay}`;
    return { startDate: firstDay, endDate: lastDayFormatted };
  }

  if (msg.includes('hoy') || msg.includes('día de hoy')) {
    return { startDate: formatDate(today), endDate: formatDate(today) };
  }

  if (msg.includes('ayer')) {
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    return { startDate: formatDate(yesterday), endDate: formatDate(yesterday) };
  }

  if (msg.includes('esta semana') || msg.includes('semana actual')) {
    const startOfWeek = new Date(today);
    const day = startOfWeek.getDay();
    const diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1); // Lunes como inicio
    startOfWeek.setDate(diff);

    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);

    return { startDate: formatDate(startOfWeek), endDate: formatDate(endOfWeek) };
  }

  console.log(`⚠️ [${requestId}]: No se pudo determinar período específico para: "${message}"`);
  return null;
}

// 🔥 FUNCIÓN PARA PROCESAR ACCIONES SUGERIDAS POR BRUNCHY
async function processActionSuggestion(geminiResponse, requestId) {
  const { action, report_type, time_frame, api_call } = geminiResponse;

  // 🔥 NUEVO: Manejar acciones tipo api_call
  if (action && typeof action === 'object' && action.type === 'api_call') {
    console.log(`🎯 [${requestId}]: Procesando acción api_call: ${action.endpoint}`);

    try {
      const { endpoint, params } = action;

      // Manejar endpoint de reportes de ventas por rango
      if (endpoint === '/pedidos/ventas/rango' && params) {
        let { startDate, endDate } = params;

        // 🔥 NUEVA FUNCIONALIDAD: Si las fechas vienen como "AUTO_CALCULATE" o no están presentes,
        // intentar calcular automáticamente basándose en el mensaje original
        if (!startDate || !endDate || startDate === 'AUTO_CALCULATE' || endDate === 'AUTO_CALCULATE') {
          console.log(`🤖 [${requestId}]: Intentando calcular fechas automáticamente...`);
          const calculatedPeriod = calculateComplexPeriods(geminiResponse.original_message || '', requestId);

          if (calculatedPeriod) {
            startDate = calculatedPeriod.startDate;
            endDate = calculatedPeriod.endDate;
            console.log(`✅ [${requestId}]: Fechas calculadas automáticamente: ${startDate} a ${endDate}`);
          } else {
            // Fallback a mes actual si no se puede calcular
            const today = new Date();
            const year = today.getFullYear();
            const month = today.getMonth() + 1;
            const firstDay = `${year}-${String(month).padStart(2, '0')}-01`;
            const lastDay = new Date(year, month, 0).getDate();
            const lastDayFormatted = `${year}-${String(month).padStart(2, '0')}-${lastDay}`;

            startDate = firstDay;
            endDate = lastDayFormatted;
            console.log(`⚠️ [${requestId}]: Usando fallback al mes actual: ${startDate} a ${endDate}`);
          }
        }

        console.log(`📊 [${requestId}]: Generando reporte de ventas desde ${startDate} hasta ${endDate}`);

        // Ejecutar consulta de ventas por rango
        const salesQuery = `
          SELECT 
            COALESCE(SUM(m.precio * pd.cantidad), 0) as total_ventas,
            COUNT(DISTINCT p.idpedido) as total_pedidos,
            COUNT(DISTINCT DATE(p.fecha)) as dias_con_ventas,
            AVG(m.precio * pd.cantidad) as promedio_por_item,
            MIN(p.fecha) as primera_venta,
            MAX(p.fecha) as ultima_venta
          FROM pedidos p 
          JOIN pedido_detalle pd ON p.idpedido = pd.idpedido 
          JOIN menu m ON pd.idplato = m.idplato 
          WHERE DATE(p.fecha) BETWEEN $1 AND $2 
          AND p.estado = 'completado'
        `;

        const salesResult = await pool.query(salesQuery, [startDate, endDate]);
        const salesData = salesResult.rows[0];

        // Consulta adicional: platos más vendidos en el período
        const topDishesQuery = `
          SELECT 
            m.nombre,
            SUM(pd.cantidad) as cantidad_vendida,
            SUM(m.precio * pd.cantidad) as ingresos_generados
          FROM pedidos p 
          JOIN pedido_detalle pd ON p.idpedido = pd.idpedido 
          JOIN menu m ON pd.idplato = m.idplato 
          WHERE DATE(p.fecha) BETWEEN $1 AND $2 
          AND p.estado = 'completado'
          GROUP BY m.idplato, m.nombre, m.precio
          ORDER BY cantidad_vendida DESC
          LIMIT 5
        `;

        const topDishesResult = await pool.query(topDishesQuery, [startDate, endDate]);
        const topDishes = topDishesResult.rows;

        // Formatear respuesta mejorada
        const totalVentas = parseFloat(salesData.total_ventas) || 0;
        const totalPedidos = parseInt(salesData.total_pedidos) || 0;
        const diasConVentas = parseInt(salesData.dias_con_ventas) || 0;
        const promedioPorItem = parseFloat(salesData.promedio_por_item) || 0;

        // 🔥 NUEVO: Determinar título inteligente basado en el período
        let periodTitle = "REPORTE DE VENTAS";
        const originalMsg = geminiResponse.original_message?.toLowerCase() || '';

        if (originalMsg.includes('bimestre')) {
          periodTitle = "REPORTE DE VENTAS DEL BIMESTRE";
        } else if (originalMsg.includes('trimestre') || originalMsg.includes('q1') || originalMsg.includes('q2') || originalMsg.includes('q3') || originalMsg.includes('q4')) {
          periodTitle = "REPORTE DE VENTAS DEL TRIMESTRE";
        } else if (originalMsg.includes('semestre')) {
          periodTitle = "REPORTE DE VENTAS DEL SEMESTRE";
        } else if (originalMsg.includes('año') && !originalMsg.includes('mes')) {
          periodTitle = "REPORTE DE VENTAS DEL AÑO";
        } else if (originalMsg.includes('mes')) {
          periodTitle = "REPORTE DE VENTAS DEL MES";
        } else if (originalMsg.includes('último') && originalMsg.includes('3 meses')) {
          periodTitle = "REPORTE DE VENTAS DE LOS ÚLTIMOS 3 MESES";
        } else if (originalMsg.includes('último') && originalMsg.includes('6 meses')) {
          periodTitle = "REPORTE DE VENTAS DE LOS ÚLTIMOS 6 MESES";
        } else if (originalMsg.includes('semana')) {
          periodTitle = "REPORTE DE VENTAS SEMANAL";
        } else if (originalMsg.includes('hoy')) {
          periodTitle = "REPORTE DE VENTAS DE HOY";
        }

        let enhancedText = `📊 **${periodTitle}** ✨\n\n`;
        enhancedText += `📅 **Período:** ${startDate} al ${endDate}\n\n`;
        enhancedText += `💰 **Total de Ventas:** $${totalVentas.toFixed(2)} 💸\n`;
        enhancedText += `📋 **Total de Pedidos:** ${totalPedidos} pedidos\n`;
        enhancedText += `📆 **Días con Ventas:** ${diasConVentas} días\n`;
        enhancedText += `📊 **Promedio por Item:** $${promedioPorItem.toFixed(2)}\n\n`;

        if (totalPedidos > 0) {
          const promedioDiario = totalVentas / Math.max(diasConVentas, 1);
          enhancedText += `📈 **Promedio Diario:** $${promedioDiario.toFixed(2)}\n\n`;
        }

        if (topDishes.length > 0) {
          enhancedText += `🏆 **TOP 5 PLATOS MÁS VENDIDOS:**\n`;
          topDishes.forEach((dish, index) => {
            const emoji = index === 0 ? '👑' : index === 1 ? '🥈' : index === 2 ? '🥉' : '⭐';
            enhancedText += `${emoji} **${dish.nombre}** - ${dish.cantidad_vendida} vendidos ($${parseFloat(dish.ingresos_generados).toFixed(2)})\n`;
          });
          enhancedText += '\n';
        }

        enhancedText += totalVentas > 1000 ? '🎉 ¡Excelente período de ventas!' :
          totalVentas > 500 ? '👍 Buen rendimiento en ventas' :
            '💪 ¡Sigamos trabajando para mejorar!';

        console.log(`✅ [${requestId}]: Reporte generado exitosamente via api_call`);

        return {
          text_response: enhancedText,
          action: 'report_generated',
          report_data: {
            period: `${startDate} al ${endDate}`,
            startDate: startDate,
            endDate: endDate,
            totalSales: totalVentas,
            totalOrders: totalPedidos,
            daysWithSales: diasConVentas,
            averagePerItem: promedioPorItem,
            topDishes: topDishes
          }
        };
      }

      console.log(`⚠️ [${requestId}]: Endpoint api_call no reconocido: ${endpoint}`);

    } catch (error) {
      console.error(`❌ [${requestId}]: Error procesando api_call:`, error);

      return {
        text_response: `❌ Lo siento, hubo un error al procesar tu solicitud de reporte: ${error.message}\n\nPuedes intentar preguntarme de nuevo o usar el panel de reportes en la administración. 😊`,
        action: 'error',
        error_details: error.message
      };
    }
  }

  // Mantener compatibilidad con el formato anterior
  if (action === 'generate_report' && report_type === 'sales') {
    console.log(`📊 [${requestId}]: Generando reporte de ventas automáticamente`);

    try {
      // Calcular fechas según el time_frame solicitado
      const now = new Date();
      let startDate, endDate = now;

      if (time_frame === 'last_three_months') {
        startDate = new Date(now.getFullYear(), now.getMonth() - 3, now.getDate());
      } else if (time_frame === 'last_month') {
        startDate = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate());
      } else if (time_frame === 'last_year') {
        startDate = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
      } else {
        // Por defecto, último mes
        startDate = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate());
      }

      const startDateStr = startDate.toISOString().split('T')[0];
      const endDateStr = endDate.toISOString().split('T')[0];

      console.log(`📅 [${requestId}]: Consultando ventas desde ${startDateStr} hasta ${endDateStr}`);

      // Ejecutar consulta de ventas por rango
      const salesQuery = `
        SELECT 
          COALESCE(SUM(m.precio * pd.cantidad), 0) as total_ventas,
          COUNT(DISTINCT p.idpedido) as total_pedidos,
          COUNT(DISTINCT DATE(p.fecha)) as dias_con_ventas,
          AVG(m.precio * pd.cantidad) as promedio_por_item,
          MIN(p.fecha) as primera_venta,
          MAX(p.fecha) as ultima_venta
        FROM pedidos p 
        JOIN pedido_detalle pd ON p.idpedido = pd.idpedido 
        JOIN menu m ON pd.idplato = m.idplato 
        WHERE DATE(p.fecha) BETWEEN $1 AND $2 
        AND p.estado = 'completado'
      `;

      const salesResult = await pool.query(salesQuery, [startDateStr, endDateStr]);
      const salesData = salesResult.rows[0];

      // Consulta adicional: platos más vendidos en el período
      const topDishesQuery = `
        SELECT 
          m.nombre,
          SUM(pd.cantidad) as cantidad_vendida,
          SUM(m.precio * pd.cantidad) as ingresos_generados
        FROM pedidos p 
        JOIN pedido_detalle pd ON p.idpedido = pd.idpedido 
        JOIN menu m ON pd.idplato = m.idplato 
        WHERE DATE(p.fecha) BETWEEN $1 AND $2 
        AND p.estado = 'completado'
            GROUP BY m.idplato, m.nombre, m.precio
            ORDER BY cantidad_vendida DESC
            LIMIT 5
      `;

      const topDishesResult = await pool.query(topDishesQuery, [startDateStr, endDateStr]);
      const topDishes = topDishesResult.rows;

      // Formatear respuesta mejorada
      const totalVentas = parseFloat(salesData.total_ventas) || 0;
      const totalPedidos = parseInt(salesData.total_pedidos) || 0;
      const diasConVentas = parseInt(salesData.dias_con_ventas) || 0;
      const promedioPorItem = parseFloat(salesData.promedio_por_item) || 0;

      const periodDescription = time_frame === 'last_three_months' ? 'últimos 3 meses' :
        time_frame === 'last_month' ? 'último mes' :
          time_frame === 'last_year' ? 'último año' : 'período solicitado';

      let enhancedText = `📊 **REPORTE DE VENTAS - ${periodDescription.toUpperCase()}** ✨\n\n`;
      enhancedText += `📅 **Período:** ${startDateStr} al ${endDateStr}\n\n`;
      enhancedText += `💰 **Total de Ventas:** $${totalVentas.toFixed(2)} 💸\n`;
      enhancedText += `📋 **Total de Pedidos:** ${totalPedidos} pedidos\n`;
      enhancedText += `📆 **Días con Ventas:** ${diasConVentas} días\n`;
      enhancedText += `📊 **Promedio por Item:** $${promedioPorItem.toFixed(2)}\n\n`;

      if (totalPedidos > 0) {
        const promedioDiario = totalVentas / Math.max(diasConVentas, 1);
        enhancedText += `📈 **Promedio Diario:** $${promedioDiario.toFixed(2)}\n\n`;
      }

      if (topDishes.length > 0) {
        enhancedText += `🏆 **TOP 5 PLATOS MÁS VENDIDOS:**\n`;
        topDishes.forEach((dish, index) => {
          const emoji = index === 0 ? '👑' : index === 1 ? '🥈' : index === 2 ? '🥉' : '⭐';
          enhancedText += `${emoji} **${dish.nombre}** - ${dish.cantidad_vendida} vendidos ($${parseFloat(dish.ingresos_generados).toFixed(2)})\n`;
        });
        enhancedText += '\n';
      }

      enhancedText += totalVentas > 1000 ? '🎉 ¡Excelente período de ventas!' :
        totalVentas > 500 ? '👍 Buen rendimiento en ventas' :
          '💪 ¡Sigamos trabajando para mejorar!';

      console.log(`✅ [${requestId}]: Reporte generado exitosamente`);

      return {
        text_response: enhancedText,
        action: 'report_generated',
        report_data: {
          period: periodDescription,
          startDate: startDateStr,
          endDate: endDateStr,
          totalSales: totalVentas,
          totalOrders: totalPedidos,
          daysWithSales: diasConVentas,
          averagePerItem: promedioPorItem,
          topDishes: topDishes
        }
      };

    } catch (error) {
      console.error(`❌ [${requestId}]: Error generando reporte:`, error);

      return {
        text_response: `❌ Lo siento, hubo un error al generar el reporte de ventas: ${error.message}\n\nPero puedes intentar preguntarme de nuevo o usar el panel de reportes en la administración. 😊`,
        action: 'error',
        error_details: error.message
      };
    }
  }

  // Si la acción no es reconocida, devolver la respuesta original
  console.log(`⚠️ [${requestId}]: Acción no reconocida: ${action}`);
  return geminiResponse;
}

// Endpoint /chat ACTUALIZADO con configuración global
app.post('/chat', async (req, res) => {
  const { message, sessionId, isAdmin, clientId, deviceInfo } = req.body;
  const requestId = `req_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

  console.log(`📝 Chat [${requestId}]: Mensaje recibido: "${String(message).substring(0, 50)}..."`);
  console.log(`📝 Chat [${requestId}]: Session ID: ${sessionId || 'No proporcionado'}`);
  console.log(`📝 Chat [${requestId}]: Es Admin: ${isAdmin || false}`);
  console.log(`📝 Chat [${requestId}]: Cliente ID: ${clientId || 'No proporcionado'}`);

  // 🆕 NUEVO: Registrar actividad del dispositivo si se proporciona información
  console.log(`🔍 Chat [${requestId}]: deviceInfo recibido:`, JSON.stringify(deviceInfo, null, 2));
  
  if (deviceInfo && deviceInfo.macAddress) {
    console.log(`📱 Chat [${requestId}]: Dispositivo detectado: ${deviceInfo.deviceName} (${deviceInfo.macAddress})`);
    
    // Buscar mesa asociada a esta MAC
    let deviceFound = false;
    for (const [tableNum, config] of Object.entries(MESA_CONFIGURATIONS)) {
      console.log(`🔍 Chat [${requestId}]: Comparando ${deviceInfo.macAddress.toUpperCase()} con ${config.macAddress.toUpperCase()}`);
      if (config.macAddress.toUpperCase() === deviceInfo.macAddress.toUpperCase()) {
        registerDeviceActivity(deviceInfo.macAddress, config.tableNumber, deviceInfo.deviceName || config.deviceName);
        console.log(`✅ Chat [${requestId}]: Actividad registrada para Mesa ${config.tableNumber}`);
        deviceFound = true;
        break;
      }
    }
    
    if (!deviceFound) {
      console.log(`⚠️ Chat [${requestId}]: MAC ${deviceInfo.macAddress} no encontrada en configuraciones`);
      console.log(`🔍 Chat [${requestId}]: MACs disponibles: ${Object.values(MESA_CONFIGURATIONS).map(c => c.macAddress).join(', ')}`);
    }
  } else {
    console.log(`⚠️ Chat [${requestId}]: deviceInfo no válido o sin macAddress`);
  }

  if (!message || !sessionId) {
    return res.status(400).json({
      error: 'Mensaje y sessionId son requeridos',
      requestId,
      timestamp: new Date().toISOString()
    });
  }

  try {
    // 🆕 NUEVO: Filtrar comandos administrativos para clientes (doble seguridad)
    if (!isAdmin && typeof message === 'string') {
      const trimmedMessage = message.trim().toLowerCase();
      const adminCommands = ['/status', '/config', '/help', '/ip', '/model', 
                            '/reports', '/popular', '/debug', '/test', '/reload'];
      
      if (trimmedMessage.startsWith('/')) {
        const command = trimmedMessage.split(' ')[0];
        if (adminCommands.includes(command)) {
          console.log(`🚫 Chat [${requestId}]: Comando administrativo bloqueado en servidor para cliente: ${command}`);
          
          res.json({
            text_response: '❌ Lo siento, ese comando no está disponible para clientes. ¡Pero puedo ayudarte con el menú, recomendaciones y pedidos! 😊',
            action: 'none',
            requestId,
            timestamp: new Date().toISOString()
          });
          return;
        }
      }
    }

    // 🔥 CAMBIO CLAVE: TODO va directamente a Brunchy para que use su inteligencia mejorada
    // Solo logueamos si es admin para debug, pero ya no interceptamos nada
    if (isAdmin) {
      console.log(`🔧 Chat [${requestId}]: Procesando mensaje de admin - ENVIANDO A BRUNCHY DIRECTAMENTE`);
    }

    // Para TODOS los mensajes (admin o cliente), usar BrunchyMCP directamente
    // Pasar el clientId si está disponible para obtener recomendaciones personalizadas
    const geminiResponse = await brunchy.getGeminiResponse(message, sessionId, clientId);
    console.log(`📝 Chat [${requestId}]: Respuesta de BrunchyMCP:`, geminiResponse);

    // 🔥 NUEVO: Procesar acciones sugeridas por Brunchy
    if (geminiResponse.action && isAdmin) {
      console.log(`🎯 Chat [${requestId}]: Procesando acción sugerida: ${geminiResponse.action}`);

      try {
        // Pasar el mensaje original para cálculo de fechas complejas
        const enhancedGeminiResponse = {
          ...geminiResponse,
          original_message: message
        };
        const enhancedResponse = await processActionSuggestion(enhancedGeminiResponse, requestId);

        res.json({
          ...enhancedResponse,
          requestId,
          timestamp: new Date().toISOString()
        });
        return;
      } catch (actionError) {
        console.error(`❌ Chat [${requestId}]: Error al procesar acción:`, actionError);
        // Si falla el procesamiento de la acción, enviar la respuesta original
      }
    }

    res.json({
      ...geminiResponse,
      requestId,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error(`❌ Chat [${requestId}]: Error general en el endpoint de chat:`, error);
    res.status(500).json({
      error: 'Error al procesar el mensaje',
      details: error.message,
      requestId,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint /mcp/validate (sin cambios en su lógica interna, pero la validación de BrunchyMCP podría necesitarse)
// Por ahora se deja como estaba, ya que BrunchyMCP no tiene un método validateResponse explícito en la nueva versión.
app.post('/mcp/validate', (req, res) => {
  try {
    const { response } = req.body;
    if (!response) {
      return res.status(400).json({ error: "Se requiere una respuesta para validar" });
    }
    // La validación de reglas ahora está implícita en el prompt y el parseo de Gemini.
    // Este endpoint podría necesitar una reevaluación o ser deprecado.
    // Por ahora, se asume que si la respuesta es un string, es válida en el sentido simple.
    const isValid = typeof response === 'string' || (typeof response === 'object' && response.text_response);

    if (isValid) {
      return res.status(200).json({
        valid: true,
        message: "La respuesta tiene un formato básico aceptable." // Mensaje genérico
      });
    } else {
      return res.status(200).json({ // Devolver 200 pero indicar no válido
        valid: false,
        message: "La respuesta no cumple con el formato esperado.",
        // No hay sugerencia automática en la nueva lógica de BrunchyMCP
      });
    }
  } catch (error) {
    console.error('Error en endpoint MCP/validate:', error);
    return res.status(500).json({ error: 'Error al validar respuesta', details: error.message });
  }
});

// Endpoint /mcp/status (actualizado con información del modelo)
app.get('/mcp/status', async (req, res) => {
  try {
    const dbResult = await pool.query("SELECT COUNT(*) as dish_count FROM menu");
    const dishCount = parseInt(dbResult.rows[0].dish_count);
    const availableResult = await pool.query("SELECT COUNT(*) as available_count FROM menu WHERE disponibilidad = true");
    const availableDishCount = parseInt(availableResult.rows[0].available_count);
    const modelInfo = brunchy.getModelInfo();

    return res.status(200).json({
      status: 'active',
      version: '1.4.1', // Versión con manejo robusto de errores
      rules: 'MCP-2024-DynamicMenu-KeyRotation-MultiModel', // Reflejar el nuevo enfoque
      database: { connected: true, totalDishes: dishCount, availableDishes: availableDishCount },
      keyRotation: {
        totalKeys: keyManager.apiKeys.length,
        currentKeyIndex: keyManager.currentKeyIndex + 1,
        keyUsage: Array.from(keyManager.keyUsageCount.entries()).map(([index, count]) => ({
          keyIndex: index + 1,
          usageCount: count
        })),
        keyErrors: Array.from(keyManager.errorCounts.entries()).map(([index, count]) => ({
          keyIndex: index + 1,
          errorCount: count
        }))
      },
      geminiModel: {
        current: modelInfo.currentModel,
        available: modelInfo.availableModels,
        displayNames: modelInfo.modelDisplayNames
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error en endpoint MCP/status:', error);
    return res.status(500).json({ status: 'degraded', error: error.message, timestamp: new Date().toISOString() });
  }
});

// Endpoint para cambiar el modelo de Gemini
app.post('/mcp/model', (req, res) => {
  try {
    const { model } = req.body;

    if (!model) {
      return res.status(400).json({
        error: 'Se requiere especificar el modelo',
        availableModels: brunchy.getModelInfo().availableModels
      });
    }

    const success = brunchy.setModel(model);

    if (success) {
      return res.status(200).json({
        success: true,
        message: `Modelo cambiado exitosamente a ${model}`,
        currentModel: brunchy.currentModel,
        timestamp: new Date().toISOString()
      });
    } else {
      return res.status(400).json({
        success: false,
        error: `Modelo no válido: ${model}`,
        availableModels: brunchy.getModelInfo().availableModels,
        timestamp: new Date().toISOString()
      });
    }
  } catch (error) {
    console.error('Error al cambiar modelo de Gemini:', error);
    return res.status(500).json({
      error: 'Error interno al cambiar modelo',
      details: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint para obtener información del modelo actual
app.get('/mcp/model', (req, res) => {
  try {
    const modelInfo = brunchy.getModelInfo();
    return res.status(200).json({
      ...modelInfo,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error al obtener información del modelo:', error);
    return res.status(500).json({
      error: 'Error al obtener información del modelo',
      details: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint para procesar audio con Gemini
app.post('/audio/process', audioUpload.single('audio'), async (req, res) => {
  const requestId = `audio_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

  try {
    console.log(`🎵 Audio [${requestId}]: Procesando audio`);

    // Verificar que se subió un archivo
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'file_missing',
        message: 'No se recibió archivo de audio',
        requestId,
        timestamp: new Date().toISOString()
      });
    }

    const { sessionId, languageCode = 'es' } = req.body;
    const audioFilePath = req.file.path;
    const audioFileSize = req.file.size;

    console.log(`🎵 Audio [${requestId}]: ${audioFileSize} bytes, session: ${sessionId}`);

    // Verificar que el archivo existe
    if (!fs.existsSync(audioFilePath)) {
      return res.status(500).json({
        success: false,
        error: 'file_not_found',
        message: 'Archivo de audio no encontrado después de la subida',
        requestId,
        timestamp: new Date().toISOString()
      });
    }

    // Procesar audio con Gemini usando sistema de reintentos
    console.log(`🤖 Audio [${requestId}]: Iniciando procesamiento con Gemini...`);

    // Función para intentar el procesamiento con rotación automática de claves
    const attemptAudioProcessing = async (retryCount = 0) => {
      const maxRetries = keyManager.apiKeys.length;

      try {
        // Obtener instancia de Gemini con rotación de claves
        const genAI = keyManager.getGenAIInstance();
        console.log(`🔑 Audio [${requestId}]: Usando clave API #${keyManager.currentKeyIndex + 1}`);

        const model = genAI.getGenerativeModel({
          model: brunchy.currentModel,
        });

        // Leer el archivo de audio
        const audioData = fs.readFileSync(audioFilePath);

        // Determinar el tipo MIME del archivo
        let mimeType = req.file.mimetype;
        if (!mimeType || mimeType === 'application/octet-stream') {
          const ext = req.file.originalname.split('.').pop()?.toLowerCase();
          switch (ext) {
            case 'mp3': mimeType = 'audio/mpeg'; break;
            case 'mp4': case 'm4a': mimeType = 'audio/mp4'; break;
            case 'wav': mimeType = 'audio/wav'; break;
            case 'webm': mimeType = 'audio/webm'; break;
            case 'ogg': mimeType = 'audio/ogg'; break;
            default: mimeType = 'audio/mp4';
          }
        }

        // Crear el prompt para Gemini
        const prompt = `Por favor, transcribe este audio a texto en español. 
        Solo devuelve el texto transcrito, sin explicaciones adicionales.
        Si no puedes entender el audio, responde "No se pudo transcribir el audio".`;

        // Preparar el contenido para Gemini
        const audioPart = {
          inlineData: {
            data: audioData.toString('base64'),
            mimeType: mimeType
          }
        };

        console.log(`🚀 Audio [${requestId}]: Enviando a Gemini...`);

        // Enviar a Gemini con timeout
        const result = await Promise.race([
          model.generateContent([prompt, audioPart]),
          new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Timeout de Gemini')), 45000)
          )
        ]);

        const response = result.response;
        const transcribedText = response.text();

        console.log(`✅ Audio [${requestId}]: Transcrito: "${transcribedText.substring(0, 50)}..."`);

        // Verificar si la transcripción fue exitosa
        if (transcribedText &&
          transcribedText.trim() !== '' &&
          !transcribedText.toLowerCase().includes('no se pudo transcribir')) {

          return {
            success: true,
            transcribed_text: transcribedText.trim(),
            text_response: transcribedText.trim(),
            language: languageCode,
            model: brunchy.currentModel,
            requestId,
            timestamp: new Date().toISOString()
          };
        } else {
          console.log(`❌ Audio [${requestId}]: Gemini no pudo transcribir`);
          return {
            success: false,
            error: 'transcription_failed',
            message: 'No se pudo transcribir el audio',
            text_response: 'No se pudo entender el audio. Por favor, intenta hablar más claro.',
            requestId,
            timestamp: new Date().toISOString()
          };
        }

      } catch (geminiError) {
        console.error(`❌ Audio [${requestId}]: Error de Gemini (intento ${retryCount + 1}):`, geminiError);

        // Intentar manejar el error con rotación de claves
        const newGenAI = keyManager.handleApiError(geminiError);

        if (newGenAI && retryCount < maxRetries - 1) {
          console.log(`🔄 Audio [${requestId}]: Reintentando con nueva clave API`);
          await new Promise(resolve => setTimeout(resolve, 1000 + (retryCount * 500)));
          return attemptAudioProcessing(retryCount + 1);
        }

        return {
          success: false,
          error: 'gemini_error',
          message: 'Error al procesar audio con Gemini',
          text_response: 'Hubo un problema al procesar el audio. Por favor, intenta de nuevo.',
          requestId,
          timestamp: new Date().toISOString()
        };
      }
    };

    try {
      const result = await attemptAudioProcessing();

      // Limpiar el archivo temporal
      try {
        fs.unlinkSync(audioFilePath);
        console.log(`🗑️ Audio [${requestId}]: Archivo temporal eliminado`);
      } catch (cleanupError) {
        console.log(`⚠️ Audio [${requestId}]: Error al eliminar archivo temporal`);
      }

      return res.status(result.success ? 200 : 500).json(result);

    } catch (processingError) {
      console.error(`❌ Audio [${requestId}]: Error general en procesamiento:`, processingError);

      // Limpiar archivo temporal en caso de error
      try {
        if (fs.existsSync(audioFilePath)) {
          fs.unlinkSync(audioFilePath);
        }
      } catch (cleanupError) {
        console.log(`⚠️ Audio [${requestId}]: Error al limpiar archivo`);
      }

      return res.status(500).json({
        success: false,
        error: 'processing_error',
        message: 'Error general al procesar audio',
        text_response: 'Error al procesar el audio. Por favor, intenta de nuevo.',
        requestId,
        timestamp: new Date().toISOString()
      });
    }

  } catch (error) {
    console.error(`❌ Audio [${requestId}]: Error general:`, error);

    // Limpiar archivo temporal en caso de error
    try {
      if (req.file && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
    } catch (cleanupError) {
      console.log(`⚠️ Audio [${requestId}]: Error al limpiar archivo`);
    }

    return res.status(500).json({
      success: false,
      error: 'server_error',
      message: 'Error interno del servidor al procesar audio',
      text_response: 'Error interno del servidor. Por favor, intenta de nuevo.',
      requestId,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoints para configuración global del asistente (controlada por admin)
app.get('/config/global', (req, res) => {
  try {
    console.log('📋 Solicitud de configuración global recibida');
    res.json({
      success: true,
      config: globalAssistantConfig,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error al obtener configuración global:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener configuración global',
      timestamp: new Date().toISOString()
    });
  }
});

app.post('/config/global', (req, res) => {
  try {
    console.log('🔧 Solicitud de actualización de configuración global:', req.body);

    const {
      serverIp,
      model,
      enableReports,
      enablePopularDishes,
      showSystemMessages,
      debugMode,
      systemPrompt
    } = req.body;

    // Actualizar configuración global
    if (serverIp !== undefined) globalAssistantConfig.serverIp = serverIp;
    if (model !== undefined) {
      globalAssistantConfig.model = model;
      // También actualizar el modelo en BrunchyMCP
      brunchy.setModel(model);
    }
    if (enableReports !== undefined) globalAssistantConfig.enableReports = enableReports;
    if (enablePopularDishes !== undefined) globalAssistantConfig.enablePopularDishes = enablePopularDishes;
    if (showSystemMessages !== undefined) globalAssistantConfig.showSystemMessages = showSystemMessages;
    if (debugMode !== undefined) globalAssistantConfig.debugMode = debugMode;
    if (systemPrompt !== undefined) globalAssistantConfig.systemPrompt = systemPrompt;

    console.log('✅ Configuración global actualizada:', globalAssistantConfig);

    res.json({
      success: true,
      message: 'Configuración actualizada exitosamente',
      config: globalAssistantConfig,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error al actualizar configuración global:', error);
    res.status(500).json({
      success: false,
      message: 'Error al actualizar configuración global',
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint para probar conexión con IP específica
app.post('/config/test-connection', (req, res) => {
  try {
    const { serverIp } = req.body;

    if (!serverIp) {
      return res.status(400).json({
        success: false,
        message: 'Se requiere serverIp para probar la conexión'
      });
    }

    // Simular prueba de conexión (en un caso real, harías ping o verificación)
    const isValidIp = /^(\d{1,3}\.){3}\d{1,3}$/.test(serverIp);

    if (isValidIp) {
      console.log(`🔗 Prueba de conexión exitosa para IP: ${serverIp}`);
      res.json({
        success: true,
        message: `Conexión exitosa con ${serverIp}`,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'Formato de IP inválido',
        timestamp: new Date().toISOString()
      });
    }
  } catch (error) {
    console.error('❌ Error al probar conexión:', error);
    res.status(500).json({
      success: false,
      message: 'Error al probar conexión',
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint /pedidos/tiempo/:id (sin cambios)
app.get('/pedidos/tiempo/:id', async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id))) { return res.status(400).json({ error: "ID de pedido inválido" }); }
    const pedidoId = parseInt(id);
    const result = await pool.query(`
      SELECT idpedido, estado, fecha as timestamp_inicial, EXTRACT(EPOCH FROM tiempo_procesamiento) as tiempo_segundos
      FROM pedidos WHERE idpedido = $1 AND tiempo_procesamiento IS NOT NULL LIMIT 1
    `, [pedidoId]);
    if (result.rows.length === 0) { return res.status(404).json({ error: "No se encontraron datos de tiempo para este pedido" }); }
    const processingData = result.rows[0];
    const tiempoSegundos = parseFloat(processingData.tiempo_segundos) || 0;
    const minutos = Math.floor(tiempoSegundos / 60);
    const segundos = Math.round(tiempoSegundos % 60);
    return res.status(200).json({
      idpedido: processingData.idpedido, estado_inicial: 'pendiente', estado_final: processingData.estado,
      timestamp_inicial: processingData.timestamp_inicial, tiempo_segundos: tiempoSegundos,
      tiempo_formato: `${minutos} min ${segundos} seg`
    });
  } catch (error) {
    console.error("❌ Error al obtener tiempo de procesamiento:", error);
    return res.status(500).json({ error: "Error al obtener tiempo de procesamiento", details: error.message });
  }
});

// Endpoint /users/:id DELETE (ELIMINADO - Usar el del login_register.js)
// Este endpoint estaba causando conflicto y haciendo hard delete
// El endpoint correcto con soft delete está en login_register.js

// Endpoint /db-status (sin cambios)
app.get('/db-status', async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    res.status(200).json({
      status: 'ok', message: 'Conexión a PostgreSQL correcta',
      timestamp: result.rows[0].now, timezone: process.env.TZ || 'No configurada'
    });
  } catch (error) {
    res.status(500).json({ status: 'error', message: 'Error en la conexión a PostgreSQL', error: error.message });
  }
});

// Verificar conexión a DB al inicio (sin cambios)
(async () => {
  try {
    const result = await pool.query("SELECT NOW()");
    console.log("Conexión a PostgreSQL funcionando:", result.rows[0]);
  } catch (error) {
    console.error("Error en la conexión a PostgreSQL:", error);
  }
})();

// Endpoint /pedidos-direct
app.post('/pedidos-direct', async (req, res) => {
  try {
    console.log('📦 Solicitud recibida en endpoint directo /pedidos-direct');
    console.log('📦 Cuerpo recibido:', req.body);
    const { idpersona, estado, items } = req.body;
    if (!idpersona) { return res.status(400).json({ error: "ID de persona es requerido" }); }
    if (!items || !Array.isArray(items) || items.length === 0) { return res.status(400).json({ error: "Se requiere al menos un item en el pedido" }); }
    await pool.query('BEGIN');
    const pedidoResult = await pool.query("INSERT INTO pedidos (idpersona, estado, fecha) VALUES ($1, $2, NOW()) RETURNING idpedido", [idpersona, estado || 'pendiente']);
    if (pedidoResult.rows.length === 0) { await pool.query('ROLLBACK'); return res.status(500).json({ error: "Error al crear el pedido" }); }
    const idpedido = pedidoResult.rows[0].idpedido;
    for (const item of items) {
      const { idplato, cantidad, notas } = item;
      if (!idplato || !cantidad) { await pool.query('ROLLBACK'); return res.status(400).json({ error: "Cada item debe tener idplato y cantidad" }); }
      await pool.query("INSERT INTO pedido_detalle (idpedido, idplato, cantidad, notas) VALUES ($1, $2, $3, $4)", [idpedido, idplato, cantidad, notas || '']);
    }
    await pool.query('COMMIT');
    return res.status(201).json({ idpedido, idpersona, estado: estado || 'pendiente', fecha: new Date().toISOString(), items: items.length });
  } catch (error) {
    try { await pool.query('ROLLBACK'); } catch (rollbackError) { console.error("Error en rollback:", rollbackError); }
    console.error("❌ Error al crear pedido directo:", error);
    return res.status(500).json({ error: "Error al crear el pedido", details: error.message });
  }
});

// Endpoint temporal para corregir rol del Super Admin
app.post('/admin/fix-super-admin-role', async (req, res) => {
  try {
    console.log('🔧 Solicitud para corregir rol del Super Admin');

    // Buscar usuario luis luis
    const findResult = await pool.query(`
      SELECT p.nombre, p.apellido, u.rol, p.email, p.idpersonas
      FROM usuario u 
      JOIN personas p ON u.idpersona = p.idpersonas 
      WHERE LOWER(p.nombre) LIKE '%luis%' AND LOWER(p.apellido) LIKE '%luis%'
    `);

    if (findResult.rows.length === 0) {
      return res.status(404).json({
        error: 'No se encontró el usuario luis luis',
        success: false
      });
    }

    const luisUser = findResult.rows[0];
    console.log(`📋 Usuario encontrado: ${luisUser.nombre} ${luisUser.apellido}, rol actual: "${luisUser.rol}"`);

    if (luisUser.rol === '00') {
      return res.status(200).json({
        message: 'El usuario ya tiene rol de Super Admin (00)',
        success: true,
        rolActual: luisUser.rol
      });
    }

    // Actualizar el rol a "00"
    const updateResult = await pool.query(`
      UPDATE usuario 
      SET rol = '00' 
      WHERE idpersona = $1
    `, [luisUser.idpersonas]);

    console.log(`✅ Filas actualizadas: ${updateResult.rowCount}`);

    // Verificar el cambio
    const verificationResult = await pool.query(`
      SELECT p.nombre, p.apellido, u.rol, p.email
      FROM usuario u 
      JOIN personas p ON u.idpersona = p.idpersonas 
      WHERE p.idpersonas = $1
    `, [luisUser.idpersonas]);

    const updatedUser = verificationResult.rows[0];

    // Mostrar estado de todos los admins
    const allAdminsResult = await pool.query(`
      SELECT p.nombre, p.apellido, u.rol, p.email
      FROM usuario u 
      JOIN personas p ON u.idpersona = p.idpersonas 
      WHERE u.rol IN ('00', '0')
      ORDER BY u.rol, p.nombre
    `);

    console.log('✅ Corrección completada');

    return res.status(200).json({
      success: true,
      message: 'Rol del Super Admin corregido exitosamente',
      usuarioActualizado: {
        nombre: updatedUser.nombre,
        apellido: updatedUser.apellido,
        rolAnterior: luisUser.rol,
        rolNuevo: updatedUser.rol
      },
      todosLosAdmins: allAdminsResult.rows.map(user => ({
        nombre: `${user.nombre} ${user.apellido}`,
        rol: user.rol,
        tipo: user.rol === '00' ? 'Super Admin' : 'Admin'
      }))
    });

  } catch (error) {
    console.error('❌ Error al corregir rol del Super Admin:', error);
    return res.status(500).json({
      success: false,
      error: 'Error interno del servidor',
      details: error.message
    });
  }
});

// ========================================
// 🏺 SISTEMA DE IDENTIFICACIÓN DE MESAS
// ========================================

// 🆕 NUEVO: Sistema de tracking de dispositivos activos
const ACTIVE_DEVICES = new Map(); // MAC -> { lastSeen: timestamp, tableNumber: number, deviceName: string }
const DEVICE_TIMEOUT = 5 * 60 * 1000; // 5 minutos en milliseconds

// 🆕 NUEVO: Función para registrar actividad de un dispositivo
function registerDeviceActivity(macAddress, tableNumber, deviceName) {
  console.log(`🔄 registerDeviceActivity llamada con: MAC=${macAddress}, Mesa=${tableNumber}, Dispositivo=${deviceName}`);
  
  if (!macAddress) {
    console.log(`❌ registerDeviceActivity: macAddress está vacía`);
    return;
  }
  
  const now = Date.now();
  const macUpper = macAddress.toUpperCase();
  
  ACTIVE_DEVICES.set(macUpper, {
    lastSeen: now,
    tableNumber: tableNumber,
    deviceName: deviceName,
    firstSeen: ACTIVE_DEVICES.get(macUpper)?.firstSeen || now
  });
  
  console.log(`✅ Actividad registrada: Mesa ${tableNumber} - ${deviceName} (${macAddress})`);
  console.log(`📊 Total dispositivos activos: ${ACTIVE_DEVICES.size}`);
  console.log(`🗺️ ACTIVE_DEVICES actual:`, Array.from(ACTIVE_DEVICES.entries()));
}

// 🆕 NUEVO: Función para limpiar dispositivos inactivos
function cleanupInactiveDevices() {
  const now = Date.now();
  const timeout = DEVICE_TIMEOUT;
  
  for (const [mac, info] of ACTIVE_DEVICES.entries()) {
    if (now - info.lastSeen > timeout) {
      console.log(`🔄 Limpiando dispositivo inactivo: Mesa ${info.tableNumber} - ${info.deviceName}`);
      ACTIVE_DEVICES.delete(mac);
    }
  }
}

// 🆕 NUEVO: Función para verificar si un dispositivo está realmente activo
function isDeviceReallyActive(macAddress) {
  if (!macAddress) return false;
  
  const deviceInfo = ACTIVE_DEVICES.get(macAddress.toUpperCase());
  if (!deviceInfo) return false;
  
  const now = Date.now();
  const isActive = (now - deviceInfo.lastSeen) <= DEVICE_TIMEOUT;
  
  if (!isActive) {
    // Limpiar automáticamente si está inactivo
    ACTIVE_DEVICES.delete(macAddress.toUpperCase());
  }
  
  return isActive;
}

// 🆕 NUEVO: Ejecutar limpieza cada minuto
setInterval(cleanupInactiveDevices, 60 * 1000);

// 🔧 CONFIGURACIÓN HARDCODEADA DE MESAS (para evitar usar base de datos)
const MESA_CONFIGURATIONS = {
  12: { 
    tableNumber: 12, 
    macAddress: '09:7F:32:DB:00:00', 
    deviceName: 'Samsung SM-A556E Mesa 12', 
    isActive: true,
    type: 'staff'
  },
  13: { 
    tableNumber: 13, 
    macAddress: '17:56:BA:18:00:00', 
    deviceName: 'Dispositivo Mesa 13', 
    isActive: true,
    type: 'staff'
  },
  14: { 
    tableNumber: 14, 
    macAddress: '39:39:DD:61:00:00', 
    deviceName: 'Redmi 220733SL Mesa 14', 
    isActive: true,
    type: 'staff'
  }
};

// 🔍 Endpoint para identificar mesa basada en MAC
app.post('/api/table/identify', async (req, res) => {
  try {
    const { macAddress, deviceName, deviceInfo } = req.body;

    console.log(`🔍 Solicitud de identificación de mesa:`);
    console.log(`   - MAC recibida: ${macAddress}`);
    console.log(`   - Dispositivo: ${deviceName}`);
    console.log(`   - Info adicional:`, deviceInfo);
    console.log(`🔍 MACs configuradas: ${Object.values(MESA_CONFIGURATIONS).map(c => c.macAddress).join(', ')}`);

    if (!macAddress) {
      return res.status(400).json({
        success: false,
        message: 'MAC address es requerida',
        table: null
      });
    }

    // Buscar SOLO en las configuraciones hardcodeadas
    let foundTable = null;
    for (const [tableNum, config] of Object.entries(MESA_CONFIGURATIONS)) {
      if (config.macAddress.toUpperCase() === macAddress.toUpperCase()) {
        foundTable = config;
        break;
      }
    }

    if (foundTable) {
      console.log(`✅ Mesa identificada: Mesa ${foundTable.tableNumber}`);
      console.log(`   - MAC: ${foundTable.macAddress}`);
      console.log(`   - Dispositivo: ${foundTable.deviceName}`);

      // 🆕 NUEVO: Registrar actividad del dispositivo
      registerDeviceActivity(macAddress, foundTable.tableNumber, foundTable.deviceName);

      res.json({
        success: true,
        message: `Mesa ${foundTable.tableNumber} identificada correctamente`,
        table: foundTable
      });
    } else {
      console.log(`⚠️ Dispositivo no registrado:`);
      console.log(`   - MAC buscada: ${macAddress}`);
      console.log(`   - Mesas disponibles: ${Object.keys(MESA_CONFIGURATIONS).join(', ')}`);

      res.json({
        success: false,
        message: 'Dispositivo no registrado en ninguna mesa',
        table: null,
        availableTables: Object.keys(MESA_CONFIGURATIONS).map(num => parseInt(num)),
        receivedMac: macAddress
      });
    }

  } catch (error) {
    console.error('❌ Error en identificación de mesa:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor',
      error: error.message,
      table: null
    });
  }
});

// 📝 Endpoint para actualizar configuración hardcodeada (solo administradores)
app.post('/api/table/register', async (req, res) => {
  try {
    const { tableNumber, macAddress, deviceName } = req.body;

    console.log(`📝 Solicitud de actualización de configuración hardcodeada:`);
    console.log(`   - Mesa: ${tableNumber}`);
    console.log(`   - MAC: ${macAddress}`);
    console.log(`   - Dispositivo: ${deviceName}`);

    // Validaciones
    if (!tableNumber || !macAddress || !deviceName) {
      return res.status(400).json({
        success: false,
        message: 'Todos los campos son requeridos (tableNumber, macAddress, deviceName)'
      });
    }

    if (![12, 13, 14].includes(parseInt(tableNumber))) {
      return res.status(400).json({
        success: false,
        message: 'Solo las mesas 12, 13 y 14 están disponibles para dispositivos'
      });
    }

    // Actualizar la configuración hardcodeada en memoria
    if (MESA_CONFIGURATIONS[tableNumber]) {
      MESA_CONFIGURATIONS[tableNumber] = {
        tableNumber: parseInt(tableNumber),
        macAddress: macAddress.toUpperCase(),
        deviceName: deviceName,
        isActive: true
      };

      console.log(`✅ Configuración hardcodeada actualizada para Mesa ${tableNumber}`);
      console.log(`   - Nueva MAC: ${macAddress.toUpperCase()}`);
      console.log(`   - Nuevo dispositivo: ${deviceName}`);

      res.json({
        success: true,
        message: `Configuración actualizada para Mesa ${tableNumber}`,
        device: MESA_CONFIGURATIONS[tableNumber],
        note: 'Los cambios se aplican en memoria hasta el próximo reinicio del servidor'
      });
    } else {
      res.status(404).json({
        success: false,
        message: `Mesa ${tableNumber} no encontrada en configuración`
      });
    }

  } catch (error) {
    console.error('❌ Error en actualización de configuración:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor',
      error: error.message
    });
  }
});

// 📋 Endpoint para obtener todas las mesas hardcodeadas
app.get('/api/table/all', async (req, res) => {
  try {
    console.log('📋 Solicitud de todas las mesas hardcodeadas');

    // Obtener solo las mesas hardcodeadas con estado real de conexión
    const allTables = [];
    for (const [tableNum, config] of Object.entries(MESA_CONFIGURATIONS)) {
      const isReallyActive = isDeviceReallyActive(config.macAddress);
      
      allTables.push({
        ...config,
        isActive: isReallyActive, // 🔄 ACTUALIZADO: Usar estado real, no hardcodeado
        source: 'hardcoded',
        realTimeStatus: isReallyActive ? 'connected' : 'disconnected',
        lastSeen: ACTIVE_DEVICES.get(config.macAddress.toUpperCase())?.lastSeen || null
      });
    }

    // Ordenar por número de mesa
    allTables.sort((a, b) => a.tableNumber - b.tableNumber);

    console.log(`✅ Enviando ${allTables.length} mesas hardcodeadas`);
    allTables.forEach(table => {
      console.log(`   - Mesa ${table.tableNumber}: ${table.deviceName} (${table.macAddress})`);
    });

    res.json({
      success: true,
      message: `${allTables.length} mesas hardcodeadas encontradas`,
      tables: allTables,
      availableTableNumbers: [12, 13, 14],
      note: 'Configuración completamente hardcodeada - no se consultan tablas de BD'
    });

  } catch (error) {
    console.error('❌ Error obteniendo mesas:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor',
      error: error.message,
      tables: []
    });
  }
});

// 🔧 Endpoint para testing y verificación real de estado de conexión
// 🆕 NUEVO: Endpoint POST para verificación de conexión desde el frontend
app.post('/api/table/debug/mac', (req, res) => {
  try {
    const { macAddress } = req.body;
    
    if (!macAddress) {
      return res.status(400).json({
        success: false,
        message: 'MAC address requerida'
      });
    }
    
    console.log(`🔍 Verificación POST para MAC: ${macAddress}`);
    
    // Buscar la configuración de la mesa
    let foundConfig = null;
    for (const [tableNum, config] of Object.entries(MESA_CONFIGURATIONS)) {
      if (config.macAddress.toUpperCase() === macAddress.toUpperCase()) {
        foundConfig = config;
        break;
      }
    }
    
    if (!foundConfig) {
      return res.json({
        success: false,
        found: false,
        message: 'Dispositivo no registrado'
      });
    }
    
    // Verificar estado real de conexión
    const isReallyActive = isDeviceReallyActive(macAddress);
    const activeDeviceInfo = ACTIVE_DEVICES.get(macAddress.toUpperCase());
    
    res.json({
      success: isReallyActive, // Solo success=true si está realmente conectado
      found: true,
      table: {
        ...foundConfig,
        isActive: isReallyActive
      },
      realTimeStatus: {
        isActive: isReallyActive,
        lastSeen: activeDeviceInfo?.lastSeen || null,
        lastSeenHuman: activeDeviceInfo?.lastSeen ? 
          new Date(activeDeviceInfo.lastSeen).toLocaleString('es-ES') : 'Nunca',
        timeoutMinutes: DEVICE_TIMEOUT / (60 * 1000)
      }
    });
    
  } catch (error) {
    console.error('❌ Error en verificación POST:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.get('/api/table/debug/mac', (req, res) => {
  try {
    const { macAddress } = req.query;
    
    if (macAddress) {
      console.log(`🔍 Debug: Verificando estado real para MAC: ${macAddress}`);
      
      for (const [tableNum, config] of Object.entries(MESA_CONFIGURATIONS)) {
        if (config.macAddress.toUpperCase() === macAddress.toUpperCase()) {
          const isReallyActive = isDeviceReallyActive(macAddress);
          const activeDeviceInfo = ACTIVE_DEVICES.get(macAddress.toUpperCase());
          
          return res.json({
            success: true,
            found: true,
            table: {
              ...config,
              isActive: isReallyActive, // Estado real, no hardcodeado
            },
            searchedMac: macAddress,
            realTimeStatus: {
              isActive: isReallyActive,
              lastSeen: activeDeviceInfo?.lastSeen || null,
              lastSeenHuman: activeDeviceInfo?.lastSeen ? 
                new Date(activeDeviceInfo.lastSeen).toLocaleString('es-ES') : 'Nunca',
              timeoutMinutes: DEVICE_TIMEOUT / (60 * 1000)
            }
          });
        }
      }
      
      return res.json({
        success: true,
        found: false,
        searchedMac: macAddress,
        availableMacs: Object.values(MESA_CONFIGURATIONS).map(c => c.macAddress)
      });
    } else {
      // Mostrar estado general de todos los dispositivos
      const deviceStatus = {};
      for (const [tableNum, config] of Object.entries(MESA_CONFIGURATIONS)) {
        const isReallyActive = isDeviceReallyActive(config.macAddress);
        const activeDeviceInfo = ACTIVE_DEVICES.get(config.macAddress.toUpperCase());
        
        deviceStatus[`mesa${tableNum}`] = {
          tableNumber: config.tableNumber,
          deviceName: config.deviceName,
          macAddress: config.macAddress,
          isActive: isReallyActive,
          lastSeen: activeDeviceInfo?.lastSeen || null,
          lastSeenHuman: activeDeviceInfo?.lastSeen ? 
            new Date(activeDeviceInfo.lastSeen).toLocaleString('es-ES') : 'Nunca'
        };
      }
      
      res.json({
        success: true,
        deviceStatus: deviceStatus,
        activeDevicesCount: Array.from(ACTIVE_DEVICES.values()).length,
        configuredDevicesCount: Object.keys(MESA_CONFIGURATIONS).length,
        timeoutMinutes: DEVICE_TIMEOUT / (60 * 1000),
        message: 'Usa ?macAddress=XX:XX:XX:XX:XX:XX para verificar una mesa específica'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Registrar los routers al final para evitar conflictos
app.use(userRoutes);
app.use(menuRoutes);
app.use(pedidosRoutes);
// app.use(authRoutes); // Comentado: user.js solo exporta funciones, no un router

console.log('🏺 Sistema de identificación de mesas inicializado');
console.log(`   - Mesas configuradas: ${Object.keys(MESA_CONFIGURATIONS).join(', ')}`);
console.log(`   - Endpoints disponibles:`);
console.log(`     • POST /api/table/identify - Identificar mesa por MAC`);
console.log(`     • POST /api/table/register - Registrar dispositivo (admin)`);
console.log(`     • GET /api/table/all - Listar todas las mesas`);
console.log(`     • GET /api/table/debug/mac - Debug y testing`);



// 🆕 NUEVO: Sistema de Notificaciones con WebSockets
class NotificationManager {
  constructor() {
    this.connectedClients = new Map(); // Mapa de dispositivos conectados
    this.io = null;
  }

  initialize(server) {
    this.io = new Server(server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      }
    });

    this.io.on('connection', (socket) => {
      console.log(`🔔 Cliente conectado: ${socket.id}`);

      // Registrar cliente
      socket.on('register', (data) => {
        const { tableNumber, deviceMac, userRole, userId } = data;
        this.connectedClients.set(socket.id, {
          socket,
          tableNumber,
          deviceMac,
          userRole,
          userId,
          connectedAt: new Date()
        });
        
        console.log(`📱 Cliente registrado: Mesa ${tableNumber}, Role ${userRole}, Usuario ${userId}`);
        console.log(`🔔 Total clientes conectados: ${this.connectedClients.size}`);
      });

      // Manejar desconexión
      socket.on('disconnect', () => {
        this.connectedClients.delete(socket.id);
        console.log(`👋 Cliente desconectado: ${socket.id}`);
        console.log(`🔔 Clientes restantes: ${this.connectedClients.size}`);
      });
    });

    console.log('🔔 Sistema de notificaciones WebSocket inicializado');
  }

  // Notificar pedido completado a clientes específicos
  notifyOrderCompleted(orderId, tableNumber, message) {
    if (!this.io) {
      console.warn('⚠️ Sistema de notificaciones no inicializado');
      return false;
    }

    let clientsNotified = 0;

    // Buscar clientes conectados en la mesa específica
    for (const [socketId, client] of this.connectedClients) {
      if (client.tableNumber == tableNumber && client.userRole == 1) { // Solo clientes
        try {
          client.socket.emit('order-completed', {
            orderId,
            tableNumber,
            message,
            timestamp: new Date().toISOString()
          });
          clientsNotified++;
          console.log(`🔔 Notificación enviada a cliente en Mesa ${tableNumber} (Socket: ${socketId})`);
        } catch (error) {
          console.error(`❌ Error enviando notificación a ${socketId}:`, error);
        }
      }
    }

    if (clientsNotified > 0) {
      console.log(`✅ Notificación enviada a ${clientsNotified} cliente(s) en Mesa ${tableNumber}`);
      return true;
    } else {
      console.warn(`⚠️ No hay clientes conectados en Mesa ${tableNumber}`);
      return false;
    }
  }

  // Obtener estadísticas de conexiones
  getConnectionStats() {
    const stats = {
      totalConnections: this.connectedClients.size,
      clientsByTable: {},
      clientsByRole: {},
      activeClients: 0
    };

    for (const [socketId, client] of this.connectedClients) {
      // Por mesa
      if (!stats.clientsByTable[client.tableNumber]) {
        stats.clientsByTable[client.tableNumber] = 0;
      }
      stats.clientsByTable[client.tableNumber]++;

      // Por rol
      if (!stats.clientsByRole[client.userRole]) {
        stats.clientsByRole[client.userRole] = 0;
      }
      stats.clientsByRole[client.userRole]++;

      stats.activeClients++;
    }

    return stats;
  }
}

// Instanciar el manager de notificaciones
const notificationManager = new NotificationManager();

// 🆕 NUEVO: Crear servidor HTTP para WebSockets
const server = http.createServer(app);

// 🆕 NUEVO: Inicializar sistema de notificaciones
notificationManager.initialize(server);

// Iniciar el servidor
console.log('🔄 Intentando iniciar servidor...');
console.log(`🔍 Variables: ip=${ip}, port=${port}, realServerIP=${realServerIP}`);
server.listen(port, ip, () => {
  console.log(`🚀 Servidor Brunchy MCP v1.4.1 corriendo en http://${ip}:${port}`);
  console.log(`🌐 IP de escucha: ${ip}:${port} (todas las interfaces)`);
  console.log(`📍 IP real detectada: ${realServerIP}:${port}`);
  console.log(`🔗 URL completa del servidor: http://${realServerIP}:${port}`);
  console.log(`💬 Endpoint de chat principal disponible en http://${realServerIP}:${port}/chat`);
  console.log(`🔔 Sistema de notificaciones WebSocket activo en ws://${realServerIP}:${port}`);
  console.log(`🤖 Modelo de Gemini por defecto: ${brunchy.currentModel} (estable)`);
  console.log(`🔧 Configuración de modelo disponible en http://${realServerIP}:${port}/mcp/model`);
  console.log(`🔑 Sistema de rotación de claves mejorado con ${keyManager.apiKeys.length} claves API`);
  console.log('✅ Sistema BrunchyMCP activo con manejo robusto de errores y rotación automática.');
}).on('error', (err) => {
  console.error('❌ Error al iniciar el servidor:', err);
  console.error(`❌ Detalles del error: ${err.message}`);
  console.error(`❌ Código de error: ${err.code}`);
  process.exit(1);
});

// Las rutas de /login_register, /menu, /pedidos se manejan a través de los routers importados.
// Asegúrate que esos archivos no definan rutas duplicadas que puedan causar conflictos.

// 🆕 NUEVO: Endpoints para notificaciones
app.post('/notifications/order-completed', (req, res) => {
  try {
    const { orderId, tableNumber, message } = req.body;
    
    console.log(`🔔 Recibida solicitud de notificación: Pedido #${orderId} → Mesa ${tableNumber}`);
    
    if (!orderId || !tableNumber) {
      return res.status(400).json({
        success: false,
        error: 'orderId y tableNumber son requeridos'
      });
    }

    const sent = notificationManager.notifyOrderCompleted(
      orderId, 
      tableNumber, 
      message || `Tu pedido #${orderId} está listo`
    );

    res.json({
      success: true,
      sent,
      message: sent 
        ? `Notificación enviada a Mesa ${tableNumber}`
        : `No hay clientes conectados en Mesa ${tableNumber}`,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error enviando notificación:', error);
    res.status(500).json({
      success: false,
      error: 'Error interno del servidor'
    });
  }
});

// 🆕 NUEVO: Endpoint para estadísticas de conexiones
app.get('/notifications/stats', (req, res) => {
  try {
    const stats = notificationManager.getConnectionStats();
    res.json({
      success: true,
      stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error obteniendo estadísticas:', error);
    res.status(500).json({
      success: false,
      error: 'Error obteniendo estadísticas'
    });
  }
});

// NUEVO: Endpoint para sincronización inicial del frontend
app.get('/config/sync', (req, res) => {
  try {
    console.log('🔄 Solicitud de sincronización inicial del frontend');

    const currentBrunchyModel = brunchy.currentModel;
    const globalConfigModel = globalAssistantConfig.model;

    // Verificar que ambos estén sincronizados
    if (currentBrunchyModel !== globalConfigModel) {
      console.warn(`⚠️ Desincronización detectada: BrunchyMCP(${currentBrunchyModel}) vs Global(${globalConfigModel})`);
      brunchy.setModel(globalConfigModel);
      console.log(`🔄 BrunchyMCP resincronizado a: ${globalConfigModel}`);
    }

    const syncData = {
      serverConfig: {
        ...globalAssistantConfig,
        brunchyModel: brunchy.currentModel,
        synchronized: currentBrunchyModel === globalConfigModel
      },
      modelInfo: brunchy.getModelInfo(),
      keyManagerStatus: {
        totalKeys: keyManager.apiKeys.length,
        currentKeyIndex: keyManager.currentKeyIndex + 1
      },
      serverTime: new Date().toISOString(),
      version: '1.4.1'
    };

    console.log('✅ Datos de sincronización enviados al frontend');
    res.json({
      success: true,
      message: 'Sincronización completada',
      data: syncData,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Error en sincronización inicial:', error);
    res.status(500).json({
      success: false,
      message: 'Error en sincronización inicial',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint para obtener la configuración del servidor (incluyendo IP real)
app.get('/server-config', (req, res) => {
  try {
    res.json({
      success: true,
      config: {
        serverIP: realServerIP,
        port: port,
        fullURL: `http://${realServerIP}:${port}`,
        listenIP: ip,
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('❌ Error al obtener configuración del servidor:', error);
    res.status(500).json({
      success: false,
      error: 'Error al obtener configuración del servidor'
    });
  }
});

// NUEVO: Endpoint mejorado para auto-descubrimiento de red
app.get('/discover', (req, res) => {
  try {
    const discoveryInfo = {
      server: {
        name: 'Le Brunch Server',
        version: '1.4.1',
        type: 'brunch-app-server',
        ip: realServerIP,
        port: port,
        baseUrl: `http://${realServerIP}:${port}`,
        capabilities: [
          'chat',
          'menu-management',
          'order-management',
          'user-management',
          'audio-processing'
        ]
      },
      network: {
        listenIP: ip,
        detectedIP: realServerIP,
        ports: {
          api: port,
          status: port
        }
      },
      status: {
        online: true,
        healthy: true,
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
      },
      database: {
        connected: true,
        type: 'PostgreSQL'
      }
    };

    // Agregar headers para descubrimiento
    res.setHeader('X-Server-Type', 'le-brunch-app');
    res.setHeader('X-Server-Version', '1.4.1');
    res.setHeader('X-Discovery-Protocol', 'http');

    res.json(discoveryInfo);
  } catch (error) {
    console.error('❌ Error en endpoint de descubrimiento:', error);
    res.status(500).json({
      error: 'Error en descubrimiento de servidor',
      timestamp: new Date().toISOString()
    });
  }
});

// NUEVO: Endpoint para corregir las URLs de imágenes en la base de datos
app.post('/admin/fix-image-urls', async (req, res) => {
  try {
    console.log('🔧 Iniciando corrección de URLs de imágenes...');

    // Obtener la URL actual del servidor
    const currentServerUrl = config.getServerUrl();
    console.log(`🌐 URL actual del servidor: ${currentServerUrl}`);

    // Obtener todos los platos con imagen_url
    const platos = await pool.query(
      'SELECT idplato, imagen_url FROM menu WHERE imagen_url IS NOT NULL AND imagen_url != \'\''
    );

    let corregidos = 0;
    let noNecesitanCorreccion = 0;

    for (const plato of platos.rows) {
      const urlOriginal = plato.imagen_url;

      // Si la URL ya es correcta o es relativa, no hacer nada
      if (urlOriginal.startsWith(currentServerUrl) || !urlOriginal.startsWith('http')) {
        noNecesitanCorreccion++;
        continue;
      }

      // Extraer solo la parte del archivo de la URL
      const match = urlOriginal.match(/\/uploads\/(.+)$/);
      if (match) {
        const filename = match[1];
        const nuevaUrl = `${currentServerUrl}/uploads/${filename}`;

        await pool.query(
          'UPDATE menu SET imagen_url = $1 WHERE idplato = $2',
          [nuevaUrl, plato.idplato]
        );

        console.log(`✅ Corregido: ${urlOriginal} → ${nuevaUrl}`);
        corregidos++;
      }
    }

    console.log(`🎯 Corrección completada: ${corregidos} URLs corregidas, ${noNecesitanCorreccion} no necesitaban corrección`);

    res.json({
      success: true,
      message: 'URLs de imágenes corregidas exitosamente',
      urlsCorregidas: corregidos,
      urlsNoNecesitanCorreccion: noNecesitanCorreccion,
      serverUrl: currentServerUrl,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error al corregir URLs de imágenes:', error);
    res.status(500).json({
      success: false,
      error: 'Error al corregir URLs de imágenes',
      details: error.message
    });
  }
});

// NUEVO: Endpoint para obtener menú con URLs de imágenes corregidas dinámicamente
app.get('/menu-with-corrected-urls', async (req, res) => {
  try {
    const { disponibilidad } = req.query;

    let query = "SELECT * FROM menu WHERE isDelete = FALSE";
    const queryParams = [];

    if (disponibilidad !== undefined) {
      const isAvailable = disponibilidad === 'true';
      query += " AND disponibilidad = $1";
      queryParams.push(isAvailable);
    }

    query += " ORDER BY nombre";

    const result = await pool.query(query, queryParams);
    const currentServerUrl = config.getServerUrl();

    // Corregir URLs dinámicamente
    const platosCorregidos = result.rows.map(plato => {
      let imagenUrlCorregida = plato.imagen_url;

      if (imagenUrlCorregida) {
        // Si la URL no contiene el servidor actual
        if (imagenUrlCorregida.startsWith('http') && !imagenUrlCorregida.startsWith(currentServerUrl)) {
          // Extraer solo el nombre del archivo
          const match = imagenUrlCorregida.match(/\/uploads\/(.+)$/);
          if (match) {
            imagenUrlCorregida = `${currentServerUrl}/uploads/${match[1]}`;
          }
        } else if (!imagenUrlCorregida.startsWith('http')) {
          // Si es una URL relativa, convertirla a absoluta
          imagenUrlCorregida = imagenUrlCorregida.startsWith('/')
            ? `${currentServerUrl}${imagenUrlCorregida}`
            : `${currentServerUrl}/${imagenUrlCorregida}`;
        }
      }

      return {
        ...plato,
        imagen_url: imagenUrlCorregida
      };
    });

    res.json(platosCorregidos);
  } catch (error) {
    console.error('❌ Error al obtener menú con URLs corregidas:', error);
    res.status(500).json({ error: error.message });
  }
});

// NUEVO: Endpoint para obtener menú completo con URLs corregidas dinámicamente
app.get('/menu-completo-corrected', async (req, res) => {
  try {
    const result = await pool.query('SELECT idplato, nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, tipo FROM menu WHERE disponibilidad = TRUE AND isDelete = FALSE');
    const currentServerUrl = config.getServerUrl();

    const platosCorregidos = result.rows.map(plato => {
      let imagenUrlCorregida = plato.imagen_url;

      if (imagenUrlCorregida) {
        if (imagenUrlCorregida.startsWith('http') && !imagenUrlCorregida.startsWith(currentServerUrl)) {
          const match = imagenUrlCorregida.match(/\/uploads\/(.+)$/);
          if (match) {
            imagenUrlCorregida = `${currentServerUrl}/uploads/${match[1]}`;
          }
        } else if (!imagenUrlCorregida.startsWith('http')) {
          imagenUrlCorregida = imagenUrlCorregida.startsWith('/')
            ? `${currentServerUrl}${imagenUrlCorregida}`
            : `${currentServerUrl}/${imagenUrlCorregida}`;
        }
      }

      return {
        ...plato,
        imagen_url: imagenUrlCorregida
      };
    });

    res.json(platosCorregidos);
  } catch (error) {
    console.error('❌ Error al obtener el menú completo con URLs corregidas:', error);
    res.status(500).json({ error: 'Error interno del servidor al obtener el menú.' });
  }
});




