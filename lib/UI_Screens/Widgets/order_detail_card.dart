import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    }

    // Actualizar el temporizador si el estado cambió
    if (oldWidget.order['estado'] != widget.order['estado']) {
      _startTimerIfPending();
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
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con información básica
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pedido #${widget.order['idpedido']}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.order['fecha'] ?? ''} ${widget.order['hora'] ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

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

              // Si está expandido, mostrar los items
              if (widget.isExpanded && items.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                Text('Detalle del pedido', style: theme.textTheme.titleSmall),

                const SizedBox(height: 8),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final cantidadItem = item['cantidad'] ?? 1;
                    final precioUnitario = item['precio_unitario'] ?? 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text(
                            '$cantidadItem x',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['nombre'] ?? 'Item',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            _formatCurrency(precioUnitario * cantidadItem),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                const Divider(),

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
                          onPressed: () => widget.onStatusChange!('cancelado'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Completar'),
                          onPressed: () => widget.onStatusChange!('completado'),
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
                    Text(
                      '${items.length} ${items.length == 1 ? 'ítem' : 'ítems'}',
                      style: theme.textTheme.bodyMedium,
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tocar para ver detalles',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
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
}
