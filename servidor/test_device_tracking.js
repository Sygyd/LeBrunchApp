// Test script para verificar el sistema de tracking de dispositivos
const http = require('http');

// Configuración de prueba
const SERVER_URL = 'http://192.168.100.228:3000'; // IP del servidor
const TEST_MACS = [
  '09:7F:32:DB:00:00', // Mesa 12 - Samsung
  '17:56:BA:18:00:00', // Mesa 13 - Dispositivo de prueba
  'AA:BB:CC:DD:EE:14', // Mesa 14 - No conectada
];

console.log('🧪 =========================');
console.log('🧪 TEST: Sistema de Tracking de Dispositivos');
console.log('🧪 =========================\n');

// Función para hacer peticiones HTTP
function makeRequest(method, endpoint, data = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint, SERVER_URL);
    const options = {
      method: method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          resolve({ status: res.statusCode, data: response });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// Simular actividad de dispositivo (como si enviara un mensaje de chat)
async function simulateDeviceActivity(macAddress, deviceName, tableNumber) {
  console.log(`📱 Simulando actividad para: ${deviceName} (${macAddress})`);
  
  try {
    const response = await makeRequest('POST', '/chat', {
      message: 'Hola Brunchy, ¿cómo estás?',
      sessionId: `test_session_${tableNumber}`,
      isAdmin: false,
      deviceInfo: {
        macAddress: macAddress,
        deviceName: deviceName,
        platform: 'Android',
        deviceId: `test_device_${tableNumber}`
      }
    });

    console.log(`   ✅ Respuesta del servidor: ${response.status}`);
    return response.status === 200;
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    return false;
  }
}

// Verificar estado de un dispositivo específico
async function checkDeviceStatus(macAddress) {
  console.log(`🔍 Verificando estado de: ${macAddress}`);
  
  try {
    const response = await makeRequest('POST', '/api/table/debug/mac', {
      macAddress: macAddress
    });

    if (response.status === 200) {
      const data = response.data;
      const isActive = data.success && data.table?.isActive;
      const lastSeen = data.realTimeStatus?.lastSeenHuman || 'Nunca';
      
      console.log(`   📊 Estado: ${isActive ? '🟢 Conectado' : '🔴 Desconectado'}`);
      console.log(`   📅 Última actividad: ${lastSeen}`);
      
      return isActive;
    } else {
      console.log(`   ❌ Error del servidor: ${response.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    return false;
  }
}

// Obtener estado general de todos los dispositivos
async function getGeneralStatus() {
  console.log(`📋 Obteniendo estado general de dispositivos...`);
  
  try {
    const response = await makeRequest('GET', '/api/table/debug/mac');

    if (response.status === 200) {
      const data = response.data;
      console.log(`   📊 Dispositivos activos: ${data.activeDevicesCount}/${data.configuredDevicesCount}`);
      console.log(`   ⏰ Timeout: ${data.timeoutMinutes} minutos\n`);
      
      console.log('   📱 Estado por mesa:');
      Object.entries(data.deviceStatus || {}).forEach(([key, device]) => {
        const status = device.isActive ? '🟢' : '🔴';
        console.log(`     ${status} Mesa ${device.tableNumber}: ${device.deviceName}`);
        console.log(`        └── Última actividad: ${device.lastSeenHuman}`);
      });
      
      return data;
    } else {
      console.log(`   ❌ Error del servidor: ${response.status}`);
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    return null;
  }
}

// Función principal de prueba
async function runTests() {
  console.log('🚀 Iniciando pruebas...\n');

  // 1. Obtener estado inicial
  console.log('1️⃣ Estado inicial:');
  await getGeneralStatus();
  console.log('\n' + '='.repeat(50) + '\n');

  // 2. Simular actividad solo en Mesa 12 (Samsung)
  console.log('2️⃣ Simulando actividad en Mesa 12...');
  const success = await simulateDeviceActivity(
    '09:7F:32:DB:00:00',
    'Samsung SM-A556E Test',
    12
  );
  
  if (success) {
    console.log('   ✅ Actividad registrada exitosamente');
  } else {
    console.log('   ❌ Error al registrar actividad');
  }
  
  // Esperar un momento para que se procese
  await new Promise(resolve => setTimeout(resolve, 1000));
  console.log('\n' + '='.repeat(50) + '\n');

  // 3. Verificar estado después de la actividad
  console.log('3️⃣ Estado después de simular actividad:');
  await getGeneralStatus();
  console.log('\n' + '='.repeat(50) + '\n');

  // 4. Verificar estados individuales
  console.log('4️⃣ Verificación individual de cada dispositivo:');
  for (const mac of TEST_MACS) {
    await checkDeviceStatus(mac);
    console.log('');
  }
  
  console.log('='.repeat(50));
  console.log('✅ Pruebas completadas');
  console.log('\n🔍 RESULTADOS ESPERADOS:');
  console.log('- Mesa 12: Debe aparecer como CONECTADA (acabamos de simular actividad)');
  console.log('- Mesa 13 y 14: Deben aparecer como DESCONECTADAS (sin actividad reciente)');
  console.log('\n💡 Si Mesa 12 no aparece como conectada, hay un problema con el tracking.');
  console.log('💡 Si Mesa 13 o 14 aparecen como conectadas, el fallback hardcodeado sigue activo.');
}

// Ejecutar las pruebas
runTests().catch(console.error); 