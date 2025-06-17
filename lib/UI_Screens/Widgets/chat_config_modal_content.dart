import 'package:flutter/material.dart';
import '../../Api_services/global_config_service.dart';
import '../../Api_services/network_config_service.dart';
import '../../Api_services/menu/menu_service.dart';
import '../../config.dart'; // 🔥 IMPORTAR AppConfig
import 'network_diagnostic_widget.dart';

class ChatConfigModalContent extends StatefulWidget {
  final VoidCallback? onConfigSaved;

  const ChatConfigModalContent({Key? key, this.onConfigSaved})
    : super(key: key);

  @override
  State<ChatConfigModalContent> createState() => _ChatConfigModalContentState();
}

class _ChatConfigModalContentState extends State<ChatConfigModalContent> {
  final GlobalConfigService _globalConfig = GlobalConfigService();
  final NetworkConfigService _networkConfig = NetworkConfigService();
  final MenuService _menuService = MenuService();

  // Controladores para las configuraciones
  final TextEditingController _serverIpController = TextEditingController();

  // Variables de estado
  bool _showSystemMessages = true;
  bool _debugMode = false;
  bool _enableReports = true;
  bool _enablePopularDishes = true;
  String _currentModel =
      "gemini-2.5-flash-preview-05-20"; // 🔥 MODELO ACTUALIZADO
  bool _isLoading = false;
  bool _isConnected = false;
  bool _initialSetupComplete = false;

  // Información del sistema
  Map<String, dynamic>? _serverStatus;

  @override
  void initState() {
    super.initState();
    _performInitialSetup();
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }

  // NUEVO: Setup inicial robusto que espera por auto-discovery
  Future<void> _performInitialSetup() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print('🔧 Modal: Iniciando setup inicial robusto...');

      // PASO 1: Asegurar que NetworkConfigService esté completamente inicializado (OPTIMIZADO)
      print('⏳ Modal: Verificando NetworkConfigService...');
      await _ensureNetworkConfigReady();

      // PASO 2: Cargar configuración usando la IP correcta
      print('📋 Modal: Cargando configuración con IP actualizada...');
      await _loadCurrentSettings();

      // PASO 3: Verificar conexión de forma optimizada y en paralelo
      print('🔌 Modal: Verificando estado de conexión...');
      _checkServerStatusOptimized(); // No esperar a que termine

