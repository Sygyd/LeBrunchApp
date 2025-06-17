import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Api_services/network_config_service.dart';
import '../../config.dart';
import '../../theme/theme.dart';

class NetworkDiagnosticWidget extends StatefulWidget {
  const NetworkDiagnosticWidget({super.key});

  @override
  State<NetworkDiagnosticWidget> createState() =>
      _NetworkDiagnosticWidgetState();
}

class _NetworkDiagnosticWidgetState extends State<NetworkDiagnosticWidget> {
  final NetworkConfigService _networkService = NetworkConfigService();
  Map<String, dynamic>? _diagnosticInfo;
  Map<String, dynamic>? _serverStatus;
  bool _isLoading = false;
  bool _isRediscovering = false;
  bool _isSmartRecovering = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnosticInfo();
  }

  Future<void> _loadDiagnosticInfo() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final networkDiagnosticInfo = _networkService.getDiagnosticInfo();
      final appConfigInfo = AppConfig.getConfigInfo();
      final serverStatus = await _networkService.checkServerStatus();

      // 🔥 NUEVO: Crear información organizada y útil sin N/A
      final combinedDiagnosticInfo = <String, dynamic>{};

      // Información esencial del servidor (siempre disponible)
      combinedDiagnosticInfo['Server IP'] = appConfigInfo['currentIp'];
      combinedDiagnosticInfo['Server Port'] = appConfigInfo['serverPort'];
      combinedDiagnosticInfo['Base URL'] = appConfigInfo['serverUrl'];

      // Solo agregar configuración de red si tiene valores útiles
      final networkIp = networkDiagnosticInfo['serverIp'];
      if (networkIp != null &&
          networkIp.toString().isNotEmpty &&
          networkIp != appConfigInfo['currentIp']) {
        combinedDiagnosticInfo['Network Service IP'] = networkIp;
      }

      final networkPort = networkDiagnosticInfo['serverPort'];
      if (networkPort != null &&
          networkPort.toString().isNotEmpty &&
          networkPort != appConfigInfo['serverPort']) {
        combinedDiagnosticInfo['Network Service Port'] = networkPort;
      }

      // Estado de configuración
      combinedDiagnosticInfo['Is Configured'] =
          networkDiagnosticInfo['isConfigured'] == true ? 'true' : 'false';
      combinedDiagnosticInfo['Is Using Default'] =
          appConfigInfo['isUsingDefault'] == true ? 'true' : 'false';

      // Solo mostrar información de descubrimiento si existe
      final lastDiscovery = networkDiagnosticInfo['lastDiscovery'];
      if (lastDiscovery != null) {
        try {
          final discoveryDate = DateTime.parse(lastDiscovery);
          final now = DateTime.now();
          final difference = now.difference(discoveryDate);

          if (difference.inDays > 0) {
            combinedDiagnosticInfo['Last Discovery'] =
                '${difference.inDays} días atrás';
          } else if (difference.inHours > 0) {
            combinedDiagnosticInfo['Last Discovery'] =
                '${difference.inHours} horas atrás';
          } else if (difference.inMinutes > 0) {
            combinedDiagnosticInfo['Last Discovery'] =
                '${difference.inMinutes} minutos atrás';
          } else {
            combinedDiagnosticInfo['Last Discovery'] = 'Hace poco';
          }
        } catch (e) {
          // Si no se puede parsear la fecha, no mostrar nada
        }
      }

      // Solo mostrar cache age si es útil
      final cacheAge = networkDiagnosticInfo['cacheAge'];
      if (cacheAge != null && cacheAge > 0) {
        if (cacheAge > 60) {
          combinedDiagnosticInfo['Cache Age'] =
              '${(cacheAge / 60).toStringAsFixed(1)} horas';
        } else {
          combinedDiagnosticInfo['Cache Age'] = '$cacheAge minutos';
        }
      }

      if (mounted) {
        setState(() {
          _diagnosticInfo = combinedDiagnosticInfo;
          _serverStatus = serverStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'Error al obtener información de diagnóstico: $e',
          Colors.red,
        );
      }
    }
  }

  Future<void> _forceRediscovery() async {
    if (mounted) {
      setState(() => _isRediscovering = true);
    }

    try {
      final success = await _networkService.forceRediscovery();

      if (mounted) {
        setState(() => _isRediscovering = false);

        if (success) {
          _showSnackBar('✅ Servidor re-descubierto exitosamente', Colors.green);
          await _loadDiagnosticInfo(); // ✅ Recargar información después de éxito
        } else {
          _showSnackBar('❌ No se pudo encontrar el servidor', Colors.orange);
          await _loadDiagnosticInfo(); // ✅ Recargar incluso si no tuvo éxito para mostrar estado actual
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRediscovering = false);
        _showSnackBar('Error durante re-descubrimiento: $e', Colors.red);
        await _loadDiagnosticInfo(); // ✅ Recargar incluso en caso de error
      }
    }
  }

  Future<void> _refreshConfiguration() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final success = await _networkService.refreshConfiguration();

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          _showSnackBar('✅ Configuración refrescada', Colors.green);
          await _loadDiagnosticInfo();
        } else {
          _showSnackBar(
            '⚠️ Configuración refrescada con warnings',
            Colors.orange,
          );
          await _loadDiagnosticInfo();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error al refrescar configuración: $e', Colors.red);
        await _loadDiagnosticInfo(); // ✅ Recargar incluso en caso de error
      }
    }
  }

  Future<void> _smartRecovery() async {
    if (mounted) {
      setState(() => _isSmartRecovering = true);
    }

    try {
      final success = await _networkService.smartRecovery();

      if (mounted) {
        setState(() => _isSmartRecovering = false);

        if (success) {
          _showSnackBar('🧠 Recuperación inteligente exitosa', Colors.green);
          await _loadDiagnosticInfo();
        } else {
          _showSnackBar('❌ No se pudo recuperar la conexión', Colors.orange);
          await _loadDiagnosticInfo(); // ✅ Recargar incluso si no tuvo éxito
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSmartRecovering = false);
        _showSnackBar('Error en recuperación inteligente: $e', Colors.red);
        await _loadDiagnosticInfo(); // ✅ Recargar incluso en caso de error
      }
    }
  }

  Future<void> _checkConnectionWithRetry() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final success = await _networkService.checkConnectionWithRetry();

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          _showSnackBar('✅ Conexión verificada exitosamente', Colors.green);
          await _loadDiagnosticInfo();
        } else {
          _showSnackBar('❌ Falló verificación de conexión', Colors.red);
          await _loadDiagnosticInfo();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error verificando conexión: $e', Colors.red);
        await _loadDiagnosticInfo(); // ✅ Recargar incluso en caso de error
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'MADE TOMMY', // 🔥 AGREGADO: MADE TOMMY para contenido
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('📋 Copiado al portapapeles', Colors.blue);
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'connected':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Conectado';
        break;
      case 'disconnected':
        color = Colors.red;
        icon = Icons.error;
        label = 'Desconectado';
        break;
      case 'error':
        color = Colors.orange;
        icon = Icons.warning;
        label = 'Error';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        label = 'Desconocido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily:
                  'MADE TOMMY', // 🔥 CAMBIADO: Usar MADE TOMMY para contenido
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, Map<String, dynamic> data) {
    // 🔥 NUEVO: Filtrar datos antes de construir la tarjeta
    final filteredData = <String, dynamic>{};

    data.forEach((key, value) {
      final stringValue = value?.toString() ?? '';
      // Solo incluir valores que no estén vacíos, sean N/A o null
      if (stringValue.isNotEmpty &&
          stringValue != 'N/A' &&
          stringValue != 'null') {
        filteredData[key] = value;
      }
    });

    // Si no hay datos útiles, no mostrar la tarjeta
    if (filteredData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'LightHouse',
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ...filteredData.entries.map(
              (entry) => _buildInfoRow(entry.key, entry.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String key, dynamic value) {
    String displayValue = value?.toString() ?? '';

    // 🔥 NUEVO: No mostrar filas con valores vacíos, nulos o N/A
    if (displayValue.isEmpty ||
        displayValue == 'N/A' ||
        displayValue == 'null') {
      return const SizedBox.shrink();
    }

    bool isClickable =
        key.contains('url') ||
        key.contains('ip') ||
        key.contains('baseUrl') ||
        key.contains('URL') ||
        key.contains('IP');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              _formatKey(key),
              style: const TextStyle(
                fontFamily:
                    'MADE TOMMY', // 🔥 CAMBIADO: Usar MADE TOMMY para contenido
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isClickable ? () => _copyToClipboard(displayValue) : null,
              child: Container(
                padding:
                    isClickable
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                        : null,
                decoration:
                    isClickable
                        ? BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        )
                        : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayValue,
                        style: TextStyle(
                          fontFamily:
                              'MADE TOMMY', // 🔥 CAMBIADO: Siempre usar MADE TOMMY para contenido
                          fontSize: 13,
                          color: isClickable ? Colors.blue : Colors.black87,
                          fontWeight:
                              isClickable ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isClickable) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.blue.withOpacity(0.7),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : word,
        )
        .join(' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Diagnóstico de Red',
          style: TextStyle(
            fontFamily: 'LightHouse',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDiagnosticInfo,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.refresh),
            tooltip: 'Actualizar información',
          ),
        ],
      ),
      body:
          _isLoading && _diagnosticInfo == null
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Cargando información de red...',
                      style: TextStyle(
                        fontFamily: 'MADE TOMMY',
                        fontSize: 16,
                      ), // 🔥 CAMBIADO: MADE TOMMY para contenido
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado general
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.router,
                              size: 32,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estado de Conexión',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(
                                      fontFamily: 'LightHouse',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_serverStatus != null)
                                    _buildStatusIndicator(
                                      _serverStatus!['status'] ?? 'unknown',
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isRediscovering ? null : _forceRediscovery,
                            icon:
                                _isRediscovering
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.search),
                            label: Text(
                              _isRediscovering ? 'Buscando...' : 'Re-descubrir',
                              style: const TextStyle(
                                fontFamily:
                                    'MADE TOMMY', // 🔥 CAMBIADO: MADE TOMMY para contenido
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoading ? null : _refreshConfiguration,
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Refrescar',
                              style: TextStyle(
                                fontFamily:
                                    'MADE TOMMY', // 🔥 CAMBIADO: MADE TOMMY para contenido
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // NUEVOS BOTONES INTELIGENTES
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isSmartRecovering ? null : _smartRecovery,
                            icon:
                                _isSmartRecovering
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.psychology),
                            label: Text(
                              _isSmartRecovering
                                  ? 'Recuperando...'
                                  : 'Recuperación Inteligente',
                              style: const TextStyle(
                                fontFamily:
                                    'MADE TOMMY', // 🔥 CAMBIADO: MADE TOMMY para contenido
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoading ? null : _checkConnectionWithRetry,
                            icon: const Icon(Icons.network_check),
                            label: const Text(
                              'Verificar Conexión',
                              style: TextStyle(
                                fontFamily:
                                    'MADE TOMMY', // 🔥 CAMBIADO: MADE TOMMY para contenido
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Información de configuración
                    if (_diagnosticInfo != null)
                      _buildInfoCard('Configuración Actual', _diagnosticInfo!),

                    // Estado del servidor
                    if (_serverStatus != null)
                      _buildInfoCard('Estado del Servidor', _serverStatus!),

                    // 🔥 MEJORADO: Solo mostrar información adicional del servidor si tiene datos útiles
                    if (_networkService.serverInfo != null &&
                        _networkService.serverInfo!['server'] != null) ...[
                      const SizedBox(height: 8),
                      // Filtrar datos del servidor para mostrar solo información útil
                      Builder(
                        builder: (context) {
                          final serverData =
                              _networkService.serverInfo!['server']
                                  as Map<String, dynamic>? ??
                              {};
                          final filteredServerData = <String, dynamic>{};

                          // Solo agregar campos que tengan valores útiles
                          if (serverData['name'] != null)
                            filteredServerData['Name'] = serverData['name'];
                          if (serverData['version'] != null)
                            filteredServerData['Version'] =
                                serverData['version'];
                          if (serverData['type'] != null)
                            filteredServerData['Type'] = serverData['type'];
                          if (serverData['capabilities'] != null) {
                            final capabilities =
                                serverData['capabilities'] as List<dynamic>?;
                            if (capabilities != null &&
                                capabilities.isNotEmpty) {
                              filteredServerData['Capabilities'] = capabilities
                                  .join(', ');
                            }
                          }

                          // Solo mostrar la tarjeta si hay datos útiles
                          if (filteredServerData.isNotEmpty) {
                            return _buildInfoCard(
                              'Información del Servidor',
                              filteredServerData,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // Estado detallado solo si tiene información relevante
                      if (_networkService.serverInfo!['status'] != null)
                        Builder(
                          builder: (context) {
                            final statusData =
                                _networkService.serverInfo!['status']
                                    as Map<String, dynamic>? ??
                                {};
                            final filteredStatusData = <String, dynamic>{};

                            // Solo agregar campos que tengan valores útiles
                            if (statusData['online'] != null)
                              filteredStatusData['Online'] =
                                  statusData['online'].toString();
                            if (statusData['healthy'] != null)
                              filteredStatusData['Healthy'] =
                                  statusData['healthy'].toString();
                            if (statusData['uptime'] != null) {
                              final uptime = statusData['uptime'] as num?;
                              if (uptime != null) {
                                final hours = (uptime / 3600).floor();
                                final minutes = ((uptime % 3600) / 60).floor();
                                filteredStatusData['Uptime'] =
                                    '${hours}h ${minutes}m';
                              }
                            }
                            if (statusData['timestamp'] != null) {
                              try {
                                final timestamp = DateTime.parse(
                                  statusData['timestamp'],
                                );
                                filteredStatusData['Last Update'] =
                                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
                              } catch (e) {
                                // Si no se puede parsear, no mostrar
                              }
                            }

                            // Solo mostrar la tarjeta si hay datos útiles
                            if (filteredStatusData.isNotEmpty) {
                              return _buildInfoCard(
                                'Estado Detallado',
                                filteredStatusData,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                    ],

                    const SizedBox(height: 20),

                    // Ayuda
                    Card(
                      color: Colors.blue.withOpacity(0.05),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ayuda',
                                  style: TextStyle(
                                    fontFamily:
                                        'LightHouse', // 🔥 MANTENER: LightHouse para títulos
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Toca las direcciones IP o URLs para copiarlas\n'
                              '• "Re-descubrir" busca el servidor en toda la red\n'
                              '• "Refrescar" actualiza la configuración actual\n'
                              '• "Recuperación Inteligente" busca IP cambiadas automáticamente\n'
                              '• "Verificar Conexión" prueba con reintentos automáticos\n'
                              '• La configuración se guarda automáticamente',
                              style: TextStyle(
                                fontFamily:
                                    'MADE TOMMY', // 🔥 CAMBIADO: MADE TOMMY para contenido
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
