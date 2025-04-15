require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');  // Conexión a PostgreSQL desde db.js
const userRoutes = require("./login_register");
const bodyParser = require("body-parser");
const menuRoutes = require("./menu");
const pedidosRoutes = require("./pedidos");

// Configuración del servidor
const ip = '192.168.1.121';
const port = 3000;
// NO usar puerto 5678 bajo ninguna circunstancia

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));  // Aumentar límite para contextos grandes
app.use(bodyParser.json());
app.use(userRoutes);
app.use(menuRoutes);
app.use(pedidosRoutes);  // Usar el router de pedidos normalmente, ya que las rutas en pedidos.js ya incluyen el prefijo "/pedidos"

// MCP (Model Context Protocol) para Le Brunch
class BrunchyMCP {
  constructor() {
    this.systemPrompt = `
    Eres 'Brunchy', un mesero virtual amable y entusiasta del restaurante Le Brunch, especializado en desayunos y brunch.
    
    REGLAS ESTRICTAS 2024:
    1. NUNCA digas que eres un modelo de lenguaje, una IA, o un asistente virtual.
    2. NUNCA menciones que no puedes hacer algo porque eres un modelo de lenguaje o un programa.
    3. SIEMPRE responde como un mesero humano real con conocimiento experto sobre el menú.
    4. NUNCA inventes platos que no estén en el menú actual que te proporcionamos de la base de datos.
    5. NUNCA recomiendes platos que no aparezcan explícitamente en el menú que te proporcionamos.
    6. Si alguien pregunta sobre un plato que no está en el menú, dile amablemente que no está disponible pero ofrece alternativas del menú actual.
    7. NUNCA inventes tablas de compartir, tablas de quesos, o tablas combinadas a menos que aparezcan en el menú de la base de datos.
    8. SIEMPRE responde en español con un tono alegre y servicial.
    9. Para pedidos: SIEMPRE pregunta por instrucciones especiales antes de confirmar.
    10. Usa formatos de texto enriquecido: **negrita** para nombres de platos y listas para ingredientes.
    11. SIEMPRE basa tus respuestas ÚNICAMENTE en la información del menú proporcionada, sin inventar nada adicional.
    12. Responde con oraciones completas y coherentes, nunca con frases mezcladas o términos inconexos.
    
    INFORMACIÓN DE LE BRUNCH:
    - Historia: El término brunch surgió en el siglo XIX en Reino Unido (breakfast + lunch).
    - Horario: Abierto de 8am a 10pm todos los días.
    - Eslogan: "¡Horneamos, cocinamos... disfrutamos!"
    - Ubicación: Le Brunch, 682C+3X9 C.C. Punta Marina, Av Américo Vespucio, Lechería 6016, Anzoátegui.
    `;
  }

  /**
   * Obtiene todos los platos disponibles en el menú actual
   */
  async getMenu() {
    try {
      const result = await pool.query(`
        SELECT 
          idplato, 
          nombre, 
          precio, 
          ingredientes, 
          categoria,
          disponibilidad, 
          imagen_url
        FROM 
          menu
        ORDER BY 
          categoria, nombre
      `);
      
      return result.rows;
    } catch (error) {
      console.error('Error al obtener menú:', error);
      return [];
    }
  }

  /**
   * Genera un contexto estructurado del menú actual
   */
  generateMenuContext(menuItems) {
    // Información sobre Le Brunch
    const restaurantInfo = `
# SOBRE LE BRUNCH
Le Brunch es un restaurante especializado en desayunos y brunch, ubicado en 682C+3X9 C.C. Punta Marina, Av Américo Vespucio, Lechería 6016, Anzoátegui.
- Horario: Abierto de 8am a 10pm todos los días.
- Eslogan: "¡Horneamos, cocinamos... disfrutamos!"
- Historia: El término brunch surgió en el siglo XIX en Reino Unido como combinación de breakfast + lunch.
`;

    // Agrupar por categorías
    const categorized = {};
    menuItems.forEach(item => {
      if (!categorized[item.categoria]) {
        categorized[item.categoria] = [];
      }
      categorized[item.categoria].push(item);
    });

    // Generar texto estructurado por categorías
    let menuContext = restaurantInfo + "\n# MENÚ ACTUAL DE LE BRUNCH\n\n";
    
    Object.entries(categorized).forEach(([categoria, platos]) => {
      menuContext += `## ${categoria.toUpperCase()}\n`;
      
      platos.forEach(plato => {
        const status = plato.disponibilidad ? "✓ Disponible" : "✗ No disponible";
        menuContext += `- **${plato.nombre}**: $${plato.precio} (${status})\n`;
        
        // Formatear ingredientes como lista
        if (plato.ingredientes) {
          const ingredientesList = plato.ingredientes
            .split(',')
            .map(i => i.trim())
            .filter(i => i.length > 0);
            
          if (ingredientesList.length > 0) {
            menuContext += "  Ingredientes:\n";
            ingredientesList.forEach(ing => {
              menuContext += `    * ${ing}\n`;
            });
          }
        }
        
        menuContext += "\n";
      });
    });
    
    // Si no hay categorías/platos en el menú
    if (Object.keys(categorized).length === 0) {
      menuContext += "Actualmente no hay información disponible sobre el menú en la base de datos.\n";
    }
    
    return menuContext;
  }

