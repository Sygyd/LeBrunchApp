import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _isLoading = true;
  String _currentPeriod = 'day'; // 'day', 'week', 'month', 'year', 'custom'
  Map<String, dynamic> _summaryData = {};

  // Para filtrado personalizado
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Si es un período personalizado, enviar fechas específicas
      if (_currentPeriod == 'custom' &&
          _startDate != null &&
          _endDate != null) {
        final formatter = DateFormat('yyyy-MM-dd');
        final summary = await _ordersService.getOrdersSummary(
          period: _currentPeriod,
          customStartDate: formatter.format(_startDate!),
          customEndDate: formatter.format(_endDate!),
        );

        if (mounted) {
          setState(() {
            _summaryData = summary;
            _isLoading = false;
          });
        }
      } else {
        // Caso normal para períodos predefinidos
        final summary = await _ordersService.getOrdersSummary(
          period: _currentPeriod,
        );

        if (mounted) {
          setState(() {
            _summaryData = summary;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los datos: $e')),
        );
      }
    }
  }

  Future<void> _showDateRangePicker() async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _endDate ?? DateTime.now(),
    );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
        _currentPeriod = 'custom';
      });

      _loadReportData();
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(amount);
  }

  String _getReportTitle() {
    switch (_currentPeriod) {
      case 'day':
        return 'Reporte del día';
      case 'week':
        return 'Reporte semanal';
      case 'month':
        return 'Reporte mensual';
      case 'year':
        return 'Reporte anual';
      case 'custom':
        if (_startDate != null && _endDate != null) {
          final formatter = DateFormat('dd/MM/yyyy');
          return 'Reporte del ${formatter.format(_startDate!)} al ${formatter.format(_endDate!)}';
        }
        return 'Reporte personalizado';
      default:
        return 'Reporte de ventas';
    }
  }

  void _navigateToOrderHistory() {
    final formatter = DateFormat('yyyy-MM-dd');
    String? startDate;
    String? endDate;
    String periodText;

    final now = DateTime.now();

    switch (_currentPeriod) {
      case 'day':
        // Solo el día actual
        startDate = formatter.format(DateTime(now.year, now.month, now.day));
        endDate = formatter.format(
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        periodText = 'Pedidos del día';
        break;
      case 'week':
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
      case 'month':
        // Desde el primer día del mes
        startDate = formatter.format(DateTime(now.year, now.month, 1));
        endDate = formatter.format(now);
        periodText = 'Pedidos del mes';
        break;
      case 'year':
        // Desde el primer día del año
        startDate = formatter.format(DateTime(now.year, 1, 1));
        endDate = formatter.format(now);
        periodText = 'Pedidos del año';
        break;
      case 'custom':
        // Usar las fechas personalizadas
        if (_startDate != null && _endDate != null) {
          startDate = formatter.format(_startDate!);
          endDate = formatter.format(_endDate!);
          final displayFormatter = DateFormat('dd/MM/yyyy');
          periodText =
              'Pedidos del ${displayFormatter.format(_startDate!)} al ${displayFormatter.format(_endDate!)}';
        } else {
          periodText = 'Historial de pedidos';
        }
        break;
      default:
        periodText = 'Historial de pedidos';
    }

    Navigator.pushNamed(
      context,
      '/admin/orders',
      arguments: {
        'title': periodText,
        'startDate': startDate,
        'endDate': endDate,
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
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white, width: 1.5),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
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
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de período
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Seleccionar período',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildPeriodChip('Hoy', 'day'),
                                    _buildPeriodChip('Esta semana', 'week'),
                                    _buildPeriodChip('Este mes', 'month'),
                                    _buildPeriodChip('Este año', 'year'),
                                    const SizedBox(width: 8),
                                    ActionChip(
                                      avatar: const Icon(Icons.date_range),
                                      label: const Text('Personalizado'),
                                      backgroundColor:
                                          _currentPeriod == 'custom'
                                              ? theme.colorScheme.primary
                                                  .withOpacity(0.2)
                                              : null,
                                      onPressed: _showDateRangePicker,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tarjetas principales de estadísticas
                      _buildMainStatsCards(theme),

                      const SizedBox(height: 16),

                      // Platos más populares
                      _buildPopularDishesSection(theme),

                      const SizedBox(height: 16),

                      // Tabla de distribución según el período
                      _buildDistributionSection(theme),

                      const SizedBox(height: 24),

                      // Botón para ver pedidos detallados
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToOrderHistory,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text(
                            'Ver historial de pedidos detallado',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildPeriodChip(String label, String period) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: _currentPeriod == period,
        selectedColor: theme.colorScheme.primary.withOpacity(0.2),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _currentPeriod = period;
            });
            _loadReportData();
          }
        },
      ),
    );
  }

  Widget _buildMainStatsCards(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                'Total de pedidos',
                '${_summaryData['totalPedidos'] ?? 0}',
                Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme,
                'Ventas totales',
                _formatCurrency(_summaryData['totalVentas'] ?? 0),
                Icons.attach_money,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          theme,
          'Ticket promedio',
          _formatCurrency(_summaryData['ticketPromedio'] ?? 0),
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
                  Text(title, style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularDishesSection(ThemeData theme) {
    final platosPopulares = _summaryData['platosPopulares'] as List? ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Platos más populares',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            platosPopulares.isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No hay datos disponibles',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      platosPopulares.length > 3 ? 3 : platosPopulares.length,
                  itemBuilder: (context, index) {
                    final plato = platosPopulares[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.2,
                        ),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(plato['nombre'] ?? ''),
                      subtitle: Text(
                        'Ordenado ${plato['cantidad'] ?? 0} veces',
                      ),
                      trailing: Text(
                        '${(plato['cantidad'] / (_summaryData['totalPedidos'] ?? 1) * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionSection(ThemeData theme) {
    Widget distributionContent;

    // Mostrar diferentes visualizaciones según el período seleccionado
    if (_currentPeriod == 'day' && _summaryData.containsKey('horasPico')) {
      final horasPico = _summaryData['horasPico'] as List? ?? [];

      distributionContent = _buildDistributionList(
        theme,
        'Horas pico',
        horasPico,
        labelField: 'hora',
        valueField: 'pedidos',
        valueLabel: 'pedidos',
      );
    } else if (_currentPeriod == 'week' &&
        _summaryData.containsKey('diasPico')) {
      final diasPico = _summaryData['diasPico'] as List? ?? [];

      distributionContent = _buildDistributionList(
        theme,
        'Días con mayor actividad',
        diasPico,
        labelField: 'dia',
        valueField: 'pedidos',
        valueLabel: 'pedidos',
      );
    } else if (_currentPeriod == 'month' &&
        _summaryData.containsKey('semanasPico')) {
      final semanasPico = _summaryData['semanasPico'] as List? ?? [];

      distributionContent = _buildDistributionList(
        theme,
        'Semanas con mayor actividad',
        semanasPico,
        labelField: 'semana',
        valueField: 'pedidos',
        valueLabel: 'pedidos',
      );
    } else if (_currentPeriod == 'year' &&
        _summaryData.containsKey('mesesPico')) {
      final mesesPico = _summaryData['mesesPico'] as List? ?? [];

      distributionContent = _buildDistributionList(
        theme,
        'Meses con mayor actividad',
        mesesPico,
        labelField: 'mes',
        valueField: 'pedidos',
        valueLabel: 'pedidos',
      );
    } else {
      // Caso por defecto o personalizado
      distributionContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No hay datos de distribución disponibles para este período',
            textAlign: TextAlign.center,
          ),
        ),
      );
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
                Icon(Icons.insert_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Distribución de pedidos',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            distributionContent,
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionList(
    ThemeData theme,
    String title,
    List items, {
    required String labelField,
    required String valueField,
    required String valueLabel,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No hay datos disponibles',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final label = item[labelField] ?? '';
            final value = item[valueField] ?? 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  Expanded(
                    flex: 5,
                    child: LinearProgressIndicator(
                      value: value / (_getMaxValue(items, valueField) * 1.1),
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.1,
                      ),
                      color: theme.colorScheme.primary,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$value $valueLabel',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  int _getMaxValue(List items, String field) {
    if (items.isEmpty) return 1;

    int maxValue = 0;
    for (final item in items) {
      final value = item[field] ?? 0;
      if (value > maxValue) {
        maxValue = value;
      }
    }

    return maxValue > 0 ? maxValue : 1;
  }
}
