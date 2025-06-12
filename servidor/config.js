// Configuración centralizada del servidor
const os = require('os');

// Función para obtener la IP local automáticamente
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  const candidates = [];
  
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      // Buscar IPv4 que no sea localhost
      if (iface.family === 'IPv4' && !iface.internal) {
        // Recopilar todas las IPs privadas
        if (iface.address.startsWith('192.168.')) {
          candidates.push({ ip: iface.address, priority: 1, interface: name }); // Prioridad alta
        } else if (iface.address.startsWith('10.')) {
          candidates.push({ ip: iface.address, priority: 2, interface: name }); // Prioridad media
        } else if (iface.address.startsWith('172.') && 
                   parseInt(iface.address.split('.')[1]) >= 16 && 
                   parseInt(iface.address.split('.')[1]) <= 31) {
          candidates.push({ ip: iface.address, priority: 3, interface: name }); // Prioridad baja
        }
      }
    }
  }
  
  // Ordenar por prioridad y seleccionar la mejor
  if (candidates.length > 0) {
    candidates.sort((a, b) => a.priority - b.priority);
    console.log(`🔍 IPs detectadas:`, candidates.map(c => `${c.ip} (${c.interface}, prioridad ${c.priority})`));
    console.log(`✅ Seleccionada: ${candidates[0].ip} (${candidates[0].interface})`);
    return candidates[0].ip;
  }
  
  // Fallback a localhost si no encuentra IP privada
  console.log('⚠️ No se encontraron IPs privadas, usando localhost');
  return '127.0.0.1';
}

// Configuración del servidor
const config = {
  // IP del servidor - se auto-detecta o se puede establecer manualmente
  host: process.env.SERVER_HOST || getLocalIP(),
  
  // Puerto del servidor
  port: process.env.PORT || 3000,
  
  // URLs de base de datos
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    name: process.env.DB_NAME || 'le_brunch_db',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || ''
  },
  
  // Configuración de uploads
  uploads: {
    directory: './uploads',
    maxFileSize: 10 * 1024 * 1024, // 10MB
    allowedTypes: ['image/jpeg', 'image/png', 'image/gif', 'audio/wav', 'audio/mp3']
  },
  
  // URLs de APIs externas
  apis: {
    gemini: {
      baseUrl: 'https://generativelanguage.googleapis.com',
      keys: [
        process.env.GEMINI_API_KEY_1,
        process.env.GEMINI_API_KEY_2,
        process.env.GEMINI_API_KEY_3
      ].filter(key => key && key !== 'FALLBACK_KEY_1' && key !== 'FALLBACK_KEY_2' && key !== 'FALLBACK_KEY_3')
    }
  },
  
  // Configuración de CORS
  cors: {
    origins: ['*'], // En producción, especificar dominios específicos
    credentials: true
  }
};

// Función para generar URLs dinámicamente
config.getServerUrl = () => `http://${config.host}:${config.port}`;
config.getUploadUrl = (filename) => `${config.getServerUrl()}/uploads/${filename}`;

// Validar configuración al cargar
function validateConfig() {
  console.log('🔧 Validando configuración del servidor...');
  console.log(`📍 IP detectada: ${config.host}`);
  console.log(`🚪 Puerto: ${config.port}`);
  console.log(`🌐 URL completa: ${config.getServerUrl()}`);
  
  // Verificar APIs keys
  if (config.apis.gemini.keys.length === 0) {
    console.warn('⚠️ No se encontraron claves válidas de Gemini API');
  } else {
    console.log(`🔑 ${config.apis.gemini.keys.length} claves de Gemini configuradas`);
  }
  
  return config;
}

module.exports = validateConfig(); 