  /**
   * Genera sugerencias basadas en el menú actual
   */
  generateSuggestions(menuItems) {
    // Filtrar solo platos disponibles
    const availableDishes = menuItems.filter(item => item.disponibilidad);
    
    // Si no hay platos disponibles, devolver array vacío
    if (availableDishes.length === 0) return [];
    
    // Seleccionar 3 platos aleatorios para recomendaciones
    const shuffled = [...availableDishes].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, 3).map(dish => dish.nombre);
  }

  /**
   * Procesa la consulta del usuario y enriquece con contexto
   */
  async processQuery(message, sessionId) {
    try {
      // Obtener menú actual
      const menuItems = await this.getMenu();
      
      // Verificar si el usuario menciona algún plato específico
      const userMessage = message.toLowerCase();
      const possiblePlatos = await this._extractPossiblePlatos(userMessage);
      
      let additionalContext = '';
      
      // Si se detectaron posibles platos, verificar si existen
      if (possiblePlatos.length > 0) {
        const existingPlatos = [];
        const nonExistingPlatos = [];
        
        // Verificar si cada posible plato existe en el menú actual
        for (const plato of possiblePlatos) {
          const exists = menuItems.some(
            item => item.nombre.toLowerCase().includes(plato.toLowerCase())
          );
          
          if (exists) {
            existingPlatos.push(plato);
          } else {
            nonExistingPlatos.push(plato);
          }
        }
        
        // Añadir información sobre platos mencionados que no existen
        if (nonExistingPlatos.length > 0) {
          additionalContext = `
ATENCIÓN: El usuario mencionó los siguientes platos que NO están en el menú actual: ${nonExistingPlatos.join(', ')}.
Indícale amablemente que esos platos no están disponibles y ofrece alternativas similares del menú actual.
NO inventes información sobre estos platos ni finjas que existen.
`;
        }
      }
      
      // Generar contexto estructurado del menú
      const menuContext = this.generateMenuContext(menuItems);
      
      // Generar sugerencias aleatorias
      const suggestions = this.generateSuggestions(menuItems);
      
      // Combinar todo en un contexto completo
      const fullContext = `
${this.systemPrompt}

${menuContext}

SUGERENCIAS DEL DÍA:
${suggestions.map(s => `- **${s}**`).join('\n')}

${additionalContext}

INSTRUCCIONES PARA ESTA CONSULTA:
1. Analiza cuidadosamente la consulta del cliente.
2. Si menciona un plato específico, verifica que esté en el menú actual antes de recomendarlo.
3. Usa el menú actualizado como referencia exclusiva para tus respuestas.
4. Prioriza los platos disponibles en tus recomendaciones.
5. Si piden una recomendación general, sugiere 2-3 platos de diferentes categorías.
6. Si preguntan por ingredientes, listalos de forma clara y organizada.
7. NUNCA inventes platos que no estén en el menú proporcionado.
8. NO menciones ni sugieras "tablas" a menos que aparezcan específicamente en la sección del menú.
9. Si te preguntan por tablas y no hay ninguna en el menú, indícale al cliente amablemente que no ofrecen tablas.

CONSULTA DEL CLIENTE: "${message}"

Tu respuesta como Brunchy:`;

      return {
        enrichedContext: fullContext,
        menuData: menuItems,
        suggestions: suggestions,
        sessionId: sessionId || 'guest-' + Date.now()
      };
    } catch (error) {
      console.error('Error al procesar consulta MCP:', error);
      return {
        error: 'Error al procesar consulta',
        fallbackContext: `${this.systemPrompt}\n\nCONSULTA DEL CLIENTE: "${message}"\n\nTu respuesta como Brunchy:`
      };
    }
  }
  
  /**
   * Extrae posibles nombres de platos mencionados en el mensaje del usuario
   */
  async _extractPossiblePlatos(message) {
    // Palabras comunes que indican que se está hablando de un plato
    const foodIndicators = ['plato', 'comida', 'quiero', 'tienen', 'hay', 'sirven', 'menu', 'tabla', 'tablas'];
    
    // Verificar si el mensaje contiene alguna palabra relacionada con comida
    const containsFoodWord = foodIndicators.some(word => message.includes(word));
    
    if (!containsFoodWord) {
      return []; // No parece estar hablando de platos
    }
    
    // Lista para almacenar posibles platos
    const possiblePlatos = [];
    
    // Dividir el mensaje en palabras y buscar posibles nombres de platos
    const words = message.split(/\s+/);
    
    // Buscar sustantivos que podrían ser nombres de platos (palabras con mayúscula inicial o después de indicadores)
    for (let i = 0; i < words.length; i++) {
      // Verificar si esta palabra o la siguiente tienen letra mayúscula inicial
      const currentWord = words[i];
      const nextWord = i < words.length - 1 ? words[i + 1] : '';
      
      // Verificar si estamos después de un indicador de plato
      const afterIndicator = i > 0 && foodIndicators.includes(words[i - 1].toLowerCase());
      
      // Si la palabra es "tabla" o "tablas", añadirla como posible plato
      if (currentWord.toLowerCase() === 'tabla' || currentWord.toLowerCase() === 'tablas') {
        // Si hay una palabra siguiente, considerar "tabla + palabra" como posible plato
        if (nextWord) {
          possiblePlatos.push(`${currentWord} ${nextWord}`);
          
          // Si hay dos palabras más, considerar "tabla + palabra + palabra" como posible plato
          if (i < words.length - 2) {
            possiblePlatos.push(`${currentWord} ${nextWord} ${words[i + 2]}`);
          }
        }
        possiblePlatos.push(currentWord);
      }
      
      // Si parece un nombre de plato, añadirlo a la lista
      if (afterIndicator || 
          (currentWord.length > 3 && currentWord[0] === currentWord[0].toUpperCase())) {
        possiblePlatos.push(currentWord);
        
        // Considerar combinaciones de 2 palabras como posibles nombres de platos
        if (nextWord && nextWord.length > 3) {
          possiblePlatos.push(`${currentWord} ${nextWord}`);
        }
      }
    }
    
    // Eliminar duplicados y devolver la lista de posibles platos
    return [...new Set(possiblePlatos)];
  }

  /**
   * Valida si una respuesta cumple con las reglas establecidas
   */
  validateResponse(response) {
    // Patrones prohibidos que no deben aparecer en las respuestas
    const prohibidosPatrones = [
      /como (modelo|asistente|ia|inteligencia)/i,
      /no (puedo|tengo la capacidad)/i,
      /no (estoy diseñado|fui diseñado|puedo preparar|puedo cocinar)/i,
      /como (ia|inteligencia artificial)/i
    ];
    
    // Verificar si la respuesta contiene algún patrón prohibido
    for (const patron of prohibidosPatrones) {
      if (patron.test(response)) {
        return false;
      }
    }
    
    return true;
  }

  /**
   * Corrige una respuesta que no cumple con las reglas
   */
  fixResponse(response) {
    return "¡Hola! Soy Brunchy, tu mesero en Le Brunch. Puedo recomendarte nuestros deliciosos platos, tomar tu pedido o responder preguntas sobre nuestro menú. ¿Te gustaría ver nuestras especialidades?";
  }
}