      setState(() => _initialSetupComplete = true);
      print('✅ Modal: Setup inicial completado');
    } catch (e) {
      print('❌ Modal: Error en setup inicial: $e');
      // Continuar con configuración básica aunque falle
      await _loadCurrentSettings();
      setState(() => _initialSetupComplete = true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // OPTIMIZADO: Versión más rápida que no bloquea la UI
  Future<void> _ensureNetworkConfigReady() async {
    const maxWaitTime = 3; // Reducido de 8 a 3 segundos
    const checkInterval = 200; // Reducido de 500 a 200 milisegundos
    int attempts = 0;
    int maxAttempts = (maxWaitTime * 1000) ~/ checkInterval;

    while (attempts < maxAttempts) {
      try {
        // Verificar si NetworkConfigService tiene una IP configurada
        final networkIp = _networkConfig.serverIp;

        if (networkIp.isNotEmpty && !_isObsoleteIp(networkIp)) {
          print('✅ Modal: NetworkConfigService listo con IP: $networkIp');
          return;
        }

        // Si no está listo, esperar un poco menos
        attempts++;
        await Future.delayed(const Duration(milliseconds: checkInterval));
      } catch (e) {
        print('⚠️ Modal: Error verificando NetworkConfigService: $e');
        break;
      }
    }

    print('⏰ Modal: Timeout optimizado, continuando...');
  }

  // NUEVO: Verificación de estado optimizada que no bloquea la UI
  Future<void> _checkServerStatusOptimized() async {
    try {
      // Verificar conexión rápida primero
      final isConnected = await _globalConfig.testConnection();

      setState(() {
        _isConnected = isConnected;
      });

      // Si está conectado, obtener detalles en segundo plano
      if (isConnected) {
        _getServerStatusInBackground();
      }
    } catch (e) {
      print('❌ Modal: Error en verificación optimizada: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  // NUEVO: Obtener estado del servidor en segundo plano
  Future<void> _getServerStatusInBackground() async {
    try {
      final status = await _globalConfig.getServerStatus();
      if (mounted) {
        setState(() {
          _serverStatus = status;
        });
      }
    } catch (e) {
      print('❌ Modal: Error obteniendo estado en segundo plano: $e');
    }
  }

  // NUEVO: Detectar IPs obsoletas
  bool _isObsoleteIp(String ip) {
    const obsoleteIPs = ['192.168.1.121', '192.168.1.136'];
    return obsoleteIPs.contains(ip);
  }

  Future<void> _loadCurrentSettings() async {
    try {
      // MEJORADO: Cargar configuración pero usar IP del NetworkConfigService si está disponible
      await _globalConfig.loadConfig();

      // Usar IP del NetworkConfigService si está disponible y es más actualizada
      String ipToUse = _globalConfig.serverIp;
      final networkIp = _networkConfig.serverIp;

      if (networkIp.isNotEmpty && !_isObsoleteIp(networkIp)) {
        if (_isObsoleteIp(ipToUse) || ipToUse != networkIp) {
          print(
            '🔄 Modal: Usando IP del NetworkConfigService: $networkIp (vs GlobalConfig: $ipToUse)',
          );
          ipToUse = networkIp;

          // Actualizar GlobalConfigService con la IP correcta
          await _globalConfig.updateServerConfig(serverIp: networkIp);
        }
      }

      setState(() {
        _serverIpController.text = ipToUse;
        // 🔥 CORREGIDO: Cargar el modelo actual sin forzar cambios, pero validar que esté en las opciones disponibles
        _currentModel = _globalConfig.currentModel;

        // Validar que el modelo cargado esté en las opciones disponibles del dropdown
        const availableModels = [
          'gemini-2.5-flash-preview-05-20',
          'gemini-2.0-flash',
          'gemini-1.5-flash',
        ];

        if (!availableModels.contains(_currentModel)) {
          print(
            '⚠️ Modal: Modelo "$_currentModel" no está en las opciones disponibles, usando por defecto',
          );
          _currentModel = "gemini-2.5-flash-preview-05-20";
        }

        print('📋 Modal: Modelo final configurado: $_currentModel');

        _enableReports = _globalConfig.enableReports;
        _enablePopularDishes = _globalConfig.enablePopularDishes;
        _showSystemMessages = _globalConfig.showSystemMessages;
        _debugMode = _globalConfig.debugMode;
      });
      print(
        '🔧 Modal: Configuración cargada - IP: $ipToUse, Modelo: $_currentModel',
      );
    } catch (e) {
      print('❌ Modal: Error al cargar configuraciones: $e');
    }
  }

  Future<void> _checkServerStatus() async {
    if (!_initialSetupComplete) return; // No verificar durante setup inicial

    setState(() => _isLoading = true);
    try {
      // Verificación rápida primero
      final isConnected = await _globalConfig.testConnection();

      setState(() {
        _isConnected = isConnected;
      });

      // Solo obtener detalles del servidor si está conectado
      if (isConnected) {
        final status = await _globalConfig.getServerStatus();
        if (mounted) {
          setState(() {
            _serverStatus = status;
          });
        }
      } else {
        // Limpiar status si no está conectado
        setState(() {
          _serverStatus = null;
        });
      }

      // CAMBIADO: Solo mostrar mensaje si el modal ya está completamente inicializado
      if (!isConnected && mounted && _initialSetupComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se pudo conectar con el servidor'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Modal: Error al verificar estado del servidor: $e');
      setState(() {
        _isConnected = false;
        _serverStatus = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      // 🔥 CORREGIDO: Permitir guardar cualquier modelo seleccionado por el usuario
      print('💾 Modal: Guardando modelo seleccionado: $_currentModel');

      // Actualizar configuración usando GlobalConfigService (sin cambiar IP)
      final success = await _globalConfig.updateServerConfig(
        model: _currentModel,
        enableReports: _enableReports,
        enablePopularDishes: _enablePopularDishes,
        showSystemMessages: _showSystemMessages,
        debugMode: _debugMode,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Configuración guardada exitosamente'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );

          // Llamar callback para notificar al chat
          widget.onConfigSaved?.call();

          // Actualizar estado del servidor
          await _checkServerStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error al guardar configuración en el servidor'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NUEVO: Método para corregir URLs de imágenes
  Future<void> _fixImageUrls() async {
    setState(() => _isLoading = true);
    try {
      final result = await _menuService.fixImageUrls();

      if (mounted) {
        final urlsCorregidas = result['urlsCorregidas'] ?? 0;
        final urlsNoNecesitaban = result['urlsNoNecesitanCorreccion'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ URLs corregidas: $urlsCorregidas | Sin cambios: $urlsNoNecesitaban',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al corregir URLs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFromServer() async {
    setState(() => _isLoading = true);
    try {
      // 🔥 ACTUALIZADO: Obtener estado del servidor y recargar configuración
      final serverStatus = await _globalConfig.getServerStatus();
      if (serverStatus != null && serverStatus['connected'] == true) {
        await _globalConfig.loadConfig();
        await _loadCurrentSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Configuración recargada desde servidor ${AppConfig.serverUrl}',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se pudo conectar con el servidor'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 ACTUALIZADO: Forzar sincronización manual
  Future<void> _forceSyncWithServer() async {
    setState(() => _isLoading = true);
    try {
      // Guardar configuración actual al servidor
      final success = await _globalConfig.updateServerConfig(
        model: _currentModel,
        enableReports: _enableReports,
        enablePopularDishes: _enablePopularDishes,
        showSystemMessages: _showSystemMessages,
        debugMode: _debugMode,
      );

      if (success) {
        await _loadCurrentSettings();
        // Verificar estado del servidor
        final serverStatus = await _globalConfig.getServerStatus();

        if (mounted) {
          String message = '✅ Sincronización completada';
          if (serverStatus != null && serverStatus['connected'] == true) {
            final geminiModel = serverStatus['geminiModel'];
            final currentServerModel = geminiModel?['current'] ?? 'desconocido';

            message += '\n🤖 Modelo en servidor: $currentServerModel';
            message += '\n🌐 URL: ${AppConfig.serverUrl}';

            if (currentServerModel != _currentModel) {
              message +=
                  '\n⚠️ Modelos diferentes: servidor ($currentServerModel) vs local ($_currentModel)';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error en sincronización manual'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en sincronización: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando configuración...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estado del Sistema
          _buildSystemStatusCard(),
          const SizedBox(height: 20),

          // Configuración del Asistente
          _buildAssistantConfigCard(),
          const SizedBox(height: 20),

          // Configuración de Sistema
          _buildSystemConfigCard(),
          const SizedBox(height: 30),

          // Botones de acción
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    // Determinar el estado visual basado en el progreso de inicialización
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!_initialSetupComplete) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
      statusText = 'Verificando...';
    } else if (_isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.wifi;
      statusText = 'Conectado';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.wifi_off;
      statusText = 'Desconectado';
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.monitor_heart,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estado del Sistema',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mostrar IP del servidor siempre
            _buildStatusRow(
              'IP del Servidor',
              _serverIpController.text.isNotEmpty
                  ? _serverIpController.text
                  : AppConfig.serverIp,
            ),
            if (_serverStatus != null) ...[
              _buildStatusRow('Estado', _serverStatus!['status'] ?? 'unknown'),
              _buildStatusRow(
                'Versión',
                _serverStatus!['version'] ?? 'unknown',
              ),
              if (_serverStatus!['geminiModel'] != null) ...[
                _buildStatusRowWithOverflow(
                  'Modelo Activo',
                  _serverStatus!['geminiModel']['current'] ?? 'unknown',
                ),
              ],
              if (_serverStatus!['keyRotation'] != null) ...[
                _buildStatusRow(
                  'Claves API',
                  '${_serverStatus!['keyRotation']['totalKeys']} configuradas',
                ),
                _buildStatusRow(
                  'Clave Activa',
                  '#${_serverStatus!['keyRotation']['currentKeyIndex']}',
                ),
              ],
            ] else if (!_initialSetupComplete)
              const Text('Inicializando conexión con el servidor...')
            else
              const Text('No se pudo cargar el estado del sistema...'),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantConfigCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Asistente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentModel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Modelo de Gemini',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.auto_awesome),
              ),
              items: [
                DropdownMenuItem(
                  value: 'gemini-2.5-flash-preview-05-20',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'RECOMENDADO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Flash 2.5 Preview')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.0-flash',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ESTABLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Flash 2.0')),
                    ],
                  ),
                ),
                const DropdownMenuItem(
                  value: 'gemini-1.5-flash',
                  child: Text('Flash 1.5 (Legacy)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currentModel = value);
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Reportes'),
              subtitle: const Text(
                'Habilitar reportes de ventas y estadísticas',
              ),
              value: _enableReports,
              onChanged: (value) => setState(() => _enableReports = value),
              secondary: const Icon(Icons.analytics),
            ),
            SwitchListTile(
              title: const Text('Platos Populares'),
              subtitle: const Text(
                'Mostrar información de platos más vendidos',
              ),
              value: _enablePopularDishes,
              onChanged:
                  (value) => setState(() => _enablePopularDishes = value),
              secondary: const Icon(Icons.trending_up),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemConfigCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sistema',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Mensajes del Sistema'),
              subtitle: const Text('Mostrar mensajes de estado y debug'),
              value: _showSystemMessages,
              onChanged: (value) => setState(() => _showSystemMessages = value),
              secondary: const Icon(Icons.message),
            ),
            SwitchListTile(
              title: const Text('Modo Debug'),
              subtitle: const Text('Habilitar funciones de depuración'),
              value: _debugMode,
              onChanged: (value) => setState(() => _debugMode = value),
              secondary: const Icon(Icons.bug_report),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NUEVO: Widget especial para el modelo activo que maneja overflow
  Widget _buildStatusRowWithOverflow(String label, String value) {
    // Acortar el nombre del modelo si es muy largo
    String displayValue = value;
    if (value.length > 20) {
      if (value.contains('gemini-2.5-flash-preview')) {
        displayValue = 'Gemini 2.5 Preview';
      } else if (value.contains('gemini-2.0-flash')) {
        displayValue = 'Gemini 2.0 Flash';
      } else if (value.contains('gemini-1.5-flash')) {
        displayValue = 'Gemini 1.5 Flash';
      } else if (value.contains('gemini-1.5-pro')) {
        displayValue = 'Gemini 1.5 Pro';
      } else if (value.contains('gemini-1.0-pro')) {
        displayValue = 'Gemini 1.0 Pro';
      } else {
        // Para otros modelos, truncar genéricamente
        displayValue =
            value.length > 18 ? '${value.substring(0, 15)}...' : value;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Tooltip(
                message: value, // Mostrar el valor completo en tooltip
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Guardar Configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _checkServerStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar Estado'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadFromServer,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Cargar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _forceSyncWithServer,
                icon: const Icon(Icons.sync_alt),
                label: const Text('Sincronizar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openNetworkDiagnostic,
                icon: const Icon(Icons.network_check),
                label: const Text('Diagnóstico'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // NUEVO: Botón para corregir URLs de imágenes
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _fixImageUrls,
            icon: const Icon(Icons.image_search),
            label: const Text('Corregir URLs de Imágenes'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.orange, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _openNetworkDiagnostic() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NetworkDiagnosticWidget()),
    );
  }
}
