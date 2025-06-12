console.log('🧪 Iniciando prueba básica de Node.js...');

const os = require('os');
const interfaces = os.networkInterfaces();

console.log('🌐 Interfaces de red detectadas:');
for (const name of Object.keys(interfaces)) {
  for (const iface of interfaces[name]) {
    if (iface.family === 'IPv4' && !iface.internal) {
      console.log(`  ${name}: ${iface.address}`);
    }
  }
}

console.log('✅ Prueba completada'); 