// Crear instancia de BrunchyMCP
const mcp = new BrunchyMCP();

// Endpoint para verificar el estado del servidor
app.get('/status', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Servidor en línea' });
});

// Endpoint de prueba para pedidos
app.post('/test/pedidos', (req, res) => {
  try {
    console.log('📦 Recibida solicitud de prueba para crear pedido');
    console.log('📦 Cuerpo recibido:', req.body);
    
    // Validaciones básicas
    const { idpersona, items } = req.body;
    
    if (!idpersona) {
      return res.status(400).json({ error: 'ID de persona es requerido' });
    }
    
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Se requiere al menos un item en el pedido' });
    }
    
    // Si llegamos aquí, la solicitud es válida
    return res.status(201).json({
      success: true,
      idpedido: Date.now(), // Simular un ID único
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

// Endpoint para realizar consultas directas a la base de datos
// !IMPORTANTE: Este endpoint solo debe ser usado para propósitos internos y de administración
app.post('/db/query', async (req, res) => {
  try {
    // Extraer la consulta del cuerpo de la solicitud
    const { query } = req.body;
    
    if (!query) {
      return res.status(400).json({ 
        error: "Se requiere una consulta SQL válida" 
      });
    }
    
    console.log(`📊 Ejecutando consulta SQL: ${query}`);
    
    // Ejecutar la consulta
    const result = await pool.query(query);
    
    // Devolver el resultado
    return res.status(200).json({
      success: true,
      result: result.rows,
      rowCount: result.rowCount
    });
    
  } catch (error) {
    console.error("❌ Error al ejecutar consulta SQL:", error);
    return res.status(500).json({ 
      error: "Error al ejecutar la consulta SQL",
      details: error.message 
    });
  }
});

// Endpoint para obtener el número de pedidos pendientes
app.get('/pedidos/pendientes/count', async (req, res) => {
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

// Endpoint para obtener las ventas del día actual
app.get('/pedidos/ventas/hoy', async (req, res) => {
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

// Endpoint para obtener todos los pedidos con filtros opcionales
app.get('/pedidos', async (req, res) => {
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

// Endpoint para obtener todas las métricas administrativas en una sola llamada
app.get('/admin/metrics', async (req, res) => {
  try {
    // Ejecutar todas las consultas en paralelo para mayor eficiencia
    const [activeDishesResult, usersResult, pendingOrdersResult, todaySalesResult] = await Promise.all([
      pool.query("SELECT COUNT(*) as count FROM menu WHERE disponibilidad = true"),
      pool.query("SELECT COUNT(*) as count FROM usuario"),
      pool.query("SELECT COUNT(*) as count FROM pedidos WHERE estado = 'pendiente'"),
      pool.query("SELECT COALESCE(SUM(pd.precio_unitario * pd.cantidad), 0) as total FROM pedidos p JOIN pedido_detalle pd ON p.idpedido = pd.idpedido WHERE DATE(p.fecha) = CURRENT_DATE")
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
    return res.status(500).json({ 
      error: "Error al obtener métricas administrativas",
      details: error.message 
    });
  }
});

// Endpoint para procesar consultas con MCP
app.post('/mcp/chat', async (req, res) => {
  try {
    const { message, sessionId } = req.body;
    
    // Validar que se recibió un mensaje
    if (!message) {
      return res.status(400).json({ 
        error: "Se requiere un mensaje en el cuerpo de la solicitud" 
      });
    }
    
    console.log(`[MCP] Procesando consulta: "${message}" (Sesión: ${sessionId || 'anónima'})`);
    
    // Procesar consulta con MCP
    const processedData = await mcp.processQuery(message, sessionId);
    
    // Devolver contexto enriquecido
    return res.status(200).json({
      ...processedData,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error en endpoint MCP/chat:', error);
    return res.status(500).json({ 
      error: 'Error al procesar consulta MCP',
      details: error.message 
    });
  }
});

// Endpoint del chat compatible con versión anterior
app.post('/chat', async (req, res) => {
  try {
    const { message, sessionId } = req.body;
    
    console.log('Mensaje recibido en el servidor:', message);
    console.log('Session ID:', sessionId || 'No proporcionado');
    
    if (!message) {
      return res.status(400).json({ 
        error: 'Se requiere un mensaje en el cuerpo de la solicitud' 
      });
    }
    
    // Procesamos directamente con nuestra instancia del MCP
    const processedData = await mcp.processQuery(message, sessionId);
    
    // La respuesta incluye todo el contexto enriquecido, pero para mantener compatibilidad
    // con clientes antiguos, solo devolvemos la respuesta simulada
    return res.status(200).json({ 
      response: `Respuesta a través de MCP para: "${message}"`,
      // Incluir estos campos solo para diagnóstico
      context_provided: true,
      mcp_enabled: true,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error en el endpoint de chat:', error);
    return res.status(500).json({ 
      error: 'Error al procesar el mensaje',
      details: error.message 
    });
  }
});

// Endpoint para validar respuestas generadas
app.post('/mcp/validate', (req, res) => {
  try {
    const { response } = req.body;
    
    if (!response) {
      return res.status(400).json({ 
        error: "Se requiere una respuesta para validar" 
      });
    }
    
    // Validar respuesta
    const isValid = mcp.validateResponse(response);
    
    if (isValid) {
      return res.status(200).json({
        valid: true,
        message: "La respuesta cumple con las reglas establecidas"
      });
    } else {
      // Si no es válida, proporcionar una respuesta corregida
      const fixedResponse = mcp.fixResponse(response);
      return res.status(200).json({
        valid: false,
        message: "La respuesta no cumple con las reglas establecidas",
        suggestion: fixedResponse
      });
    }
  } catch (error) {
    console.error('Error en endpoint MCP/validate:', error);
    return res.status(500).json({ 
      error: 'Error al validar respuesta',
      details: error.message 
    });
  }
});

// Endpoint para verificar estado del MCP
app.get('/mcp/status', async (req, res) => {
  try {
    // Verificar conexión a base de datos
    const dbResult = await pool.query("SELECT COUNT(*) as dish_count FROM menu");
    const dishCount = parseInt(dbResult.rows[0].dish_count);
    
    // Obtener platos disponibles
    const availableResult = await pool.query("SELECT COUNT(*) as available_count FROM menu WHERE disponibilidad = true");
    const availableDishCount = parseInt(availableResult.rows[0].available_count);
    
    return res.status(200).json({
      status: 'active',
      version: '1.2.0',
      rules: 'MCP-2024-06',
      database: {
        connected: true,
        totalDishes: dishCount,
        availableDishes: availableDishCount
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error en endpoint MCP/status:', error);
    return res.status(500).json({
      status: 'degraded',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint para eliminar un usuario
app.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`🗑️ Solicitud para eliminar usuario con ID: ${id}`);
    
    // Iniciar una transacción para asegurar que ambas eliminaciones se realicen o ninguna
    await pool.query('BEGIN');
    
    // Primero eliminar el registro de la tabla usuario
    const deleteUserResult = await pool.query(
      'DELETE FROM usuario WHERE idpersona = $1 RETURNING idpersona',
      [id]
    );
    
    if (deleteUserResult.rows.length === 0) {
      await pool.query('ROLLBACK');
      return res.status(404).json({ 
        success: false,
        message: "Usuario no encontrado"
      });
    }
    
    // Si se eliminó el usuario, proceder a eliminar la persona
    const deletePersonResult = await pool.query(
      'DELETE FROM personas WHERE idpersonas = $1 RETURNING nombre, apellido',
      [id]
    );
    
    // Confirmar la transacción
    await pool.query('COMMIT');
    
    console.log(`✅ Usuario eliminado con éxito: ${deletePersonResult.rows[0]?.nombre} ${deletePersonResult.rows[0]?.apellido}`);
    
    return res.status(200).json({
      success: true,
      message: "Usuario eliminado con éxito",
      deletedUser: {
        id: id,
        nombre: deletePersonResult.rows[0]?.nombre,
        apellido: deletePersonResult.rows[0]?.apellido
      }
    });
    
  } catch (error) {
    // Si hay un error, revertir la transacción
    await pool.query('ROLLBACK');
    console.error("❌ Error al eliminar usuario:", error);
    return res.status(500).json({ 
      success: false,
      message: "Error al eliminar el usuario",
      error: error.message
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

// Endpoint directo para solucionar problemas si el router no funciona
app.post('/pedidos-direct', async (req, res) => {
  try {
    console.log('📦 Solicitud recibida en endpoint directo /pedidos-direct');
    console.log('📦 Cuerpo recibido:', req.body);
    
    const { idpersona, estado, items } = req.body;
    
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
    
    // 2. Insertar cada detalle del pedido
    for (const item of items) {
      const { idplato, cantidad, precio_unitario } = item;
      
      if (!idplato || !cantidad || !precio_unitario) {
        await pool.query('ROLLBACK');
        return res.status(400).json({ 
          error: "Cada item debe tener idplato, cantidad y precio_unitario" 
        });
      }
      
      await pool.query(
        "INSERT INTO pedido_detalle (idpedido, idplato, cantidad, precio_unitario) VALUES ($1, $2, $3, $4)",
        [idpedido, idplato, cantidad, precio_unitario]
      );
    }
    
    // Confirmar transacción
    await pool.query('COMMIT');
    
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
    try {
      await pool.query('ROLLBACK');
    } catch (rollbackError) {
      console.error("Error en rollback:", rollbackError);
    }
    
    console.error("❌ Error al crear pedido directo:", error);
    return res.status(500).json({
      error: "Error al crear el pedido",
      details: error.message
    });
  }
});

// Iniciar el servidor
app.listen(port, ip, () => {
  console.log(`Servidor MCP unificado corriendo en http://${ip}:${port}`);
  console.log(`Endpoint MCP disponible en http://${ip}:${port}/mcp/chat`);
  console.log(`Endpoint de chat disponible en http://${ip}:${port}/chat`);
  console.log('Sistema MCP activo con todas las funcionalidades incluidas');
});


