import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../Widgets/custom_modal.dart';
import '../Widgets/background_scaffold.dart';
import '../../services/notification_service.dart';
import '../../theme/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/date_filter_bar.dart';
import '../../Api_services/pedidos/popular_dishes_service.dart';
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../Widgets/custom_modal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../services/notification_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final OrdersService _ordersService = OrdersService();
  final PopularDishesService _popularDishesService = PopularDishesService();
  final GlobalKey<DateFilterBarState> _filterBarKey =
      GlobalKey<DateFilterBarState>();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Estado para el filtro de categoría con enum para mejor tipo de datos
  String _selectedCategory = 'todos';

  // Constantes para las categorías
  static const Map<String, String> categoryLabels = {
    'todos': 'Todos los items',
    'comida': 'Solo comidas',
    'bebida': 'Solo bebidas',
  };

  String _currentPeriod = 'hoy';
  Map<String, dynamic> _summaryData = {};
  List<Map<String, dynamic>> _popularDishes = [];

  // Para filtrado personalizado
  String? _customStartDate;
  String? _customEndDate;

  @override
  void initState() {
    super.initState();
    _currentPeriod = 'hoy';
    _selectedCategory = 'todos';
    _loadReportData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      String? servicePeriod = _convertPeriodToServiceFormat(_currentPeriod);
      String? selectedCategory =
          _selectedCategory == 'todos' ? null : _selectedCategory;

      // Calcular fechas específicas según el período seleccionado
      String? startDateCalculated;
      String? endDateCalculated;

      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd');

      // Si es período personalizado, usar las fechas personalizadas
      if (_currentPeriod == 'personalizado') {
        startDateCalculated = _customStartDate;
        endDateCalculated = _customEndDate;
      } else {
        // Para otros períodos, calcular las fechas específicas
        switch (_currentPeriod) {
          case 'hoy':
            // Solo el día actual
            startDateCalculated = formatter.format(
              DateTime(now.year, now.month, now.day),
            );
            endDateCalculated = formatter.format(
              DateTime(now.year, now.month, now.day, 23, 59, 59),
            );
            break;
          case 'semana':
            // Desde el lunes de esta semana hasta hoy
            final firstDayOfWeek = now.subtract(
              Duration(days: now.weekday - 1),
            );
            startDateCalculated = formatter.format(
              DateTime(
                firstDayOfWeek.year,
                firstDayOfWeek.month,
                firstDayOfWeek.day,
              ),
            );
            endDateCalculated = formatter.format(now);
            break;
          case 'mes':
            // Desde el primer día del mes hasta hoy
            startDateCalculated = formatter.format(
              DateTime(now.year, now.month, 1),
            );
            endDateCalculated = formatter.format(now);
            break;
          case 'año':
            // Desde el primer día del año hasta hoy
            startDateCalculated = formatter.format(DateTime(now.year, 1, 1));
            endDateCalculated = formatter.format(now);
            break;
          case 'todos':
            // Sin restricción de fechas
            startDateCalculated = null;
            endDateCalculated = null;
            break;
        }
      }

      print(
        '🔍 Cargando reporte para período: $_currentPeriod (API: $servicePeriod)',
      );
      print('📅 Fechas calculadas: $startDateCalculated a $endDateCalculated');
      print('🏷️ Categoría: $selectedCategory');

      // Preparar datos iniciales
      Map<String, dynamic> summary = {
        'totalPedidos': 0,
        'totalVentas': 0.0,
        'ticketPromedio': 0.0,
      };
      List<Map<String, dynamic>> popularDishes = [];

      if (!mounted) return;

      // Obtener resumen de pedidos con fechas específicas
      final ordersSummary = await _ordersService.getOrdersSummary(
        period: servicePeriod,
        customStartDate: startDateCalculated,
        customEndDate: endDateCalculated,
        categoria: selectedCategory,
      );

      print('📊 Resumen de pedidos recibido: $ordersSummary');

      // Obtener platos populares con fechas específicas
      final dishes = await _popularDishesService.getPopularDishesDirect(
        period: servicePeriod,
        startDate: startDateCalculated,
        endDate: endDateCalculated,
        categoria: selectedCategory,
      );

      print('📊 Platos populares recibidos: ${dishes.length}');

      if (mounted) {
        setState(() {
          _summaryData = ordersSummary;
          _popularDishes = dishes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error al cargar datos del reporte: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error al cargar datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Función auxiliar para convertir el período al formato del servicio
  String _convertPeriodToServiceFormat(String period) {
    switch (period) {
      case 'hoy':
        return 'day';
      case 'semana':
        return 'week';
      case 'mes':
        return 'month';
      case 'año':
        return 'year';
      case 'personalizado':
        return 'custom';
      case 'todos':
        return 'all';
      default:
        return 'day';
    }
  }

  String _formatCurrency(dynamic amount) {
    // Convertir el valor a double de manera segura
    double value = 0.0;
    if (amount != null) {
      if (amount is int) {
        value = amount.toDouble();
      } else if (amount is double) {
        value = amount;
      } else if (amount is String) {
        value = double.tryParse(amount) ?? 0.0;
      }
    }
    final formatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
      locale: 'es_VE',
    );
    return formatter.format(value);
  }

  String _getReportTitle() {
    // Si el filtro es 'todos' o 'personalizado', mostrar solo 'Reporte'
    if (_currentPeriod == 'todos' || _currentPeriod == 'personalizado') {
      return 'Reporte';
    }
    switch (_currentPeriod) {
      case 'hoy':
        return 'Reporte del día';
      case 'semana':
        return 'Reporte semanal';
      case 'mes':
        return 'Reporte mensual';
      case 'año':
        return 'Reporte anual';
      default:
        return 'Reporte';
    }
  }

  void _navigateToOrderHistory() {
    String? startDate;
    String? endDate;
    String periodText;

    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');

    switch (_currentPeriod) {
      case 'hoy':
        // Solo el día actual
        startDate = formatter.format(DateTime(now.year, now.month, now.day));
        endDate = formatter.format(
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        periodText = 'Pedidos del día';
        break;
      case 'semana':
        // Desde el lunes de esta semana
        final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startDate = formatter.format(
          DateTime(
            firstDayOfWeek.year,
            firstDayOfWeek.month,
            firstDayOfWeek.day,
          ),
        );
        endDate = formatter.format(now);
        periodText = 'Pedidos de la semana';
        break;
      case 'mes':
        // Desde el primer día del mes
        startDate = formatter.format(DateTime(now.year, now.month, 1));
        endDate = formatter.format(now);
        periodText = 'Pedidos del mes';
        break;
      case 'año':
        // Desde el primer día del año
        startDate = formatter.format(DateTime(now.year, 1, 1));
        endDate = formatter.format(now);
        periodText = 'Pedidos del año';
        break;
      case 'personalizado':
        // Usar las fechas personalizadas
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate;
          endDate = _customEndDate;
          final displayFormatter = DateFormat('dd/MM/yyyy');
          final dateFormat = DateFormat('yyyy-MM-dd');
          final startDt = dateFormat.parse(_customStartDate!);
          final endDt = dateFormat.parse(_customEndDate!);
          periodText =
              'Pedidos del ${displayFormatter.format(startDt)} al ${displayFormatter.format(endDt)}';
        } else {
          periodText = 'Historial de pedidos';
        }
        break;
      default:
        periodText = 'Historial de pedidos';
    }

    // Navegar a OrderHistoryScreen con los argumentos necesarios
    Navigator.pushNamed(
      context,
      '/admin/order-history',
      arguments: {
        'title': periodText,
        'startDate': startDate,
        'endDate': endDate,
        'estado':
            'todos', // Mostrar todos los pedidos (completados y cancelados)
      },
    );
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid10OrHigher()) {
        // Para Android 10 y superior, necesitamos MANAGE_EXTERNAL_STORAGE
        if (!await Permission.manageExternalStorage.isGranted) {
          bool shouldRequest = await CustomModal.showConfirmation(
            context: context,
            title: 'Permisos de almacenamiento',
            message:
                'Para guardar el reporte, necesitamos acceso al almacenamiento. Se abrirá configuración donde deberás activar "Permitir administrar archivos".',
            confirmText: 'Ir a Configuración',
            cancelText: 'Cancelar',
          );

          if (shouldRequest) {
            await Permission.manageExternalStorage.request();
            if (!await Permission.manageExternalStorage.isGranted) {
              await openAppSettings();
            }
          }
          return await Permission.manageExternalStorage.isGranted;
        }
        return true;
      } else {
        // Para Android 9 y anterior
        var status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // Para iOS u otras plataformas
  }

  Future<bool> _isAndroid10OrHigher() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfoPlugin = DeviceInfoPlugin();
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return androidInfo.version.sdkInt >= 29;
      } catch (e) {
        print('Error al obtener información del dispositivo: $e');
        // Si hay un error al obtener la información, asumimos que es una versión anterior
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackgroundScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getReportTitle(),
                    style: TextStyle(
                      fontFamily: 'Lighthouse',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    categoryLabels[_selectedCategory] ?? 'Todos los items',
                    style: TextStyle(
                      fontFamily: 'Lighthouse',
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            // Filtro de categoría a la derecha
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: theme.primaryColor,
                icon: const Icon(Icons.filter_list, color: Colors.white),
                focusColor: Colors.transparent,
                elevation: 1,
                items:
                    categoryLabels.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              entry.key == 'todos'
                                  ? Icons.restaurant_menu
                                  : entry.key == 'comida'
                                  ? Icons.lunch_dining
                                  : Icons.local_drink,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontFamily: 'Lighthouse',
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _selectedCategory) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                    _loadReportData();
                  }
                },
                style: const TextStyle(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFF3ea69b),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 70.0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF3ea69b),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            image: DecorationImage(
              image: AssetImage('assets/images/fondo-flores-2.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          DateFilterBar(
            key: _filterBarKey,
            initialFilter: _currentPeriod,
            onFilterChanged: (String period) {
              setState(() {
                _currentPeriod = period;
                if (period != 'personalizado') {
                  _customStartDate = null;
                  _customEndDate = null;
                }
              });
              _loadReportData();
            },
            onCustomDateRangeSelected: (String startDate, String endDate) {
              setState(() {
                _currentPeriod = 'personalizado';
                _customStartDate = startDate;
                _customEndDate = endDate;
              });
              _loadReportData();
            },
            showFilterLabel: true,
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar los datos',
                            style: TextStyle(
                              fontFamily: 'Lighthouse',
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Lighthouse',
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadReportData,
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Reintentar',
                              style: TextStyle(fontFamily: 'Lighthouse'),
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadReportData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatisticsCards(theme),
                              const SizedBox(height: 16),
                              _buildDistributionSection(theme),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _navigateToOrderHistory,
                                icon: const Icon(Icons.history),
                                label: const Text('Ver historial de pedidos'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _generateAndDownloadPDF,
                                icon: const Icon(Icons.download),
                                label: const Text('Descargar reporte'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // BOTÓN TEMPORAL DE PRUEBA - ELIMINAR DESPUÉS
                              ElevatedButton.icon(
                                onPressed: _testNotification,
                                icon: const Icon(Icons.notifications),
                                label: const Text('🧪 Probar notificación'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(ThemeData theme) {
    final totalPedidos = _summaryData['totalPedidos'] ?? 0;
    final totalVentas = _summaryData['totalVentas'] ?? 0.0;
    final ticketPromedio = _summaryData['ticketPromedio'] ?? 0.0;

    // Asegurar que los valores son números válidos
    final totalPedidosInt =
        totalPedidos is int
            ? totalPedidos
            : int.tryParse(totalPedidos.toString()) ?? 0;

    // Forzar la conversión a double para evitar errores de tipo
    final totalVentasDouble =
        totalVentas is double
            ? totalVentas
            : double.tryParse(totalVentas.toString()) ?? 0.0;
    final ticketPromedioDouble =
        ticketPromedio is double
            ? ticketPromedio
            : double.tryParse(ticketPromedio.toString()) ?? 0.0;

    print(
      '💰 Valores para tarjetas: Pedidos=$totalPedidosInt, Ventas=$totalVentasDouble, Ticket=$ticketPromedioDouble',
    );

    // Si no hay pedidos, mostrar un mensaje
    if (totalPedidosInt == 0) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No hay pedidos en este período',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona otro período o inténtalo más tarde',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Total de pedidos',
                '$totalPedidosInt',
                Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Ventas totales',
                _formatCurrency(totalVentasDouble),
                Icons.attach_money,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Ticket promedio',
                _formatCurrency(ticketPromedioDouble),
                Icons.point_of_sale,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMinMaxCard(
                theme,
                (_summaryData['minPedido'] as num?)?.toDouble() ?? 0.0,
                (_summaryData['maxPedido'] as num?)?.toDouble() ?? 0.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon, {
    bool isWide = false,
  }) {
    return SizedBox(
      height: 100,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment:
                isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment:
                    isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontFamily: 'MADE TOMMY', // Usar MADE TOMMY para números
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinMaxCard(ThemeData theme, double minValue, double maxValue) {
    return SizedBox(
      height: 100,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Min/Max',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('Min', style: theme.textTheme.bodySmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatCurrency(minValue),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontFamily: 'MADE TOMMY',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(height: 30, width: 1, color: theme.dividerColor),
                  Column(
                    children: [
                      Text('Max', style: theme.textTheme.bodySmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatCurrency(maxValue),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontFamily: 'MADE TOMMY',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionSection(ThemeData theme) {
    // Verificar que haya datos de pedidos
    final hayPedidos = (_summaryData['totalPedidos'] ?? 0) > 0;

    return Column(
      children: [
        // Gráfico de platos populares existente
        if (hayPedidos) _buildPopularDishesChart(theme),

        // Nuevos gráficos
        if (hayPedidos) ...[
          const SizedBox(height: 16),
          _buildSalesByHourChart(theme),
          const SizedBox(height: 16),
          _buildCategorySalesChart(theme),
          const SizedBox(height: 16),
          _buildAverageTicketByDayChart(theme),
        ],
      ],
    );
  }

  // Método para construir el gráfico de platos populares
  Widget _buildPopularDishesChart(ThemeData theme) {
    // Si no hay platos populares pero hay pedidos, mostrar mensaje
    if (_popularDishes.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Platos más vendidos',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Text(
                        'No hay datos sobre platos vendidos en este período',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          _filterBarKey.currentState?.updateFilter('todos');
                          setState(() {
                            _currentPeriod = 'todos';
                          });
                          _loadReportData();
                        },
                        icon: const Icon(Icons.all_inclusive),
                        label: const Text('Ver todos los datos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
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

    // Calcular el total de ventas para porcentajes
    int totalVentas = 0;
    for (var dish in _popularDishes) {
      // Manejar diferentes tipos de datos para cantidad_vendida
      var cantidadVendida = dish['cantidad_vendida'];
      if (cantidadVendida is int) {
        totalVentas += cantidadVendida;
      } else if (cantidadVendida is double) {
        totalVentas += cantidadVendida.toInt();
      } else if (cantidadVendida is String) {
        totalVentas += int.tryParse(cantidadVendida) ?? 0;
      }
    }

    // Si no hay ventas registradas, mostrar gráfico con proporciones iguales
    if (totalVentas == 0) {
      // Asignar un valor igual a cada plato para la visualización
      final double porcentajeIgual = 1.0 / _popularDishes.length;

      // Colores para el gráfico
      final List<Color> chartColors = [
        const Color(0xFF3ea69b), // Verde principal
        const Color(0xFFf0c869), // Amarillo
        const Color(0xFFff7a6a), // Salmón
        const Color(0xFF5d80be), // Azul
        const Color(0xFFb56db4), // Morado
      ];

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Platos disponibles',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gráfico circular
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    // Gráfico
                    Expanded(
                      flex: 3,
                      child: CustomPaint(
                        size: const Size(180, 180),
                        painter: PieChartPainter(
                          List.generate(
                            _popularDishes.length,
                            (_) => porcentajeIgual,
                          ),
                          chartColors,
                        ),
                      ),
                    ),

                    // Leyenda
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          math.min(_popularDishes.length, 5),
                          (index) {
                            final dish = _popularDishes[index];

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    color:
                                        chartColors[index % chartColors.length],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${dish['nombre']}",
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  _currentPeriod == 'todos'
                      ? "Mostrando todos los platos disponibles"
                      : "Los platos listados no registran ventas en este período",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón para ver todos los platos populares
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/popular-dishes');
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Ver todos los platos'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    if (_currentPeriod != 'todos')
                      TextButton.icon(
                        onPressed: () {
                          _filterBarKey.currentState?.updateFilter('todos');
                          setState(() {
                            _currentPeriod = 'todos';
                          });
                          _loadReportData();
                        },
                        icon: const Icon(Icons.all_inclusive),
                        label: const Text('Ver todos los datos'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Colores para el gráfico cuando hay ventas
    final List<Color> chartColors = [
      const Color(0xFF3ea69b), // Verde principal
      const Color(0xFFf0c869), // Amarillo
      const Color(0xFFff7a6a), // Salmón
      const Color(0xFF5d80be), // Azul
      const Color(0xFFb56db4), // Morado
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Platos más vendidos', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),

            // Gráfico circular
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Gráfico
                  Expanded(
                    flex: 3,
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: PieChartPainter(
                        _popularDishes.map((dish) {
                          var cantidadVendida = dish['cantidad_vendida'];
                          int cantidad = 0;
                          if (cantidadVendida is int) {
                            cantidad = cantidadVendida;
                          } else if (cantidadVendida is double) {
                            cantidad = cantidadVendida.toInt();
                          } else if (cantidadVendida is String) {
                            cantidad = int.tryParse(cantidadVendida) ?? 0;
                          }
                          return cantidad / totalVentas;
                        }).toList(),
                        chartColors,
                      ),
                    ),
                  ),

                  // Leyenda
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        math.min(_popularDishes.length, 5),
                        (index) {
                          final dish = _popularDishes[index];
                          var cantidadVendida = dish['cantidad_vendida'];
                          int cantidad = 0;
                          if (cantidadVendida is int) {
                            cantidad = cantidadVendida;
                          } else if (cantidadVendida is double) {
                            cantidad = cantidadVendida.toInt();
                          } else if (cantidadVendida is String) {
                            cantidad = int.tryParse(cantidadVendida) ?? 0;
                          }
                          final percent = (cantidad / totalVentas * 100)
                              .toStringAsFixed(1);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color:
                                      chartColors[index % chartColors.length],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${dish['nombre']}",
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$percent%",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Lista detallada
            ...List.generate(math.min(_popularDishes.length, 5), (index) {
              final dish = _popularDishes[index];
              var cantidadVendida = dish['cantidad_vendida'];
              int ventas = 0;
              if (cantidadVendida is int) {
                ventas = cantidadVendida;
              } else if (cantidadVendida is double) {
                ventas = cantidadVendida.toInt();
              } else if (cantidadVendida is String) {
                ventas = int.tryParse(cantidadVendida) ?? 0;
              }
              final percent = (ventas / totalVentas * 100).toStringAsFixed(1);
              final color = chartColors[index % chartColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "${index + 1}. ${dish['nombre']}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "$ventas unid. ($percent%)",
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Barra de progreso
                    LinearProgressIndicator(
                      value: ventas / totalVentas,
                      backgroundColor: color.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Botón para ver todos los platos populares
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/popular-dishes');
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ver todos los platos populares'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesByHourChart(ThemeData theme) {
    final ventasPorHora = _summaryData['ventasPorHora'] as List<dynamic>? ?? [];

    // Convertir los datos a spots para el gráfico
    final spots =
        ventasPorHora.map((venta) {
          // Convertir hora de manera segura
          final horaValue = venta['hora'];
          final hora =
              horaValue is int ? horaValue : int.parse(horaValue.toString());

          // Convertir total_ventas de manera segura
          final ventasValue = venta['total_ventas'];
          final totalVentas =
              ventasValue is num
                  ? ventasValue.toDouble()
                  : double.parse(ventasValue.toString());

          return FlSpot(hora.toDouble(), totalVentas);
        }).toList();

    // Encontrar el valor máximo para el eje Y
    final maxY =
        spots.isEmpty
            ? 100.0
            : spots.map((spot) => spot.y).reduce(math.max) * 1.2;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Ventas por hora', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child:
                  spots.isEmpty
                      ? const Center(child: Text('No hay datos para mostrar'))
                      : LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${value.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}h',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                                interval: 4,
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: theme.colorScheme.primary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                              ),
                            ),
                          ],
                          minX: 0,
                          maxX: 23,
                          minY: 0,
                          maxY: maxY,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySalesChart(ThemeData theme) {
    final ventasPorCategoria =
        _summaryData['ventasPorCategoria'] as List<dynamic>? ?? [];

    // Convertir los datos para el gráfico de manera segura
    final barGroups =
        ventasPorCategoria.asMap().entries.map((entry) {
          final venta = entry.value;
          try {
            final totalVentas = double.parse(venta['total_ventas'].toString());
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: totalVentas,
                  color: theme.colorScheme.primary,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          } catch (e) {
            print('Error procesando venta: $venta');
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: 0,
                  color: theme.colorScheme.primary,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }
        }).toList();

    // Encontrar el valor máximo para el eje Y de manera segura
    final maxY =
        ventasPorCategoria.isEmpty
            ? 100.0
            : (ventasPorCategoria
                    .map((venta) {
                      try {
                        return double.parse(venta['total_ventas'].toString());
                      } catch (e) {
                        return 0.0;
                      }
                    })
                    .reduce((a, b) => math.max(a, b)) *
                1.2);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ventas por categoría',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300, // Aumentamos la altura para dar más espacio
              child:
                  ventasPorCategoria.isEmpty
                      ? const Center(child: Text('No hay datos para mostrar'))
                      : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.blueGrey,
                              getTooltipItem: (
                                group,
                                groupIndex,
                                rod,
                                rodIndex,
                              ) {
                                return BarTooltipItem(
                                  '\$${rod.toY.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${value.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() <
                                          ventasPorCategoria.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 55.0,
                                      ),
                                      child: Transform.rotate(
                                        angle: -math.pi / 4,
                                        child: SizedBox(
                                          width: 100,
                                          child: Text(
                                            ventasPorCategoria[value
                                                    .toInt()]['categoria']
                                                as String,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          barGroups: barGroups,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageTicketByDayChart(ThemeData theme) {
    final ticketPromedioPorDia =
        _summaryData['ticketPromedioPorDia'] as List<dynamic>? ?? [];

    print('📊 Datos de ticket promedio por día: $ticketPromedioPorDia');

    // Convertir los datos para el gráfico
    final barGroups = List.generate(7, (index) {
      try {
        final diaData = ticketPromedioPorDia.firstWhere((dia) {
          try {
            final diaSemanaValue = dia['dia_semana'];
            print(
              '🔍 Valor de día semana para índice $index: $diaSemanaValue (tipo: ${diaSemanaValue.runtimeType})',
            );

            int diaSemana;
            if (diaSemanaValue is int) {
              diaSemana = diaSemanaValue;
            } else if (diaSemanaValue is String) {
              diaSemana = int.parse(diaSemanaValue);
            } else {
              print(
                '⚠️ Tipo de dato no esperado para dia_semana: ${diaSemanaValue.runtimeType}',
              );
              return false;
            }

            return diaSemana == index;
          } catch (e) {
            print('❌ Error procesando día de la semana: $e');
            return false;
          }
        }, orElse: () => {'ticket_promedio': '0.0'});

        print('📊 Datos encontrados para día $index: $diaData');

        double ticketPromedio;
        try {
          final rawTicket = diaData['ticket_promedio'];
          if (rawTicket is num) {
            ticketPromedio = rawTicket.toDouble();
          } else {
            ticketPromedio = double.parse(rawTicket.toString());
          }
        } catch (e) {
          print('❌ Error convirtiendo ticket promedio: $e');
          ticketPromedio = 0.0;
        }

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: ticketPromedio,
              color: theme.colorScheme.primary,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      } catch (e) {
        print('❌ Error general procesando día $index: $e');
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: 0,
              color: theme.colorScheme.primary,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }
    });

    // Encontrar el valor máximo para el eje Y de manera segura
    double maxY;
    try {
      if (ticketPromedioPorDia.isEmpty) {
        maxY = 50.0;
      } else {
        final valores =
            ticketPromedioPorDia.map((dia) {
              try {
                final rawTicket = dia['ticket_promedio'];
                if (rawTicket is num) {
                  return rawTicket.toDouble();
                } else {
                  return double.parse(rawTicket.toString());
                }
              } catch (e) {
                print('❌ Error convirtiendo valor para maxY: $e');
                return 0.0;
              }
            }).toList();
        maxY = valores.reduce(math.max) * 1.2;
      }
    } catch (e) {
      print('❌ Error calculando maxY: $e');
      maxY = 50.0;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ticket promedio por día',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child:
                  ticketPromedioPorDia.isEmpty
                      ? const Center(child: Text('No hay datos para mostrar'))
                      : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.center,
                          maxY: maxY,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${value.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const dias = [
                                    'Lun',
                                    'Mar',
                                    'Mié',
                                    'Jue',
                                    'Vie',
                                    'Sáb',
                                    'Dom',
                                  ];
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < dias.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        dias[value.toInt()],
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          barGroups: barGroups,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndDownloadPDF() async {
    const int progressNotificationId = 12345;

    try {
      bool hasPermission = await _requestStoragePermission();

      if (!hasPermission) {
        if (!mounted) return;
        await CustomModal.showError(
          context: context,
          title: 'Permiso denegado',
          message:
              'No se puede descargar el reporte sin los permisos necesarios.',
        );
        return;
      }

      // Mostrar notificación de progreso inicial
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Generando reporte PDF',
        message: 'Preparando documento...',
        progress: 0,
        maxProgress: 100,
      );

      // Mostrar modal de progreso
      if (!mounted) return;
      bool showingProgress = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Generando reporte',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Por favor espera mientras generamos tu reporte...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Actualizar progreso: preparación
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Generando reporte PDF',
        message: 'Recopilando datos...',
        progress: 20,
        maxProgress: 100,
      );

      // Crear el documento PDF
      final pdf = pw.Document();

      // Obtener el título del reporte según los filtros
      String reportTitle = _getReportTitle();
      String categoryFilter =
          categoryLabels[_selectedCategory] ?? 'Todos los items';
      String dateRange = '';

      switch (_currentPeriod) {
        case 'hoy':
          dateRange = DateFormat('dd/MM/yyyy').format(DateTime.now());
          break;
        case 'semana':
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          dateRange =
              '${DateFormat('dd/MM/yyyy').format(startOfWeek)} - ${DateFormat('dd/MM/yyyy').format(now)}';
          break;
        case 'mes':
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          dateRange =
              '${DateFormat('dd/MM/yyyy').format(startOfMonth)} - ${DateFormat('dd/MM/yyyy').format(now)}';
          break;
        case 'año':
          final now = DateTime.now();
          final startOfYear = DateTime(now.year, 1, 1);
          dateRange =
              '${DateFormat('dd/MM/yyyy').format(startOfYear)} - ${DateFormat('dd/MM/yyyy').format(now)}';
          break;
        case 'personalizado':
          if (_customStartDate != null && _customEndDate != null) {
            final startDate = DateFormat('yyyy-MM-dd').parse(_customStartDate!);
            final endDate = DateFormat('yyyy-MM-dd').parse(_customEndDate!);
            dateRange =
                '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}';
          }
          break;
      }

      // Actualizar progreso: creando contenido
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Generando reporte PDF',
        message: 'Creando contenido del documento...',
        progress: 50,
        maxProgress: 100,
      );

      // Asegurar que los valores numéricos sean válidos
      final totalPedidos = _summaryData['totalPedidos']?.toString() ?? '0';
      final totalVentas = _summaryData['totalVentas'] ?? 0.0;
      final ticketPromedio = _summaryData['ticketPromedio'] ?? 0.0;
      final minTicket = _summaryData['minPedido'] ?? 0.0;
      final maxTicket = _summaryData['maxPedido'] ?? 0.0;
      final ventasPorHora =
          _summaryData['ventasPorHora'] as List<dynamic>? ?? [];
      final ventasPorCategoria =
          _summaryData['ventasPorCategoria'] as List<dynamic>? ?? [];
      final ticketPromedioPorDia =
          _summaryData['ticketPromedioPorDia'] as List<dynamic>? ?? [];

      // Cargar el logo desde assets
      final logoData = await rootBundle.load('assets/logos/image006.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // Agregar contenido al PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Encabezado con logo
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex(
                        '#3EA69B',
                      ), // Color primary del theme
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo
                        pw.Container(
                          width: 80,
                          height: 80,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 20),
                        // Información del reporte
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Reporte de Ventas',
                                style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                categoryFilter,
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  color: PdfColors.white,
                                ),
                              ),
                              if (dateRange.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  dateRange,
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 25),

                  // Información del período y filtros (ahora más compacta)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#94C7C0'),
                      ), // Secondary color del theme
                      borderRadius: pw.BorderRadius.circular(8),
                      color: PdfColor.fromHex(
                        '#F8FFFE',
                      ), // Muy claro basado en el primary
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Período: $_currentPeriod',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex(
                              '#2D8A80',
                            ), // primaryContainer del theme
                          ),
                        ),
                        pw.Text(
                          'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColor.fromHex(
                              '#444444',
                            ), // onSurface del theme
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 25),

                  // Resumen de ventas
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex(
                        '#F8FFFE',
                      ), // Color muy claro basado en el primary
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#94C7C0'),
                      ), // Secondary color
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Resumen de ventas',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex(
                              '#2D8A80',
                            ), // primaryContainer del theme
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        _buildSummaryRow('Total de pedidos', totalPedidos),
                        _buildSummaryRow(
                          'Total de ventas',
                          _formatCurrency(totalVentas),
                        ),
                        _buildSummaryRow(
                          'Ticket promedio',
                          _formatCurrency(ticketPromedio),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Divider(
                          color: PdfColor.fromHex('#94C7C0'),
                        ), // Secondary color
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Rango de tickets',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex(
                              '#2D8A80',
                            ), // primaryContainer del theme
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        _buildSummaryRow(
                          'Ticket mínimo',
                          _formatCurrency(minTicket),
                        ),
                        _buildSummaryRow(
                          'Ticket máximo',
                          _formatCurrency(maxTicket),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Platos más vendidos
                  if (_popularDishes.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex(
                          '#F8FFFE',
                        ), // Color muy claro basado en el primary
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#94C7C0'),
                        ), // Secondary color
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Platos más vendidos',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex(
                                '#2D8A80',
                              ), // primaryContainer del theme
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          ..._popularDishes.map((dish) {
                            final nombre = dish['nombre'] as String;
                            final cantidadVendida =
                                int.tryParse(
                                  dish['cantidad_vendida'].toString(),
                                ) ??
                                0;
                            final porcentaje = ((cantidadVendida /
                                        (int.tryParse(totalPedidos) ?? 1)) *
                                    100)
                                .toStringAsFixed(1);

                            return pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      nombre,
                                      style: pw.TextStyle(
                                        color: PdfColor.fromHex(
                                          '#444444',
                                        ), // onSurface del theme
                                      ),
                                    ),
                                    pw.Text(
                                      '$cantidadVendida und. ($porcentaje%)',
                                      style: pw.TextStyle(
                                        color: PdfColor.fromHex(
                                          '#2D8A80',
                                        ), // primaryContainer del theme
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 5),
                                pw.Container(
                                  height: 10,
                                  child: pw.Stack(
                                    children: [
                                      pw.Container(
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor.fromHex(
                                            '#C2C8BC',
                                          ), // outline del theme como fondo
                                          borderRadius: pw
                                              .BorderRadius.circular(5),
                                        ),
                                      ),
                                      pw.Container(
                                        width:
                                            400 *
                                            (cantidadVendida /
                                                (int.tryParse(totalPedidos) ??
                                                    1)),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor.fromHex(
                                            '#3EA69B',
                                          ), // primary del theme
                                          borderRadius: pw
                                              .BorderRadius.circular(5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 10),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 20),

                  // Gráficos
                  if (ventasPorHora.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex(
                          '#F8FFFE',
                        ), // Color muy claro basado en el primary
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#94C7C0'),
                        ), // Secondary color
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Ventas por hora',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex(
                                '#2D8A80',
                              ), // primaryContainer del theme
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _buildVentasPorHoraChart(ventasPorHora),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 20),

                  if (ventasPorCategoria.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex(
                          '#F8FFFE',
                        ), // Color muy claro basado en el primary
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#94C7C0'),
                        ), // Secondary color
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Ventas por categoría',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex(
                                '#2D8A80',
                              ), // primaryContainer del theme
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _buildVentasPorCategoriaChart(ventasPorCategoria),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 20),

                  if (ticketPromedioPorDia.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex(
                          '#F8FFFE',
                        ), // Color muy claro basado en el primary
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#94C7C0'),
                        ), // Secondary color
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Ticket promedio por día',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex(
                                '#2D8A80',
                              ), // primaryContainer del theme
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _buildTicketPromedioPorDiaChart(ticketPromedioPorDia),
                        ],
                      ),
                    ),
                ],
              ),
            ];
          },
        ),
      );

      // Actualizar progreso: guardando archivo
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Generando reporte PDF',
        message: 'Guardando archivo...',
        progress: 80,
        maxProgress: 100,
      );

      // Obtener el directorio de descargas
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception('No se pudo acceder al directorio de almacenamiento');
      }

      // Generar nombre de archivo único
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'reporte_lebrunch_$timestamp.pdf';
      final file = File('${dir.path}/$fileName');

      // Guardar el archivo
      await file.writeAsBytes(await pdf.save());

      // Completar progreso
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Generando reporte PDF',
        message: 'Completado!',
        progress: 100,
        maxProgress: 100,
      );

      // Esperar un momento antes de cancelar la notificación de progreso
      await Future.delayed(const Duration(milliseconds: 500));
      await NotificationService.cancelNotification(progressNotificationId);

      // Mostrar notificación de descarga completa
      await NotificationService.showPdfDownloadedNotification(
        fileName: fileName,
        filePath: file.path,
      );

      if (!mounted) return;
      // Cerrar el modal de progreso si está abierto
      if (showingProgress && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Mostrar modal de éxito con información sobre la notificación
      await CustomModal.showSuccess(
        context: context,
        title: '¡Reporte generado!',
        message:
            'El reporte se ha guardado exitosamente.\n\nPuedes encontrarlo en tus notificaciones o en:\n${file.path}',
        buttonText: 'Entendido',
      );
    } catch (e) {
      // Cancelar notificación de progreso en caso de error
      await NotificationService.cancelNotification(progressNotificationId);

      if (!mounted) return;
      // Cerrar el modal de progreso si está abierto
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Mostrar modal de error
      await CustomModal.showError(
        context: context,
        title: 'Error',
        message: 'Ocurrió un error al generar el reporte: ${e.toString()}',
      );
    }
  }

  // Función auxiliar para construir filas de resumen en el PDF
  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#444444'), // onSurface del theme
            ),
          ),
          pw.Spacer(),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#2D8A80'), // primaryContainer del theme
            ),
          ),
        ],
      ),
    );
  }

  // Función para construir el gráfico de ventas por hora
  pw.Widget _buildVentasPorHoraChart(List<dynamic> data) {
    try {
      // Convertir datos de manera segura
      final processedData =
          data.map((item) {
            double totalVentas = 0.0;
            int hora = 0;
            try {
              if (item['total_ventas'] is num) {
                totalVentas = (item['total_ventas'] as num).toDouble();
              } else {
                totalVentas =
                    double.tryParse(item['total_ventas'].toString()) ?? 0.0;
              }
              hora = int.tryParse(item['hora'].toString()) ?? 0;
            } catch (e) {
              print('Error procesando total_ventas: $e');
            }
            return {'total_ventas': totalVentas, 'hora': hora};
          }).toList();

      // Encontrar el valor máximo para escalar el gráfico
      double maxValue = processedData.fold(
        0.0,
        (max, item) => math.max(max, (item['total_ventas'] as double? ?? 0.0)),
      );

      return pw.Container(
        height: 200,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children:
              processedData.map((item) {
                final height =
                    ((item['total_ventas'] as double? ?? 0.0) /
                        (maxValue > 0 ? maxValue : 1)) *
                    150;
                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        height: height,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex(
                            '#3EA69B',
                          ), // primary del theme
                          borderRadius: pw.BorderRadius.vertical(
                            top: pw.Radius.circular(4),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${item['hora']}h',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex(
                            '#444444',
                          ), // onSurface del theme
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    } catch (e) {
      print('Error generando gráfico de ventas por hora: $e');
      return pw.Container();
    }
  }

  // Función para construir el gráfico de ventas por categoría
  pw.Widget _buildVentasPorCategoriaChart(List<dynamic> data) {
    try {
      // Convertir datos de manera segura
      final processedData =
          data.map((item) {
            double totalVentas = 0.0;
            String categoria = '';
            try {
              if (item['total_ventas'] is num) {
                totalVentas = (item['total_ventas'] as num).toDouble();
              } else {
                totalVentas =
                    double.tryParse(item['total_ventas'].toString()) ?? 0.0;
              }
              categoria = item['categoria']?.toString() ?? '';
            } catch (e) {
              print('Error procesando datos de categoría: $e');
            }
            return {'categoria': categoria, 'total_ventas': totalVentas};
          }).toList();

      // Encontrar el valor máximo para escalar el gráfico
      double maxValue = processedData.fold(
        0.0,
        (max, item) => math.max(max, (item['total_ventas'] as double? ?? 0.0)),
      );

      return pw.Container(
        height: 200,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children:
              processedData.map((item) {
                final height =
                    ((item['total_ventas'] as double? ?? 0.0) /
                        (maxValue > 0 ? maxValue : 1)) *
                    150;
                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        height: height,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex(
                            '#94C7C0',
                          ), // secondary del theme
                          borderRadius: pw.BorderRadius.vertical(
                            top: pw.Radius.circular(4),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        item['categoria']?.toString() ?? '',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex(
                            '#444444',
                          ), // onSurface del theme
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(item['total_ventas'] as double? ?? 0.0),
                        style: pw.TextStyle(
                          fontSize: 6,
                          color: PdfColor.fromHex(
                            '#2D8A80',
                          ), // primaryContainer del theme
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    } catch (e) {
      print('Error generando gráfico de ventas por categoría: $e');
      return pw.Container();
    }
  }

  // Función para construir el gráfico de ticket promedio por día
  pw.Widget _buildTicketPromedioPorDiaChart(List<dynamic> data) {
    try {
      final diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

      // Convertir datos de manera segura
      final processedData =
          data.map((item) {
            double ticketPromedio = 0.0;
            try {
              if (item['ticket_promedio'] is num) {
                ticketPromedio = (item['ticket_promedio'] as num).toDouble();
              } else {
                ticketPromedio =
                    double.tryParse(item['ticket_promedio'].toString()) ?? 0.0;
              }
            } catch (e) {
              print('Error procesando ticket_promedio: $e');
            }
            return {'ticket_promedio': ticketPromedio};
          }).toList();

      // Encontrar el valor máximo para escalar el gráfico
      double maxValue = processedData.fold(
        0.0,
        (max, item) =>
            math.max(max, (item['ticket_promedio'] as double? ?? 0.0)),
      );

      return pw.Container(
        height: 200,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children:
              processedData.map((item) {
                final height =
                    ((item['ticket_promedio'] as double? ?? 0.0) /
                        (maxValue > 0 ? maxValue : 1)) *
                    150;
                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        height: height,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex(
                            '#2D8A80',
                          ), // primaryContainer del theme
                          borderRadius: pw.BorderRadius.vertical(
                            top: pw.Radius.circular(4),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        diasSemana[processedData.indexOf(item)],
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex(
                            '#444444',
                          ), // onSurface del theme
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(
                          item['ticket_promedio'] as double? ?? 0.0,
                        ),
                        style: pw.TextStyle(
                          fontSize: 6,
                          color: PdfColor.fromHex(
                            '#2D8A80',
                          ), // primaryContainer del theme
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    } catch (e) {
      print('Error generando gráfico de ticket promedio por día: $e');
      return pw.Container();
    }
  }

  // Función temporal de prueba para notificaciones - ELIMINAR DESPUÉS
  Future<void> _testNotification() async {
    try {
      await NotificationService.showTestNotification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Notificación de prueba enviada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al enviar notificación de prueba: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Clase para dibujar el gráfico de pastel
class PieChartPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;

  PieChartPainter(this.percentages, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Dibujar círculo de fondo
    final backgroundPaint =
        Paint()
          ..color = Colors.grey.shade200
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Variables para el cálculo de arcos
    double startAngle = -math.pi / 2; // Empezar desde arriba

    // Dibujar cada segmento del pastel
    for (int i = 0; i < percentages.length; i++) {
      final sweepAngle = percentages[i] * 2 * math.pi;
      final paint =
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Dibujar círculo central (agujero)
    final circlePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
