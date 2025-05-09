import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';

class OrderDetailCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isExpanded;
  final VoidCallback? onTap;
  final Function(String)? onStatusChange;
  final VoidCallback? onRefresh;
  final String? role; // 'cook' o 'barista'

  const OrderDetailCard({
    super.key,
    required this.order,
    this.isExpanded = false,
    this.onTap,
    this.onStatusChange,
    this.onRefresh,
    this.role,
  });

  @override
  State<OrderDetailCard> createState() => _OrderDetailCardState();
}

class _OrderDetailCardState extends State<OrderDetailCard> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  late DateTime _orderTime;
  late final OrdersService _ordersService;
  Map<String, dynamic>? _processingTimeData;
  bool _loadingProcessingTime = false;
  static const bool _debugMode = false; // Activa/desactiva logs de depuración

  // Método para logs condicionales, reemplaza los print
  void _log(String message) {
    if (_debugMode) {
      // Evitar print en producción usando debugPrint que ya está en material.dart
      debugPrint(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _ordersService = OrdersService();
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
        // Crear DateTime con la fecha y hora del pedido
        // No usamos UTC para evitar problemas de zona horaria
        final parsedDateTime = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).parse('$orderDate $orderTime');

        // El servidor ya está en zona horaria America/Caracas (GMT-4)
        // No necesitamos ajustar más la hora
        _orderTime = parsedDateTime;

        _log('⏰ Hora del pedido parseada: $_orderTime');
      } else {
        // Si no hay fecha/hora válida, usar la hora actual como fallback
        _orderTime = DateTime.now();
        _log('⏰ Usando hora fallback: $_orderTime');
      }

      // Calcular tiempo transcurrido desde que se creó el pedido
      _updateElapsedTime();

      // Usar llaves para el bloque if de debug
      if (_debugMode) {
        _log('⏰ Tiempo transcurrido inicial: ${_formatElapsedTime()}');
      }
    } catch (e) {
      // Usar método de log en lugar de print directo
      debugPrint('❌ Error al parsear fecha del pedido: $e');
      // Usar la hora actual en caso de error
      _orderTime = DateTime.now();
      _elapsedTime = Duration.zero;
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
          debugPrint('❌ Error al cargar tiempo de procesamiento: $e');
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
    // Usar la hora local actual sin ajustes de UTC
    final now = DateTime.now();
    _elapsedTime = now.difference(_orderTime);
  }

  void _startTimerIfPending() {
    // Cancelar timer existente
    _timer?.cancel();
    _timer = null;

    // Solo iniciar timer si el pedido está pendiente
    final estado = widget.order['estado']?.toString().toLowerCase() ?? '';
    if (estado == 'pendiente') {
      // Usar llaves para el bloque if
      if (_debugMode) {
        _log(
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
      // Usar llaves para el bloque if
      if (_debugMode) {
        _log(
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

  Future<void> _updateItemStatus(int platoId, bool completado) async {
    try {
      final items = List<Map<String, dynamic>>.from(
        widget.order['items'] ?? [],
      );

      // Encontrar el ítem específico
      final itemIndex = items.indexWhere((item) => item['idplato'] == platoId);
      if (itemIndex == -1) {
        throw Exception('Ítem no encontrado');
      }

      final item = items[itemIndex];
      final String tipo = item['tipo']?.toString().toLowerCase() ?? '';

      // Determinar el rol adecuado para la actualización según el tipo de ítem
      final String roleForUpdate = tipo == 'comida' ? 'cook' : 'barista';

      final success = await _ordersService.updateItemStatus(
        widget.order['idpedido'],
        platoId,
        completado,
        widget.role ?? roleForUpdate,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completado
                  ? 'Item marcado como completado'
                  : 'Item marcado como pendiente',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Verificar si la orden está completamente lista usando el método adecuado
        await _ordersService.checkAndUpdateOrderCompletion(
          widget.order['idpedido'],
        );

        // Refrescar la interfaz
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para marcar todos los ítems de un tipo (comida/bebida) como completados
  Future<void> _completeAllItemsOfType(String tipo) async {
    try {
      final items = List<Map<String, dynamic>>.from(
        widget.order['items'] ?? [],
      );
      bool atLeastOneUpdated = false;

      // Filtrar los ítems por tipo y marcar como completados
      for (var item in items) {
        if (item['tipo']?.toString().toLowerCase() == tipo.toLowerCase()) {
          final bool isAlreadyCompleted =
              tipo == 'comida'
                  ? (item['completado_cocinero'] ?? false)
                  : (item['completado_barista'] ?? false);

          // Solo actualizar los que no están completados
          if (!isAlreadyCompleted) {
            final success = await _ordersService.updateItemStatus(
              widget.order['idpedido'],
              item['idplato'],
              true,
              tipo == 'comida' ? 'cook' : 'barista',
            );

            if (success) {
              atLeastOneUpdated = true;
            }
          }
        }
      }

      if (atLeastOneUpdated && mounted) {
        // Determinar si hay ítems del otro tipo también
        bool hayComida = false;
        bool hayBebida = false;

        for (var item in items) {
          final itemTipo = item['tipo']?.toString().toLowerCase() ?? '';
          if (itemTipo == 'comida') hayComida = true;
          if (itemTipo == 'bebida') hayBebida = true;
        }

        // Mensaje específico según el contexto
        String mensaje = 'Todos los ítems de $tipo completados';

        if (hayComida && hayBebida) {
          if (tipo == 'comida') {
            mensaje = 'Comida completada. Faltan bebidas.';
          } else {
            mensaje = 'Bebidas completadas. Falta comida.';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
        );

        // Verificar el estado del pedido para posible actualización automática
        await _ordersService.checkAndUpdateOrderCompletion(
          widget.order['idpedido'],
        );

        // Actualizar la UI para reflejar los cambios
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar los ítems: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = List<Map<String, dynamic>>.from(widget.order['items'] ?? []);
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
                  Flexible(
                    child: Text(
                      'Pedido #${widget.order['idpedido']}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${widget.order['fecha'] ?? ''} ${widget.order['hora'] ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Indicador de progreso de la orden (si está pendiente)
              if (estado.toLowerCase() == 'pendiente' && items.isNotEmpty) ...[
                _buildOrderProgressIndicator(items, theme),
                const SizedBox(height: 8),
              ],

              // Información del cliente
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cliente: ${widget.order['cliente'] ?? 'Cliente'}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),

              // Botones de acción para roles específicos (cook/barista)
              if (widget.role == 'cook' || widget.role == 'barista') ...[
                const SizedBox(height: 8),
                _buildCompleteItemsButton(items, widget.role!, theme),
              ],

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
                    // Asegurar que tipo siempre sea un valor válido
                    final String itemTipo =
                        (item['tipo'] ?? '').toString().toLowerCase();
                    final bool isComida = itemTipo == 'comida';

                    // Determinar si mostrar checkbox basado en el rol
                    final bool showCheckbox = widget.role == 'admin';
                    final bool showActionButton =
                        (widget.role == 'cook' && isComida) ||
                        (widget.role == 'barista' && !isComida);

                    // Determinar el estado de completado para cocinero y barista
                    final bool completadoCocinero =
                        item['completado_cocinero'] ?? false;
                    final bool completadoBarista =
                        item['completado_barista'] ?? false;

                    // Determinar si el item está completado según su tipo
                    final bool isCompleted =
                        isComida ? completadoCocinero : completadoBarista;

                    // Obtener la fecha de completado según el rol o tipo
                    final String? fechaCompletadoCocinero =
                        item['fecha_completado_cocinero'];
                    final String? fechaCompletadoBarista =
                        item['fecha_completado_barista'];
                    final String? fechaCompletado =
                        isComida
                            ? fechaCompletadoCocinero
                            : fechaCompletadoBarista;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkbox solo para admin
                          if (showCheckbox)
                            Checkbox(
                              value:
                                  isComida
                                      ? completadoCocinero
                                      : completadoBarista,
                              onChanged: (bool? value) {
                                if (value != null && widget.role == 'admin') {
                                  _updateItemStatus(item['idplato'], value);
                                }
                              },
                            )
                          // Para otros roles o cuando no se muestra checkbox, mostrar icono indicador
                          else
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              child:
                                  isComida
                                      ? Icon(
                                        completadoCocinero
                                            ? Icons.restaurant
                                            : Icons.restaurant_outlined,
                                        color:
                                            completadoCocinero
                                                ? Colors.green
                                                : Colors.grey,
                                        size: 20,
                                      )
                                      : Icon(
                                        completadoBarista
                                            ? Icons.local_cafe
                                            : Icons.local_cafe_outlined,
                                        color:
                                            completadoBarista
                                                ? Colors.green
                                                : Colors.grey,
                                        size: 20,
                                      ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // Icono para indicar tipo de ítem
                                          Icon(
                                            isComida
                                                ? Icons.restaurant
                                                : Icons.local_cafe,
                                            size: 14,
                                            color: theme.colorScheme.primary
                                                .withAlpha(153),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item['nombre'] ?? 'Item',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    // Aplicar tachado si está completado
                                                    decoration:
                                                        isCompleted &&
                                                                widget.role !=
                                                                    'admin'
                                                            ? TextDecoration
                                                                .lineThrough
                                                            : null,
                                                    decorationColor:
                                                        Colors.grey,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Etiqueta de cantidad
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'x${item['cantidad'] ?? 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    // Estado visual de completado
                                    if (isCompleted)
                                      Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withAlpha(50),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isComida
                                                  ? Icons.check_circle_outline
                                                  : Icons.local_cafe,
                                              color: Colors.green,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              isComida ? 'Cocinero' : 'Barista',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: Colors.green,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                // Segunda línea con información adicional
                                if (item['precio_unitario'] != null)
                                  Text(
                                    'Precio: ${_formatCurrency(item['precio_unitario'])}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                    ),
                                  ),

                                // Notas del ítem si existen
                                if (item['notas'] != null &&
                                    item['notas'].toString().isNotEmpty)
                                  Text(
                                    'Notas: ${item['notas']}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 11,
                                    ),
                                  ),

                                // Información de tiempo de completado
                                if (fechaCompletado != null)
                                  Text(
                                    'Completado: ${_formatItemCompletionTime(fechaCompletado)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.green,
                                      fontSize: 10,
                                    ),
                                  ),

                                // Botón de acción para cocinero/barista
                                if (showActionButton && !isCompleted)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: InkWell(
                                      onTap:
                                          () => _updateItemStatus(
                                            item['idplato'],
                                            true,
                                          ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withAlpha(25),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withAlpha(75),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Marcar como completado',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Precio subtotal con manejo de overflow
                          SizedBox(
                            width: 50, // Ancho fijo para evitar overflow
                            child: Text(
                              _formatCurrency(
                                (item['precio_unitario'] ?? 0) *
                                    (item['cantidad'] ?? 1),
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
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
                    // Mostrar progreso de la orden si hay comida y bebida
                    if (widget.isExpanded && hayComidaYBebida(items)) ...[
                      Expanded(child: _buildProgressIndicator(items)),
                    ],
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
                if (widget.onRefresh != null &&
                    estado != 'completado' &&
                    estado != 'cancelado') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (estado == 'pendiente') ...[
                        // Verificar si el pedido está completamente procesado
                        if (widget.role == 'admin' &&
                            _isOrderReadyToComplete(items)) ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Completar pedido'),
                            onPressed:
                                () => _showConfirmationDialog(
                                  context,
                                  'Completar Pedido',
                                  '¿Confirmar completar pedido?',
                                  'completado',
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancelar'),
                            onPressed:
                                () => _showConfirmationDialog(
                                  context,
                                  'Cancelar Pedido',
                                  '¿Cancelar este pedido?',
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
                                  '¿Completar este pedido?',
                                  'completado',
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        () {
                          // Calcular el número total de platos sumando las cantidades
                          int totalPlatos = 0;
                          for (var item in items) {
                            if (item['cantidad'] is int) {
                              totalPlatos += item['cantidad'] as int;
                            } else if (item['cantidad'] is double) {
                              totalPlatos +=
                                  (item['cantidad'] as double).toInt();
                            } else if (item['cantidad'] != null) {
                              totalPlatos +=
                                  int.tryParse(item['cantidad'].toString()) ??
                                  1;
                            } else {
                              totalPlatos +=
                                  1; // Valor por defecto si no hay cantidad
                            }
                          }

                          return '${items.length} ${items.length == 1 ? 'ítem' : 'ítems'} · $totalPlatos ${totalPlatos == 1 ? 'plato' : 'platos'}';
                        }(),
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  // Método para mostrar diálogo de confirmación con validación mejorada
  void _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    String status,
  ) {
    final items = List<Map<String, dynamic>>.from(widget.order['items'] ?? []);

    // Si estamos intentando completar, verificar primero si está todo listo
    if (status == 'completado' && !_isOrderReadyToComplete(items)) {
      String customMessage = 'No se puede completar aún';

      bool hayComida = false;
      bool hayBebida = false;
      bool todosLosItemsComidaCompletados = true;
      bool todosLosItemsBebidaCompletados = true;

      for (var item in items) {
        final tipo = item['tipo']?.toString().toLowerCase() ?? '';

        if (tipo == 'comida') {
          hayComida = true;
          if (!(item['completado_cocinero'] ?? false)) {
            todosLosItemsComidaCompletados = false;
          }
        } else if (tipo == 'bebida') {
          hayBebida = true;
          if (!(item['completado_barista'] ?? false)) {
            todosLosItemsBebidaCompletados = false;
          }
        }
      }

      if (hayComida && hayBebida) {
        if (!todosLosItemsComidaCompletados &&
            !todosLosItemsBebidaCompletados) {
          customMessage = 'Faltan ítems de comida y bebida';
        } else if (!todosLosItemsComidaCompletados) {
          customMessage = 'Faltan ítems de comida';
        } else {
          customMessage = 'Faltan ítems de bebida';
        }
      } else if (hayComida && !todosLosItemsComidaCompletados) {
        customMessage = 'Faltan ítems de comida';
      } else if (hayBebida && !todosLosItemsBebidaCompletados) {
        customMessage = 'Faltan ítems de bebida';
      }

      // Mostrar un diálogo de error o SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(customMessage),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      return; // No continuar con el diálogo
    }

    // Proceder con el diálogo normal si la orden está lista o se está cancelando
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    status == 'completado' ? Colors.green : Colors.red,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (widget.onStatusChange != null) {
                  widget.onStatusChange!(status);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderProgressIndicator(
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    // Contar ítems de comida y bebida
    int totalComida = 0;
    int totalBebida = 0;
    int completedComida = 0;
    int completedBebida = 0;

    for (var item in items) {
      if (item['tipo'] == 'comida') {
        totalComida++;
        if (item['completado_cocinero'] ?? false) {
          completedComida++;
        }
      } else if (item['tipo'] == 'bebida') {
        totalBebida++;
        if (item['completado_barista'] ?? false) {
          completedBebida++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progreso del pedido:',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),

        // Indicador para ítems de comida
        if (totalComida > 0) ...[
          Row(
            children: [
              Icon(
                Icons.restaurant,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Comida:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedComida/$totalComida completados',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                completedComida == totalComida
                                    ? Colors.green
                                    : theme.colorScheme.primary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value:
                            totalComida > 0
                                ? completedComida / totalComida
                                : 0.0,
                        backgroundColor: Colors.grey.withAlpha(51),
                        color:
                            completedComida == totalComida
                                ? Colors.green
                                : theme.colorScheme.primary,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        // Indicador para ítems de bebida
        if (totalBebida > 0) ...[
          Row(
            children: [
              Icon(
                Icons.local_cafe,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Bebida:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedBebida/$totalBebida completados',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                completedBebida == totalBebida
                                    ? Colors.green
                                    : theme.colorScheme.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value:
                            totalBebida > 0
                                ? completedBebida / totalBebida
                                : 0.0,
                        backgroundColor: Colors.grey.withAlpha(51),
                        color:
                            completedBebida == totalBebida
                                ? Colors.green
                                : theme.colorScheme.secondary,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        // Mensaje de estado general
        if (totalComida > 0 || totalBebida > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _isOrderFullyCompleted(
                      completedComida,
                      totalComida,
                      completedBebida,
                      totalBebida,
                    )
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                size: 14,
                color:
                    _isOrderFullyCompleted(
                          completedComida,
                          totalComida,
                          completedBebida,
                          totalBebida,
                        )
                        ? Colors.green
                        : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                _getOrderProgressMessage(
                  completedComida,
                  totalComida,
                  completedBebida,
                  totalBebida,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      _isOrderFullyCompleted(
                            completedComida,
                            totalComida,
                            completedBebida,
                            totalBebida,
                          )
                          ? Colors.green
                          : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool _isOrderFullyCompleted(
    int completedComida,
    int totalComida,
    int completedBebida,
    int totalBebida,
  ) {
    bool comidaCompleta = totalComida == 0 || completedComida == totalComida;
    bool bebidaCompleta = totalBebida == 0 || completedBebida == totalBebida;
    return comidaCompleta && bebidaCompleta;
  }

  String _getOrderProgressMessage(
    int completedComida,
    int totalComida,
    int completedBebida,
    int totalBebida,
  ) {
    bool comidaCompleta = totalComida == 0 || completedComida == totalComida;
    bool bebidaCompleta = totalBebida == 0 || completedBebida == totalBebida;

    if (comidaCompleta && bebidaCompleta) {
      return 'Pedido listo para ser completado';
    } else if (!comidaCompleta && !bebidaCompleta) {
      return 'Falta completar ítems de comida y bebida';
    } else if (!comidaCompleta) {
      return 'Falta completar ítems de comida';
    } else {
      return 'Falta completar ítems de bebida';
    }
  }

  // Método para verificar si una orden está lista para ser completada
  bool _isOrderReadyToComplete(List<Map<String, dynamic>> items) {
    bool hayComida = false;
    bool hayBebida = false;
    bool todosItemsComidaCompletados = true;
    bool todosItemsBebidaCompletados = true;

    // Verificar cada item
    for (var item in items) {
      final tipo = item['tipo']?.toString().toLowerCase() ?? '';

      if (tipo == 'comida') {
        hayComida = true;
        final completadoCocinero = item['completado_cocinero'] ?? false;
        if (!completadoCocinero) {
          todosItemsComidaCompletados = false;
        }
      } else if (tipo == 'bebida') {
        hayBebida = true;
        final completadoBarista = item['completado_barista'] ?? false;
        if (!completadoBarista) {
          todosItemsBebidaCompletados = false;
        }
      }
    }

    // Aplicar las reglas definidas:

    // Si no hay ítems de ningún tipo (caso raro), no está lista
    if (!hayComida && !hayBebida) {
      return false;
    }

    // Si ambos tipos están presentes y todos están completados
    if (hayComida &&
        hayBebida &&
        todosItemsComidaCompletados &&
        todosItemsBebidaCompletados) {
      return true; // cook completado = true y barista completado = true => completado
    }

    // Si solo hay comida y todos los ítems están completados
    if (hayComida && !hayBebida && todosItemsComidaCompletados) {
      return true; // Sólo comida y completada => completado
    }

    // Si solo hay bebida y todos los ítems están completados
    if (!hayComida && hayBebida && todosItemsBebidaCompletados) {
      return true; // Sólo bebida y completada => completado
    }

    // En cualquier otro caso, no está lista para completarse
    return false;
  }

  bool hayComidaYBebida(List<Map<String, dynamic>> items) {
    bool hayComida = false;
    bool hayBebida = false;

    for (var item in items) {
      final tipo = item['tipo']?.toString().toLowerCase() ?? '';
      if (tipo == 'comida') hayComida = true;
      if (tipo == 'bebida') hayBebida = true;
      if (hayComida && hayBebida) return true;
    }

    return hayComida && hayBebida;
  }

  Widget _buildProgressIndicator(List<Map<String, dynamic>> items) {
    // Contar ítems de comida y bebida
    int totalComida = 0;
    int completedComida = 0;
    int totalBebida = 0;
    int completedBebida = 0;

    for (var item in items) {
      final tipo = item['tipo']?.toString().toLowerCase() ?? '';
      final completadoCocinero = item['completado_cocinero'] ?? false;
      final completadoBarista = item['completado_barista'] ?? false;

      if (tipo == 'comida') {
        totalComida++;
        if (completadoCocinero) completedComida++;
      } else if (tipo == 'bebida') {
        totalBebida++;
        if (completadoBarista) completedBebida++;
      }
    }

    final bool comidaCompleta =
        totalComida == 0 || completedComida == totalComida;
    final bool bebidaCompleta =
        totalBebida == 0 || completedBebida == totalBebida;

    final mensaje = _getOrderProgressMessage(
      completedComida,
      totalComida,
      completedBebida,
      totalBebida,
    );
    final Color colorMensaje =
        comidaCompleta && bebidaCompleta ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorMensaje.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorMensaje.withAlpha(76), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                comidaCompleta && bebidaCompleta
                    ? Icons.check_circle_outline
                    : Icons.pending_outlined,
                size: 14,
                color: colorMensaje,
              ),
              const SizedBox(width: 4),
              Text(
                mensaje,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorMensaje,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              // Indicador de cocinero
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: 12,
                      color: comidaCompleta ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: LinearProgressIndicator(
                        value:
                            totalComida > 0
                                ? completedComida / totalComida
                                : 1.0,
                        backgroundColor: Colors.grey.withAlpha(51),
                        color: comidaCompleta ? Colors.green : Colors.orange,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completedComida/$totalComida',
                      style: TextStyle(
                        fontSize: 10,
                        color: comidaCompleta ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Indicador de barista
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.local_cafe,
                      size: 12,
                      color: bebidaCompleta ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: LinearProgressIndicator(
                        value:
                            totalBebida > 0
                                ? completedBebida / totalBebida
                                : 1.0,
                        backgroundColor: Colors.grey.withAlpha(51),
                        color: bebidaCompleta ? Colors.green : Colors.orange,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completedBebida/$totalBebida',
                      style: TextStyle(
                        fontSize: 10,
                        color: bebidaCompleta ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Método para construir el botón de completar todos los ítems
  Widget _buildCompleteItemsButton(
    List<Map<String, dynamic>> items,
    String role,
    ThemeData theme,
  ) {
    final String tipo = role == 'cook' ? 'comida' : 'bebida';

    // Contar ítems pendientes del tipo correspondiente
    int totalItems = 0;
    int pendingItems = 0;

    for (var item in items) {
      if (item['tipo']?.toString().toLowerCase() == tipo) {
        totalItems++;
        final bool isCompleted =
            tipo == 'comida'
                ? (item['completado_cocinero'] ?? false)
                : (item['completado_barista'] ?? false);

        if (!isCompleted) {
          pendingItems++;
        }
      }
    }

    // Si no hay ítems pendientes, mostrar botón desactivado
    if (pendingItems == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Todos los ítems de ${tipo == 'comida' ? 'comida' : 'bebida'} completados',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Si hay ítems pendientes, mostrar botón activo
    return ElevatedButton.icon(
      onPressed: () => _completeAllItemsOfType(tipo),
      icon: Icon(role == 'cook' ? Icons.restaurant : Icons.coffee, size: 18),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Completar ${pendingItems == 1 ? "1 ítem" : "$pendingItems ítems"} de ${tipo == 'comida' ? 'comida' : 'bebida'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$pendingItems/$totalItems',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minimumSize: Size(double.infinity, 48),
      ),
    );
  }

  // Método para formatear la hora de completado de un ítem
  String _formatItemCompletionTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }
}
