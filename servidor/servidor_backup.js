require('dotenv').config();
const express = require('express');
const cors = require('cors');
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
    // 🔥 NUEVO: Verificar configuraciones antes de procesar
    const lowerMessage = message.toLowerCase();
    
    // Verificar si solicita reportes pero están desactivados
    if (!globalAssistantConfig.enableReports && 
        (lowerMessage.includes('reporte') || 
         lowerMessage.includes('ventas') || 
         lowerMessage.includes('estadística') ||
         lowerMessage.includes('estadisticas'))) {
      console.log('📊 Solicitud de reportes detectada pero función desactivada');
      return {
        text_response: "¡Hola! 😊 Me encantaría ayudarte con reportes y estadísticas, pero esta función está temporalmente desactivada. 📊❌\n\nPor favor contacta al administrador para activar los reportes. ¡Mientras tanto, puedo ayudarte con nuestro delicioso menú! 🍳✨",
        action: 'reports_disabled'
      };
    }
    
    // Verificar si solicita platos populares pero están desactivados
    if (!globalAssistantConfig.enablePopularDishes && 
        (lowerMessage.includes('popular') || 
         lowerMessage.includes('más vendido') ||
         lowerMessage.includes('favorito') ||
         lowerMessage.includes('recomendación') ||
         lowerMessage.includes('recomendaciones'))) {
      console.log('🏆 Solicitud de platos populares detectada pero función desactivada');
      return {
        text_response: "¡Hola! 😊 Me gustaría recomendarte nuestros platos más populares, pero esta función está temporalmente desactivada. 🏆❌\n\n¡Pero puedo ayudarte a explorar todo nuestro delicioso menú! ¿Qué tipo de comida te provoca hoy? 🍳✨",
        action: 'popular_dishes_disabled'
      };
    }

    // Obtener o inicializar el historial del chat
    if (!this.chatHistories[sessionId]) {
      this.chatHistories[sessionId] = [];
    }

    let recommendationsContext = '';

    // Solo agregar contexto de recomendaciones si están habilitadas y el cliente está identificado
    if (globalAssistantConfig.enablePopularDishes && clientId && 
        (lowerMessage.includes('recomend') || 
         lowerMessage.includes('suggest') || 
         lowerMessage.includes('popular'))) {
      console.log(`🔍 Generando recomendaciones personalizadas para cliente ${clientId}`);

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
      }

      // Construir el prompt completo
      const currentPrompt = this.systemPrompt + 
        (this.menu.length > 0 ? `\n\nMENÚ ACTUAL:\n${JSON.stringify(this.menu, null, 2)}` : '') +
        recommendationsContext;

      // Limitar el historial para no exceder el límite de tokens, manteniendo los últimos N intercambios.
      // Ejemplo: mantener los últimos 10 mensajes (5 intercambios usuario/modelo)
      const maxHistoryLength = 10;
      let currentSessionHistory = this.chatHistories[sessionId];
      if (currentSessionHistory.length > maxHistoryLength) {
        currentSessionHistory = currentSessionHistory.slice(-maxHistoryLength);
      }

      // Si tenemos el ID del cliente, obtener recomendaciones personalizadas
      let clientRecommendationsContext = '';
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

            clientRecommendationsContext = `\n\n🤖 SISTEMA INTELIGENTE DE RECOMENDACIONES DE BRUNCHY:

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
        } catch (error) {
          console.error(`❌ [BrunchyMCP] Error obteniendo recomendaciones para cliente ${clientId}:`, error);
          // Continuar sin recomendaciones si hay error
        }
      }

      // Agregar el contexto de recomendaciones al system prompt si está disponible
      const enhancedSystemPrompt = currentPrompt + recommendationsContext + clientRecommendationsContext;

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
