import 'package:flutter/material.dart';
import 'ChatScreen.dart';
import '../Widgets/background_scaffold.dart';
import '../Widgets/recommendations_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_services/table_identification_service.dart';

class ClientHomeScreen extends StatefulWidget {
  final String userName;
  final String userCedula;
  final Function(int)? onNavigate;

  const ClientHomeScreen({
    super.key,
    required this.userName,
    this.userCedula = '',
    this.onNavigate,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final TableIdentificationService _tableService = TableIdentificationService();

  // Estado para la información de la mesa
  TableInfo? _currentTable;
  bool _isLoadingTable = true;
  String? _deviceMac;

  @override
  void initState() {
    super.initState();
    _identifyTable();
  }

  /// Identificar la mesa del dispositivo actual
  Future<void> _identifyTable() async {
    try {
      setState(() {
        _isLoadingTable = true;
      });

      print('🔍 ClientHomeScreen: Iniciando identificación de mesa...');

      // 🆕 NUEVO: Obtener información completa del dispositivo para debugging
      final deviceInfo = await _tableService.getDeviceInfo();
      print('📱 ====== INFORMACIÓN COMPLETA DEL DISPOSITIVO ======');
      print('📱 Device ID: ${deviceInfo['deviceId']}');
      print('📱 Device Name: ${deviceInfo['deviceName']}');
      print('📱 MAC generada por la app: ${deviceInfo['macAddress']}');
      print('📱 Plataforma: ${deviceInfo['platform']}');
      print('📱 ===============================================');

      // Primero obtener la MAC del dispositivo para debugging
      final mac = await _tableService.getCurrentDeviceMac();

      // Intentar identificar la mesa
      final tableInfo = await _tableService.identifyTable();

      if (mounted) {
        setState(() {
          _currentTable = tableInfo;
          _deviceMac = mac;
          _isLoadingTable = false;
        });

        if (tableInfo != null) {
          print(
            '✅ ClientHomeScreen: Mesa identificada - Mesa ${tableInfo.tableNumber}',
          );
        } else {
          print(
            '⚠️ ClientHomeScreen: Dispositivo no registrado en ninguna mesa',
          );
          print('   - MAC del dispositivo: $mac');
          print('🔧 PARA AGREGAR ESTE DISPOSITIVO:');
          print('   Agregar esta MAC a connectedMacs: $mac');
        }
      }
    } catch (e) {
      print('❌ ClientHomeScreen: Error identificando mesa: $e');
      if (mounted) {
        setState(() {
          _isLoadingTable = false;
        });
      }
    }
  }

  Future<int?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_id');
    } catch (e) {
      print('Error al obtener ID del usuario: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackgroundScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con título del restaurante
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, top: 8.0),
                  child: Center(
                    child: Image.asset(
                      'assets/logos/logo_lebrunch.png',
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error al cargar logo: $error');
                        // Mostrar texto como fallback en caso de error
                        return Text(
                          'Le Brunch',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontFamily: 'LightHouse',
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 🆕 NUEVA: Tarjeta de información de mesa
                _buildTableInfoCard(context, theme),

                const SizedBox(height: 16),

                // Información del usuario (cédula si está disponible)
                if (widget.userCedula.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primary,
                          child: Icon(
                            Icons.person,
                            size: 24,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'CI: ${widget.userCedula}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Añadir tarjeta de Brunchy
                _buildBrunchyCard(context, theme),

                const SizedBox(height: 24),

                // Widget de recomendaciones personalizadas
                FutureBuilder<int?>(
                  future: _getCurrentUserId(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Column(
                        children: [
                          RecommendationsWidget(clientId: snapshot.data!),
                          const SizedBox(height: 24),
                        ],
                      );
                    } else {
                      // Si no hay usuario logueado, no mostrar recomendaciones
                      return const SizedBox(height: 8);
                    }
                  },
                ),

                // Resto del contenido...
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🆕 NUEVA: Construir tarjeta de información de mesa
  Widget _buildTableInfoCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 3,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.table_restaurant,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingTable)
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Identificando mesa...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: 'MADE TOMMY',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else if (_currentTable != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mesa ${_currentTable!.tableNumber}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: 'MADE TOMMY',
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mesa identificada',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                              fontFamily: 'MADE TOMMY',
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mesa no identificada',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: 'MADE TOMMY',
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dispositivo no registrado',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                              fontFamily: 'MADE TOMMY',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper para construir filas de información
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontFamily: 'LightHouse',
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'MADE TOMMY',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta para Brunchy
  Widget _buildBrunchyCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navegar a la pantalla de chat
          if (widget.onNavigate != null) {
            // El índice 2 corresponde a la pestaña de Chat en la barra de navegación del cliente
            widget.onNavigate!(2);
            print('🎯 Navegando a ChatScreen usando onNavigate con índice 2');
          } else {
            // Fallback: navegar directamente si no hay callback de navegación
            print('⚠️ onNavigate no disponible, usando navegación directa');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                radius: 24,
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola! Soy Brunchy',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'LightHouse',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentTable != null
                          ? 'Tu mesero virtual para la Mesa ${_currentTable!.tableNumber}'
                          : 'Tu mesero virtual para atenderte',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontFamily: 'MADE TOMMY',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Chatear',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
