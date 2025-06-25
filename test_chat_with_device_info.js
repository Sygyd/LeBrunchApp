// Script para probar envío de chat con deviceInfo
const http = require('http');

const SERVER_URL = 'http://192.168.100.228:3000';

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

async function testChatWithDeviceInfo() {
  console.log('🧪 Probando chat con deviceInfo...\n');

  try {
    // Simular exactamente lo que debería enviar el Flutter app
    const chatData = {
      message: 'Hola Brunchy, soy un dispositivo de prueba',
      sessionId: 'flutter_test_session',
      isAdmin: false,
      clientId: 10,
      deviceInfo: {
        macAddress: '09:7F:32:DB:00:00',
        deviceName: 'samsung SM-A556E',
        platform: 'Android',
        deviceId: 'UP1A.231005.007'
      }
    };

    console.log('📤 Enviando mensaje con deviceInfo:');
    console.log('   📱 MAC:', chatData.deviceInfo.macAddress);
    console.log('   📱 Dispositivo:', chatData.deviceInfo.deviceName);
    console.log('   💬 Mensaje:', chatData.message);

    const response = await makeRequest('POST', '/chat', chatData);

    console.log('\n📬 Respuesta del servidor:');
    console.log('   📊 Status:', response.status);
    console.log('   📝 Respuesta:', response.data.text_response?.substring(0, 100) + '...' || 'Sin respuesta');

    if (response.status === 200) {
      console.log('\n✅ Chat enviado exitosamente');
      console.log('🔍 Ahora verifica en los logs del servidor si aparecen:');
      console.log('   - "📱 Chat [req_xxx]: deviceInfo recibido:"');
      console.log('   - "🔄 registerDeviceActivity llamada con:"');
      console.log('   - "✅ Actividad registrada: Mesa 12"');
    } else {
      console.log('\n❌ Error en el chat');
    }

    // Verificar estado después del chat
    console.log('\n🔍 Verificando estado de dispositivos después del chat...');
    const statusResponse = await makeRequest('GET', '/api/table/debug/mac');
    
    if (statusResponse.status === 200) {
      const data = statusResponse.data;
      console.log(`📊 Dispositivos activos: ${data.activeDevicesCount}/${data.configuredDevicesCount}`);
      
      if (data.deviceStatus) {
        Object.entries(data.deviceStatus).forEach(([key, device]) => {
          const status = device.isActive ? '🟢 Conectado' : '🔴 Desconectado';
          console.log(`   ${status} Mesa ${device.tableNumber}: ${device.lastSeenHuman}`);
        });
      }
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testChatWithDeviceInfo(); 