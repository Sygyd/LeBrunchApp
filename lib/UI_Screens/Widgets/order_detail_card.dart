import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';

class OrderDetailCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onTap;
  final bool isExpanded;
  final Function(String)? onStatusChange;

  const OrderDetailCard({
    super.key,
    required this.order,
    this.onTap,
    this.isExpanded = false,
    this.onStatusChange,
  });

  @override
  State<OrderDetailCard> createState() => _OrderDetailCardState();
}

class _OrderDetailCardState extends State<OrderDetailCard> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  late DateTime _orderTime;
  final OrdersService _ordersService = OrdersService();
  Map<String, dynamic>? _processingTimeData;
  bool _loadingProcessingTime = false;
  // Definir el offset para la zona horaria de Venezuela (GMT-4)
  static const int _venezuelaOffsetHours = -4;
  static const bool _debugMode = false; // Activa/desactiva logs de depuración

  @override
  void initState() {
    super.initState();
    // Inicializar la hora del pedido basada en los datos
    _initializeOrderTime();
    // Iniciar temporizador si el pedido está pendiente
    _startTimerIfPending();
    // Cargar tiempo de procesamiento si es completado o cancelado
    _loadProcessingTimeIfNeeded();
  }

  @override
  void didUpdateWidget(OrderDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Comprobar si la información del pedido ha cambiado significativamente
    if (oldWidget.order['idpedido'] != widget.order['idpedido'] ||
        oldWidget.order['fecha'] != widget.order['fecha'] ||
        oldWidget.order['hora'] != widget.order['hora']) {
      // Reinicializar la hora del pedido si es un pedido diferente
      _initializeOrderTime();
      // Reiniciar datos de tiempo de procesamiento
      _processingTimeData = null;
      _loadProcessingTimeIfNeeded();
    }

    // Actualizar el temporizador si el estado cambió
    if (oldWidget.order['estado'] != widget.order['estado']) {
      _startTimerIfPending();
      _loadProcessingTimeIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeOrderTime() {
    final String orderDate = widget.order['fecha'] ?? '';
    final String orderTime = widget.order['hora'] ?? '';

    try {
      // Intentar parsear la fecha y hora del pedido
      if (orderDate.isNotEmpty && orderTime.isNotEmpty) {
        // Crear DateTime en UTC
        final parsedDateTime = DateFormat('yyyy-MM-dd HH:mm').parse(
          '$orderDate $orderTime',
          true, // Usar UTC
        );

        // Ajustar a la zona horaria de Venezuela (GMT-4)
        _orderTime = parsedDateTime.toUtc().add(
          const Duration(hours: _venezuelaOffsetHours),
        );

        if (_debugMode) print('⏰ Hora del pedido parseada: $_orderTime');
      } else {
        // Si no hay fecha/hora válida, usar hace 5 minutos como fallback
        _orderTime = DateTime.now().toUtc().add(
          const Duration(hours: _venezuelaOffsetHours, minutes: -5),
        );
        if (_debugMode) print('⏰ Usando hora fallback: $_orderTime');
      }

      // Calcular tiempo transcurrido desde que se creó el pedido
      _updateElapsedTime();
      if (_debugMode)
        print('⏰ Tiempo transcurrido inicial: ${_formatElapsedTime()}');
    } catch (e) {
      print('❌ Error al parsear fecha del pedido: $e');
      // Usar un valor predeterminado en caso de error
      _orderTime = DateTime.now().toUtc().add(
        const Duration(hours: _venezuelaOffsetHours, minutes: -5),
      );
      _elapsedTime = const Duration(minutes: 5);
    }
  }

  Future<void> _loadProcessingTimeIfNeeded() async {
    final estado = widget.order['estado']?.toString().toLowerCase() ?? '';

    // Solo cargar tiempo para pedidos completados o cancelados
    if (estado == 'completado' || estado == 'cancelado') {
      if (_processingTimeData == null && !_loadingProcessingTime) {
        setState(() {
          _loadingProcessingTime = true;
        });

        try {
          final orderId = widget.order['idpedido'];
          if (orderId != null) {
            final timeData = await _ordersService.getOrderProcessingTime(
              orderId,
            );

            if (mounted) {
              setState(() {
                _processingTimeData = timeData;
                _loadingProcessingTime = false;
              });
            }
          }
        } catch (e) {
          print('❌ Error al cargar tiempo de procesamiento: $e');
          if (mounted) {
            setState(() {
              _loadingProcessingTime = false;
            });
          }
        }
      }
    }
  }

  void _updateElapsedTime() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: _venezuelaOffsetHours),
    );
    _elapsedTime = now.difference(_orderTime);
  }

  void _startTimerIfPending() {
    // Cancelar timer existente
    _timer?.cancel();
    _timer = null;

    // Solo iniciar timer si el pedido está pendiente
    final estado = widget.order['estado']?.toString().toLowerCase() ?? '';
    if (estado == 'pendiente') {
      if (_debugMode) {
        print(
          '⏱️ Iniciando temporizador para pedido pendiente #${widget.order['idpedido']}',
        );
      }

      // Actualizar cada segundo
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _updateElapsedTime();
          });
        }
      });
    } else {
      if (_debugMode) {
        print(
          '🛑 No se inicia temporizador, pedido no pendiente: ${widget.order['estado']}',
        );
      }
    }
  }

  String _formatElapsedTime() {
    int hours = _elapsedTime.inHours;
    int minutes = _elapsedTime.inMinutes % 60;
    int seconds = _elapsedTime.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatCurrency(dynamic amount) {
    // Asegurar que el valor sea un double
    final double safeAmount =
        amount is double
            ? amount
            : (amount is int
                ? amount.toDouble()
                : double.tryParse(amount.toString()) ?? 0.0);

    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(safeAmount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.order['items'] as List? ?? [];
    final total = widget.order['total'] ?? 0.0;
    final estado = widget.order['estado'] ?? 'pendiente';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con información básica
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(estado, theme),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(estado),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pedido #${widget.order['idpedido']}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.order['fecha'] ?? ''} ${widget.order['hora'] ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Información del cliente
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cliente: ${widget.order['cliente'] ?? 'Cliente'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),

              // Mostrar tiempo transcurrido para pedidos pendientes
              if (estado.toLowerCase() == 'pendiente') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Tiempo: ${_formatElapsedTime()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],

              // Mostrar tiempo de procesamiento para pedidos completados o cancelados
              if ((estado.toLowerCase() == 'completado' ||
                  estado.toLowerCase() == 'cancelado')) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timelapse,
                      size: 18,
                      color:
                          estado.toLowerCase() == 'completado'
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    if (_loadingProcessingTime)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_processingTimeData != null)
                      Text(
                        'Tiempo de procesamiento: ${_processingTimeData!['tiempo_formato']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              estado.toLowerCase() == 'completado'
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        'Tiempo de procesamiento: No disponible',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],

              // Si está expandido, mostrar los items
              if (widget.isExpanded && items.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),

                Text(
                  'Detalle del pedido',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12),
                ),

                const SizedBox(height: 4),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final cantidadItem = item['cantidad'] ?? 1;
                    final precioUnitario = item['precio_unitario'] ?? 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Text(
                            '$cantidadItem x',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['nombre'] ?? 'Item',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            _formatCurrency(precioUnitario * cantidadItem),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),

                // Total
                Row(
                  children: [
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total', style: theme.textTheme.titleSmall),
                        Text(
                          _formatCurrency(total),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Botones de acción si está pendiente y hay un callback para cambiar el estado
                if (widget.onStatusChange != null &&
                    estado != 'completado' &&
                    estado != 'cancelado') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (estado == 'pendiente') ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar'),
                          onPressed:
                              () => _showConfirmationDialog(
                                context,
                                'Cancelar Pedido',
                                '¿Estás seguro de que deseas cancelar este pedido?',
                                'cancelado',
                              ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Completar'),
                          onPressed:
                              () => _showConfirmationDialog(
                                context,
                                'Completar Pedido',
                                '¿Estás seguro de que deseas marcar este pedido como completado?',
                                'completado',
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(() {
                      // Calcular el número total de platos sumando las cantidades
                      int totalPlatos = 0;
                      for (var item in items) {
                        if (item['cantidad'] is int) {
                          totalPlatos += item['cantidad'] as int;
                        } else if (item['cantidad'] is double) {
                          totalPlatos += (item['cantidad'] as double).toInt();
                        } else if (item['cantidad'] != null) {
                          totalPlatos +=
                              int.tryParse(item['cantidad'].toString()) ?? 1;
                        } else {
                          totalPlatos +=
                              1; // Valor por defecto si no hay cantidad
                        }
                      }

                      return '${items.length} ${items.length == 1 ? 'ítem' : 'ítems'} · $totalPlatos ${totalPlatos == 1 ? 'plato' : 'platos'}';
                    }(), style: theme.textTheme.bodyMedium),
                    Text(
                      _formatCurrency(total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.onTap != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isExpanded ? 'Ver menos' : 'Ver más',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          widget.isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'completado':
        return 'COMPLETADO';
      case 'cancelado':
        return 'CANCELADO';
      default:
        return status.toUpperCase();
    }
  }

  void _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    String status,
  ) {
    final theme = Theme.of(context);

    // Usar los colores directamente del esquema de colores del tema
    final Color actionColor =
        status == 'cancelado'
            ? theme.colorScheme.error
            : theme.colorScheme.primary;

    final Color overlayColor = theme.colorScheme.surface.withOpacity(0.95);

    showDialog(
      context: context,
      barrierDismissible: false, // Evitar cierre accidental
      builder:
          (context) => Theme(
            // Asegurar que el diálogo utilice el tema actual
            data: theme,
            child: AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              title: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: actionColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'LightHouse',
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: actionColor, width: 2),
              ),
              backgroundColor: overlayColor,
              elevation: 8,
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withOpacity(
                      0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Cancelar', style: theme.textTheme.labelLarge),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onStatusChange!(status);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor:
                        status == 'cancelado'
                            ? theme.colorScheme.onError
                            : theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Confirmar',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          status == 'cancelado'
                              ? theme.colorScheme.onError
                              : theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
