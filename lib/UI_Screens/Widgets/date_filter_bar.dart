import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:developer' as developer;
import 'dart:async'; // Para StreamSubscription
import '../../services/order_status_service.dart'; // Importar el servicio

// Exponer el tipo para uso con GlobalKey
typedef DateFilterBarState = _DateFilterBarState;

class DateFilterBar extends StatefulWidget {
  final String initialFilter;
  final Function(String) onFilterChanged;
  final Function(String, String) onCustomDateRangeSelected;
  final bool showFilterLabel;

  const DateFilterBar({
    Key? key,
    this.initialFilter = 'todos',
    required this.onFilterChanged,
    required this.onCustomDateRangeSelected,
    this.showFilterLabel = true,
  }) : super(key: key);

  @override
  State<DateFilterBar> createState() => _DateFilterBarState();
}

class _DateFilterBarState extends State<DateFilterBar> {
  late String _selectedFilter;
  List<DateTime?> _selectedDates = [];
  final OrderStatusService _statusService =
      OrderStatusService(); // Instancia del servicio
  StreamSubscription?
  _orderCompletedSubscription; // Suscripción a cambios de estado

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;

    // Suscribirse a cambios de estado de pendiente a completado
    _orderCompletedSubscription = _statusService.onOrderCompleted.listen(
      _handleOrderCompleted,
    );
  }

  @override
  void dispose() {
    _orderCompletedSubscription?.cancel();
    super.dispose();
  }

  // Cuando un pedido se completa, actualizar si estamos en un filtro relevante
  void _handleOrderCompleted(int orderId) {
    developer.log(
      '📣 DateFilterBar: Recibida notificación de pedido #$orderId completado',
      name: 'DateFilterBar',
    );

    // Si estamos viendo pedidos pendientes, actualizamos para reflejar el cambio
    if (_selectedFilter == 'pendientes') {
      // Notificar al padre que debe actualizar los datos
      widget.onFilterChanged(_selectedFilter);
      developer.log(
        '🔄 Solicitando recarga de pedidos pendientes debido a un cambio de estado',
        name: 'DateFilterBar',
      );
    }
  }

  // Método para actualizar el filtro programáticamente
  void updateFilter(String filter) {
    if (mounted) {
      setState(() {
        _selectedFilter = filter;
      });
      // No llamamos a widget.onFilterChanged para evitar un ciclo
    }
  }

  // Método para construir un filtro chip
  Widget _buildFilterChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == value;

    // Resaltar especialmente la opción "Todos" cuando está seleccionada
    final bool isTodosSelected = value == 'todos' && isSelected;

    return ChoiceChip(
      label: Text(
        value == 'todos'
            ? 'Todos los pedidos'
            : label, // Texto más claro para "Todos"
        style: TextStyle(
          fontSize:
              value == 'todos'
                  ? 13
                  : 12, // Texto ligeramente más grande para "Todos"
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });

          widget.onFilterChanged(value);
        }
      },
      selectedColor:
          isTodosSelected
              ? theme.colorScheme.primary.withOpacity(
                0.3,
              ) // Color más intenso para "Todos" cuando está seleccionado
              : theme.colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color:
            isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: value == 'todos' ? 12 : 8,
      ), // Padding adicional para "Todos"
    );
  }

  // Método para mostrar el calendario
  Future<void> _showCalendarDialog() async {
    final theme = Theme.of(context);

    final result = await showDialog<List<DateTime?>>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Seleccionar rango de fechas',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 390, // Más ancho para meses largos
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.copyWith(
                          titleMedium: const TextStyle(
                            fontSize: 13, // Más pequeño para el header
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      child: CalendarDatePicker2(
                        config: CalendarDatePicker2Config(
                          calendarType: CalendarDatePicker2Type.range,
                          selectedDayHighlightColor: const Color(0xFF3ea69b),
                          weekdayLabels: [
                            'Lun',
                            'Mar',
                            'Mié',
                            'Jue',
                            'Vie',
                            'Sáb',
                            'Dom',
                          ],
                          weekdayLabelTextStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          firstDayOfWeek: 1,
                          controlsHeight: 26,
                          controlsTextStyle: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          dayTextStyle: const TextStyle(color: Colors.black87),
                          selectedDayTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          todayTextStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          centerAlignModePicker: true,
                          useAbbrLabelForMonthModePicker:
                              true, // Usar abreviaturas de meses
                        ),
                        value: _selectedDates,
                        onValueChanged: (dates) {
                          setState(() {
                            _selectedDates = dates;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_selectedDates.length >= 2 &&
                              _selectedDates[0] != null &&
                              _selectedDates[1] != null) {
                            Navigator.of(context).pop(_selectedDates);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Por favor selecciona un rango de fechas',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (result != null && result.length >= 2) {
      setState(() {
        _selectedFilter = 'personalizado';
        _selectedDates = result;
      });

      final startDate = DateFormat('yyyy-MM-dd').format(result[0]!);
      final endDate = DateFormat('yyyy-MM-dd').format(result[1]!);

      developer.log(
        '📅 Rango de fechas seleccionado: $startDate a $endDate',
        name: 'DateFilterBar',
      );

      widget.onCustomDateRangeSelected(startDate, endDate);
      widget.onFilterChanged('personalizado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showFilterLabel)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    'Filtrar por período:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todos', 'todos'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Hoy', 'hoy'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Esta semana', 'semana'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Este mes', 'mes'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Último año', 'año'),
                    const SizedBox(width: 8),
                    // Botón de calendario personalizado
                    InkWell(
                      onTap: _showCalendarDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _selectedFilter == 'personalizado'
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _selectedFilter == 'personalizado'
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 16,
                              color:
                                  _selectedFilter == 'personalizado'
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedFilter == 'personalizado' &&
                                      _selectedDates.length >= 2
                                  ? _getShortRangeText()
                                  : 'Personalizado',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    _selectedFilter == 'personalizado'
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade700,
                                fontWeight:
                                    _selectedFilter == 'personalizado'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mostrar el rango de fechas si está seleccionado personalizado
              if (_selectedFilter == 'personalizado' &&
                  _selectedDates.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Text(
                    'Rango: ${_getFullRangeText()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para obtener un texto corto del rango de fechas
  String _getShortRangeText() {
    if (_selectedDates.length < 2 ||
        _selectedDates[0] == null ||
        _selectedDates[1] == null) {
      return 'Personalizado';
    }

    final formatter = DateFormat('dd/MM');
    return '${formatter.format(_selectedDates[0]!)} - ${formatter.format(_selectedDates[1]!)}';
  }

  // Método para obtener el texto completo del rango de fechas
  String _getFullRangeText() {
    if (_selectedDates.length < 2 ||
        _selectedDates[0] == null ||
        _selectedDates[1] == null) {
      return '';
    }

    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(_selectedDates[0]!)} al ${formatter.format(_selectedDates[1]!)}';
  }
}
