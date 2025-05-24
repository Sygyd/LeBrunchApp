require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const bodyParser = require("body-parser");
const menuRoutes = require("./menu");
const pedidosRoutes = require("./pedidos");

// Configuración de zona horaria Venezuela (GMT-4)
process.env.TZ = 'America/Caracas';
console.log(`🕒 Zona horaria configurada: ${process.env.TZ} - Hora actual: ${new Date().toLocaleString()}`);

// Configuración del servidor
const ip = '192.168.1.121';
const port = 3000;
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

    if (isQuotaError || isInvalidKeyError) {
      console.log(`🔄 Error de API detectado, rotando claves...`);
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
app.use(bodyParser.json());
app.use(userRoutes);
app.use(menuRoutes);
app.use(pedidosRoutes);

// Nueva clase BrunchyMCP
class BrunchyMCP {
  constructor() {
    this.baseSystemPrompt = `
    Eres 'Brunchy', un mesero virtual especializado ÚNICAMENTE en el restaurante Le Brunch.
    
    🚫 RESTRICCIONES ABSOLUTAS - NUNCA RESPONDAS A:
    - Preguntas sobre política, geografía, historia mundial, celebridades
    - Información general sobre otros países, capitales, presidentes
    - Noticias, deportes, clima, finanzas, criptomonedas, bolsa de valores
    - Matemáticas, ciencias, tecnología no relacionada con el restaurante
    - Consejos médicos, legales, o de cualquier otro tipo profesional
    - Cualquier tema que NO sea específicamente sobre Le Brunch, su menú o servicios
    
    ✅ SOLO PUEDES RESPONDER SOBRE:
    - El menú de Le Brunch (comidas y bebidas disponibles)
    - Tomar pedidos y añadir items al carrito
    - Horarios, ubicación e información específica del restaurante
    - Precios, ingredientes, y preparación de nuestros platos
    - Historia y concepto del brunch en relación al restaurante
    
    🎯 TU ÚNICO OBJETIVO: Ser un mesero virtual especializado que ayuda a los clientes a ordenar del menú.
    
    REGLAS DE COMPORTAMIENTO:
    1. NUNCA digas que eres un modelo de lenguaje, una IA, un bot. Siempre eres 'Brunchy'.
    2. Si te preguntan algo fuera del restaurante/menú, responde: "Lo siento, soy Brunchy, el mesero virtual de Le Brunch. Solo puedo ayudarte con nuestro menú y pedidos. ¿Qué te gustaría ordenar hoy?"
    3. Mantén un tono amigable pero SIEMPRE redirige a temas del restaurante.
    4. Si el cliente pide algo que NO está en el menú, debes decirlo amablemente.
    5. Para las solicitudes de añadir al carrito, SIEMPRE incluye la respuesta conversacional Y el JSON.
    6. Cuando incluyas el JSON, asegúrate de que los nombres coincidan exactamente con el menú.
    7. Las cantidades por defecto son 1 si no se especifican.

    FORMATO DE RESPUESTA CON JSON PARA AÑADIR AL CARRITO (cuando sea aplicable):
    \`\`\`json
    {
      "text_response": "¡Claro! Añadiendo [nombre del plato/bebida] a tu carrito. ¿Algo más en lo que pueda ayudarte?",
      "action": "add_to_cart",
      "items": [
        {"name": "nombre del plato/bebida 1", "quantity": numero, "notes": "cualquier modificación o nota"},
        {"name": "nombre del plato/bebida 2", "quantity": numero, "notes": "cualquier modificación o nota"}
      ]
    }
    \`\`\`
    Si no hay ítems del menú, el JSON no debe incluir la clave "items" ni "action". La clave "text_response" siempre debe estar presente.

    Ejemplos de interacción:
    - Cliente: "Quiero 2 panquecas y un capuccino."
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Excelente elección! Añadiendo 2 panquecas y un capuccino a tu carrito. ¿Deseas algo más?",
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
        "text_response": "¡Perfecto! Una Tabla Tradicional sin tomate y un Jugo de Naranja se están añadiendo a tu pedido. ¿Necesitas algo más?",
        "action": "add_to_cart",
        "items": [
          {"name": "Tabla Tradicional", "quantity": 1, "notes": "sin tomate"},
          {"name": "Jugo de Naranja", "quantity": 1, "notes": ""}
        ]
      }
      \`\`\`

    - Cliente: "Hola, ¿cuáles son sus horarios?"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "¡Hola! Estamos abiertos de lunes a viernes de 8 AM a 5 PM, y los fines de semana de 9 AM a 6 PM. ¡Te esperamos!"
      }
      \`\`\`

    EJEMPLOS DE PREGUNTAS QUE DEBES RECHAZAR:
    - Cliente: "¿Cuál es la capital de Venezuela?"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "Lo siento, soy Brunchy, el mesero virtual de Le Brunch. Solo puedo ayudarte con nuestro menú y pedidos. ¿Qué te gustaría ordenar hoy?"
      }
      \`\`\`

    - Cliente: "¿Quién es el presidente de Estados Unidos?"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "Lo siento, soy Brunchy, el mesero virtual de Le Brunch. Solo puedo ayudarte con nuestro menú y pedidos. ¿Qué te gustaría ordenar hoy?"
      }
      \`\`\`

    - Cliente: "¿Cuál es el precio del Bitcoin?"
    - Brunchy:
      \`\`\`json
      {
        "text_response": "Lo siento, soy Brunchy, el mesero virtual de Le Brunch. Solo puedo ayudarte con nuestro menú y pedidos. ¿Qué te gustaría ordenar hoy?"
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
      const result = await pool.query('SELECT nombre, categoria, precio, disponibilidad, tipo FROM menu WHERE disponibilidad = TRUE ORDER BY tipo, categoria, nombre');
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

    this.systemPrompt = this.baseSystemPrompt + menuString;
  }

  async getGeminiResponse(message, sessionId) {
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

    currentSessionHistory.push({ role: "user", parts: [{ text: message }] });

    if (this.menu.length === 0) {
        await this.loadMenu(); 
    }

    console.log(`[BrunchyMCP] Enviando a Gemini para sesión ${sessionId}:`, message);
    
    // Función para intentar la solicitud con rotación automática de claves
    const attemptRequest = async (retryCount = 0) => {
      const maxRetries = keyManager.apiKeys.length; // Intentar con todas las claves disponibles
      
      try {
        // Obtener instancia de Gemini con la clave actual
        const genAI = keyManager.getGenAIInstance();
        console.log(`🔑 [BrunchyMCP] Usando clave API #${keyManager.currentKeyIndex + 1}`);
        
        const model = genAI.getGenerativeModel({ 
            model: "gemini-1.5-flash",
            systemInstruction: { 
                role: "system", 
                parts: [{ text: this.systemPrompt }] 
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
                const jsonString = jsonMatch[1] || jsonMatch[2];
                parsedResponse = JSON.parse(jsonString);
                console.log('[BrunchyMCP] Respuesta parseada como JSON:', parsedResponse);
                return parsedResponse;
            } else {
                parsedResponse = { text_response: responseText };
                console.log('[BrunchyMCP] Respuesta tratada como texto plano:', parsedResponse);
                return parsedResponse;
            }
        } catch (jsonError) {
            console.error('❌ [BrunchyMCP] Error al parsear JSON de la respuesta de Gemini, tratando como texto plano:', jsonError);
            parsedResponse = { text_response: responseText };
            return parsedResponse;
        }

      } catch (error) {
        console.error(`❌ [BrunchyMCP] Error al obtener respuesta de Gemini (intento ${retryCount + 1}):`, error);
        
        // Intentar manejar el error con rotación de claves
        const newGenAI = keyManager.handleApiError(error);
        
        if (newGenAI && retryCount < maxRetries - 1) {
          console.log(`🔄 [BrunchyMCP] Reintentando con nueva clave API (intento ${retryCount + 2}/${maxRetries})`);
          return attemptRequest(retryCount + 1);
        }
        
        // Si llegamos aquí, ya agotamos todas las claves o el error no es manejable
        currentSessionHistory.push({ role: "model", parts: [{ text: "Error interno del modelo al procesar la solicitud." }] });
        this.chatHistories[sessionId] = currentSessionHistory;
        return { text_response: "Lo siento, tengo problemas para procesar tu solicitud en este momento. Por favor, intenta de nuevo más tarde."};
      }
    };

    return attemptRequest();
  }
}

