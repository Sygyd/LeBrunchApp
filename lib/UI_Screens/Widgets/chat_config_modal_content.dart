import 'package:flutter/material.dart';
import '../../Api_services/global_config_service.dart';

class ChatConfigModalContent extends StatefulWidget {
  final VoidCallback? onConfigSaved;

  const ChatConfigModalContent({Key? key, this.onConfigSaved})
    : super(key: key);

  @override
  State<ChatConfigModalContent> createState() => _ChatConfigModalContentState();
}

class _ChatConfigModalContentState extends State<ChatConfigModalContent> {
  final GlobalConfigService _globalConfig = GlobalConfigService();

  // Controladores para las configuraciones
  final TextEditingController _serverIpController = TextEditingController();

  // Variables de estado
  bool _showSystemMessages = true;
  bool _debugMode = false;
  bool _enableReports = true;
  bool _enablePopularDishes = true;
  bool _enableMenuManagement = true;
  String _currentModel = "gemini-2.0-flash";
  bool _isLoading = false;
  bool _isConnected = false;

  // Información del sistema
  Map<String, dynamic>? _serverStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _checkServerStatus();
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      await _globalConfig.loadConfig();
      setState(() {
        _serverIpController.text = _globalConfig.serverIp;
        _currentModel = _globalConfig.currentModel;
        _enableReports = _globalConfig.enableReports;
        _enablePopularDishes = _globalConfig.enablePopularDishes;
        _enableMenuManagement = _globalConfig.enableMenuManagement;
        _showSystemMessages = _globalConfig.showSystemMessages;
        _debugMode = _globalConfig.debugMode;
      });
      print('🔧 Modal: Configuración cargada desde GlobalConfigService');
    } catch (e) {
      print('❌ Error al cargar configuraciones: $e');
    }
  }

  Future<void> _checkServerStatus() async {
    setState(() => _isLoading = true);
    try {
      final isConnected = await _globalConfig.testConnection();
      final status = await _globalConfig.getServerStatus();

      setState(() {
        _isConnected = isConnected;
        _serverStatus = status;
      });

      if (!isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se pudo conectar con el servidor'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al verificar estado del servidor: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      // Actualizar configuración usando GlobalConfigService
      final success = await _globalConfig.updateServerConfig(
        serverIp: _serverIpController.text.trim(),
        model: _currentModel,
        enableReports: _enableReports,
        enablePopularDishes: _enablePopularDishes,
        enableMenuManagement: _enableMenuManagement,
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

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    try {
      final result = await _globalConfig.testConnectionWithDetails(
        _serverIpController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Prueba completada'),
            backgroundColor:
                result['success']
                    ? Theme.of(context).colorScheme.primary
                    : Colors.red,
          ),
        );

        setState(() {
          _isConnected = result['success'] ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al probar conexión: $e'),
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
      final success = await _globalConfig.loadConfigFromServer();
      if (success) {
        await _loadCurrentSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '✅ Configuración sincronizada desde servidor',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se pudo cargar configuración del servidor'),
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

          // Configuración del Servidor
          _buildServerConfigCard(),
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
                    color:
                        _isConnected
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        size: 12,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected ? 'Conectado' : 'Desconectado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_serverStatus != null) ...[
              _buildStatusRow('Estado', _serverStatus!['status'] ?? 'unknown'),
              _buildStatusRow(
                'Versión',
                _serverStatus!['version'] ?? 'unknown',
              ),
              if (_serverStatus!['geminiModel'] != null) ...[
                _buildStatusRow(
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
            ] else
              const Text('No se pudo cargar el estado del sistema...'),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard() {
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
                    Icons.dns,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Servidor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverIpController,
              decoration: const InputDecoration(
                labelText: 'IP del Servidor',
                hintText: '192.168.1.121',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
            ),
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
                  value: 'gemini-2.0-flash',
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
                          'NUEVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Flash 2.0')),
                    ],
                  ),
                ),
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
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BETA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Flash 2.5 Preview')),
                    ],
                  ),
                ),
                const DropdownMenuItem(
                  value: 'gemini-1.5-flash',
                  child: Text('Flash 1.5'),
                ),
                const DropdownMenuItem(
                  value: 'gemini-1.5-pro',
                  child: Text('Pro 1.5'),
                ),
                const DropdownMenuItem(
                  value: 'gemini-1.0-pro',
                  child: Text('Pro 1.0'),
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
            SwitchListTile(
              title: const Text('Gestión de Menú'),
              subtitle: const Text('Permitir gestión del menú desde el chat'),
              value: _enableMenuManagement,
              onChanged:
                  (value) => setState(() => _enableMenuManagement = value),
              secondary: const Icon(Icons.restaurant_menu),
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
                onPressed: _isLoading ? null : _testConnection,
                icon: const Icon(Icons.wifi_find),
                label: const Text('Probar'),
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
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar'),
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
      ],
    );
  }
}
