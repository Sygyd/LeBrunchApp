import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/date_filter_bar.dart';
import '../../Api_services/pedidos/popular_dishes_service.dart';
import 'dart:math' as math;

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

  String _currentPeriod =
      'hoy'; // Usando el formato de DateFilterBar: 'hoy', 'semana', 'mes', 'año', 'personalizado'
  Map<String, dynamic> _summaryData = {};
  List<Map<String, dynamic>> _popularDishes = [];

  // Para filtrado personalizado
  String? _customStartDate;
  String? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Convertir el formato de periodo de DateFilterBar al formato de OrdersService
      String? servicePeriod;
      switch (_currentPeriod) {
        case 'hoy':
          servicePeriod = 'day';
          break;
        case 'semana':
          servicePeriod = 'week';
          break;
        case 'mes':
          servicePeriod = 'month';
          break;
        case 'año':
          servicePeriod = 'year';
          break;
        case 'personalizado':
          servicePeriod = 'custom';
          break;
        case 'todos':
          servicePeriod = 'all'; // Para 'todos', usamos 'all' en lugar de null
          break;
        default:
          servicePeriod = 'day'; // Por defecto, usar día
      }

      print(
        '🔍 Cargando reporte para período: $_currentPeriod (API: $servicePeriod)',
      );

      Map<String, dynamic> summary;
      List<Map<String, dynamic>> popularDishes;

      // Si es un período personalizado, enviar fechas específicas
      if (_currentPeriod == 'personalizado' &&
          _customStartDate != null &&
          _customEndDate != null) {
        print('📅 Rango personalizado: $_customStartDate a $_customEndDate');

        summary = await _ordersService.getOrdersSummary(
          period: servicePeriod,
          customStartDate: _customStartDate,
          customEndDate: _customEndDate,
        );

        // Cargar platos populares para el mismo período
        popularDishes = await _popularDishesService.getPopularDishesDirect(
          period: null, // No usar período predefinido para rango personalizado
          startDate: _customStartDate,
          endDate: _customEndDate,
          limit: 5,
        );
      } else if (_currentPeriod == 'todos') {
        // Para "todos", usamos el período 'all'
        summary = await _ordersService.getOrdersSummary(
          period: 'all', // Usar 'all' como período para incluir todo
        );

        // Cargar todos los platos populares sin filtros de fecha
        popularDishes = await _popularDishesService.getPopularDishesDirect(
          period: 'all', // Usar 'all' como período para incluir todo
          limit: 5,
        );
      } else {
        // Caso normal para períodos predefinidos
        summary = await _ordersService.getOrdersSummary(period: servicePeriod);

        // Cargar platos populares para el mismo período
        popularDishes = await _popularDishesService.getPopularDishesDirect(
          period: servicePeriod,
          limit: 5,
        );
      }

      if (mounted) {
        setState(() {
          _summaryData = summary;
          _popularDishes = popularDishes;
          _isLoading = false;
        });
        print('📊 Datos cargados: ${summary.toString()}');
        print('🍽️ Platos populares: ${popularDishes.length}');
      }
    } catch (e) {
      print('❌ Error al cargar datos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
          // En caso de error, mostrar datos vacíos
          _summaryData = {
            'totalPedidos': 0,
            'totalVentas': 0.0,
            'ticketPromedio': 0.0,
          };
          _popularDishes = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(amount);
  }

  String _getReportTitle() {
    switch (_currentPeriod) {
      case 'hoy':
        return 'Reporte del día';
      case 'semana':
        return 'Reporte semanal';
      case 'mes':
        return 'Reporte mensual';
      case 'año':
        return 'Reporte anual';
      case 'personalizado':
        if (_customStartDate != null && _customEndDate != null) {
          // Convertir las fechas de formato yyyy-MM-dd a dd/MM/yyyy para mostrar
          final dateFormat = DateFormat('yyyy-MM-dd');
          final displayFormat = DateFormat('dd/MM/yyyy');
          final startDate = dateFormat.parse(_customStartDate!);
          final endDate = dateFormat.parse(_customEndDate!);

          return 'Reporte del ${displayFormat.format(startDate)} al ${displayFormat.format(endDate)}';
        }
        return 'Reporte personalizado';
      default:
        return 'Reporte de ventas';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de fechas
          DateFilterBar(
            key: _filterBarKey,
            initialFilter: _currentPeriod,
            onFilterChanged: (filter) {
              setState(() {
                _currentPeriod = filter;
              });
              _loadReportData();
            },
            onCustomDateRangeSelected: (startDate, endDate) {
              setState(() {
                _customStartDate = startDate;
                _customEndDate = endDate;
                _currentPeriod = 'personalizado';
              });
              _loadReportData();
            },
          ),

          // Contenido principal con Expanded para evitar el desbordamiento
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadReportData,
                      color: theme.colorScheme.primary,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          // Tarjetas de estadísticas
                          _buildStatisticsCards(theme),

                          const SizedBox(height: 16),

                          // Distribución de pedidos (platos populares)
                          _buildDistributionSection(theme),

                          const SizedBox(height: 16),

                          // Botón para ver historial de pedidos
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
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(ThemeData theme) {
    // Asegurar que los valores son números válidos
    final totalPedidos = _summaryData['totalPedidos'] ?? 0;
    final totalVentas =
        _summaryData['totalVentas'] is num
            ? _summaryData['totalVentas']
            : double.tryParse('${_summaryData['totalVentas']}') ?? 0.0;
    final ticketPromedio =
        _summaryData['ticketPromedio'] is num
            ? _summaryData['ticketPromedio']
            : double.tryParse('${_summaryData['ticketPromedio']}') ?? 0.0;

    print(
      '💰 Valores para tarjetas: Pedidos=$totalPedidos, Ventas=$totalVentas, Ticket=$ticketPromedio',
    );

    // Si no hay pedidos, mostrar un mensaje
    if (totalPedidos == 0) {
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
                '$totalPedidos',
                Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Ventas totales',
                _formatCurrency(totalVentas),
                Icons.attach_money,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          theme,
          'Ticket promedio',
          _formatCurrency(ticketPromedio),
          Icons.point_of_sale,
          isWide: true,
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

  Widget _buildDistributionSection(ThemeData theme) {
    // Verificar que haya datos de pedidos
    final hayPedidos = (_summaryData['totalPedidos'] ?? 0) > 0;

    // Si hay pedidos, mostrar el gráfico siempre
    if (hayPedidos) {
      // Incluso si no hay platos populares, intentar mostrar el gráfico
      return _buildPopularDishesChart(theme);
    }

    // Mensaje para cuando no hay pedidos
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
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No hay pedidos en este período para mostrar distribución',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
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
      totalVentas += dish['cantidad_vendida'] as int;
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
                        _popularDishes
                            .map(
                              (dish) =>
                                  (dish['cantidad_vendida'] as int) /
                                  totalVentas,
                            )
                            .toList(),
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
                          final percent = ((dish['cantidad_vendida'] as int) /
                                  totalVentas *
                                  100)
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
              final ventas = dish['cantidad_vendida'] as int;
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