// Instanciar BrunchyMCP y cargar el menú al iniciar el servidor
const brunchy = new BrunchyMCP();
brunchy.loadMenu().catch(err => console.error("Error inicial crítico al cargar menú para Brunchy:", err));

// Opcional: Recargar el menú periódicamente
// setInterval(() => {
//   console.log("Recargando menú periódicamente...");
//   brunchy.loadMenu();
// }, 3600000); // Cada hora


// Endpoint para obtener el menú completo (ya existe y es correcto)
app.get('/menu-completo', async (req, res) => {
  try {
    // Esta consulta ya incluye 'tipo'
    const result = await pool.query('SELECT idplato, nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, tipo FROM menu WHERE disponibilidad = TRUE');
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
    return res.status(200).json({count: parseInt(rows[0].count), timestamp: new Date().toISOString()});
  } catch (error) {
    console.error("❌ Error al obtener número de pedidos pendientes:", error);
    return res.status(500).json({ error: "Error al obtener número de pedidos pendientes", details: error.message });
  }
});

app.get('/pedidos/ventas/hoy', async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT COALESCE(SUM(pd.precio_unitario * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido WHERE DATE(p.fecha) = CURRENT_DATE AND p.estado = 'completado'");
    return res.status(200).json({total: parseFloat(rows[0].total), timestamp: new Date().toISOString()});
  } catch (error) {
    console.error("❌ Error al obtener ventas del día:", error);
    return res.status(500).json({ error: "Error al obtener ventas del día", details: error.message });
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
      `SELECT pd.idpedido, pd.idplato, pd.cantidad, pd.precio_unitario, 
              m.nombre as nombre
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

// Endpoint de métricas administrativas (sin cambios)
app.get('/admin/metrics', async (req, res) => {
  try {
    const [activeDishesResult, usersResult, pendingOrdersResult, todaySalesResult] = await Promise.all([
      pool.query("SELECT COUNT(*) as count FROM menu WHERE disponibilidad = true"),
      pool.query("SELECT COUNT(*) as count FROM usuario"),
      pool.query("SELECT COUNT(*) as count FROM pedidos WHERE estado = 'pendiente'"),
      pool.query("SELECT COALESCE(SUM(pd.precio_unitario * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido WHERE DATE(p.fecha) = CURRENT_DATE AND p.estado = 'completado'")
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

// Endpoint /chat ACTUALIZADO
app.post('/chat', async (req, res) => {
  const { message, sessionId } = req.body; // direct ya no es necesario con la nueva lógica
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    
  console.log(`📝 Chat [${requestId}]: Mensaje recibido: "${String(message).substring(0, 50)}..."`);
    console.log(`📝 Chat [${requestId}]: Session ID: ${sessionId || 'No proporcionado'}`);
    
  if (!message || !sessionId) {
      return res.status(400).json({ 
      error: 'Mensaje y sessionId son requeridos',
          requestId,
          timestamp: new Date().toISOString()
        });
      }
      
  try {
    const geminiResponse = await brunchy.getGeminiResponse(message, sessionId);
    // geminiResponse es un objeto { text_response: "...", action?: "...", items?: [...] }
    // o solo { text_response: "..." } si no hay acción de carrito.
    console.log(`📝 Chat [${requestId}]: Respuesta de BrunchyMCP:`, geminiResponse);
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

// Endpoint /mcp/status (sin cambios)
app.get('/mcp/status', async (req, res) => {
  try {
    const dbResult = await pool.query("SELECT COUNT(*) as dish_count FROM menu");
    const dishCount = parseInt(dbResult.rows[0].dish_count);
    const availableResult = await pool.query("SELECT COUNT(*) as available_count FROM menu WHERE disponibilidad = true");
    const availableDishCount = parseInt(availableResult.rows[0].available_count);
    return res.status(200).json({
      status: 'active',
      version: '1.3.0', // Actualizar versión para reflejar sistema de rotación
      rules: 'MCP-2024-DynamicMenu-KeyRotation', // Reflejar el nuevo enfoque
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
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error en endpoint MCP/status:', error);
    return res.status(500).json({ status: 'degraded', error: error.message, timestamp: new Date().toISOString() });
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

// Endpoint /users/:id DELETE (sin cambios)
app.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`🗑️ Solicitud para eliminar usuario con ID: ${id}`);
    await pool.query('BEGIN');
    const deleteUserResult = await pool.query('DELETE FROM usuario WHERE idpersona = $1 RETURNING idpersona', [id]);
    if (deleteUserResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "Usuario no encontrado" });
    }
    const deletePersonResult = await pool.query('DELETE FROM personas WHERE idpersonas = $1 RETURNING nombre, apellido', [id]);
    await pool.query('COMMIT');
    console.log(`✅ Usuario eliminado con éxito: ${deletePersonResult.rows[0]?.nombre} ${deletePersonResult.rows[0]?.apellido}`);
    return res.status(200).json({
      success: true, message: "Usuario eliminado con éxito",
      deletedUser: { id: id, nombre: deletePersonResult.rows[0]?.nombre, apellido: deletePersonResult.rows[0]?.apellido }
    });
  } catch (error) {
    await pool.query('ROLLBACK');
    console.error("❌ Error al eliminar usuario:", error);
    return res.status(500).json({ success: false, message: "Error al eliminar el usuario", error: error.message });
  }
});

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

// Endpoint /pedidos-direct (sin cambios)
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
      const { idplato, cantidad, precio_unitario } = item;
      if (!idplato || !cantidad || !precio_unitario) { await pool.query('ROLLBACK'); return res.status(400).json({ error: "Cada item debe tener idplato, cantidad y precio_unitario" }); }
      await pool.query("INSERT INTO pedido_detalle (idpedido, idplato, cantidad, precio_unitario) VALUES ($1, $2, $3, $4)", [idpedido, idplato, cantidad, precio_unitario]);
    }
    await pool.query('COMMIT');
    return res.status(201).json({ idpedido, idpersona, estado: estado || 'pendiente', fecha: new Date().toISOString(), items: items.length });
  } catch (error) {
    try { await pool.query('ROLLBACK'); } catch (rollbackError) { console.error("Error en rollback:", rollbackError); }
    console.error("❌ Error al crear pedido directo:", error);
    return res.status(500).json({ error: "Error al crear el pedido", details: error.message });
  }
});

// Iniciar el servidor
app.listen(port, ip, () => {
  console.log(`Servidor Brunchy MCP corriendo en http://${ip}:${port}`);
  // Ya no se referencia /mcp/chat como el principal si /chat es el actualizado
  console.log(`Endpoint de chat principal disponible en http://${ip}:${port}/chat`);
  console.log('Sistema BrunchyMCP activo con carga dinámica de menú y manejo de sesión.');
});

// Las rutas de /login_register, /menu, /pedidos se manejan a través de los routers importados.
// Asegúrate que esos archivos no definan rutas duplicadas que puedan causar conflictos.


