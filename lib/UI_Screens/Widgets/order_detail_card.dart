import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';
import 'custom_modal.dart'; // Importar nuestro modal personalizado

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
      final String itemName = item['nombre'] ?? 'Ítem';

      // Determinar el rol adecuado para la actualización según el tipo de ítem
      // Si es administrador, usar el rol correspondiente según el tipo de ítem
      String roleForUpdate;
      if (widget.role == 'admin') {
        roleForUpdate = tipo == 'comida' ? 'cook' : 'barista';
      } else {
        roleForUpdate = widget.role ?? (tipo == 'comida' ? 'cook' : 'barista');
      }

      // Mostrar modal de confirmación antes de marcar como completado
      if (completado) {
        final confirm = await CustomModal.showConfirmation(
          context: context,
          title: 'Completar ítem',
          message: '¿Estás seguro de marcar "$itemName" como completado?',
          confirmText: 'Completar',
          confirmColor: Colors.green,
        );

        if (!confirm) return; // El usuario canceló la acción
      }

      final success = await _ordersService.updateItemStatus(
        widget.order['idpedido'],
        platoId,
        completado,
        roleForUpdate, // Usar el rol correcto
      );

      if (success && mounted) {
        await CustomModal.showSuccess(
          context: context,
          message:
              completado
                  ? 'Ítem marcado como completado'
                  : 'Ítem marcado como pendiente',
          buttonText: 'Aceptar',
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
        await CustomModal.showError(
          context: context,
          message: 'Error al actualizar estado: $e',
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

      // Contar items pendientes
      int pendingItems = 0;
      for (var item in items) {
        if (item['tipo']?.toString().toLowerCase() == tipo.toLowerCase()) {
          final bool isAlreadyCompleted =
              tipo == 'comida'
                  ? (item['completado_cocinero'] ?? false)
                  : (item['completado_barista'] ?? false);
          if (!isAlreadyCompleted) pendingItems++;
        }
      }

      // Mostrar confirmación
      final confirm = await CustomModal.showConfirmation(
        context: context,
        title: 'Completar todos los ítems',
        message:
            '¿Estás seguro de marcar todos los ítems de ${tipo == 'comida' ? 'comida' : 'bebida'} ($pendingItems) como completados?',
        confirmText: 'Completar todos',
        confirmColor: Colors.green,
      );

      if (!confirm) return; // Usuario canceló la acción

      bool atLeastOneUpdated = false;

      // Determinar el rol a usar para la actualización
      final String roleToUse = tipo == 'comida' ? 'cook' : 'barista';

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
              roleToUse, // Usar siempre el rol correcto según el tipo
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

        await CustomModal.showSuccess(context: context, message: mensaje);

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
        await CustomModal.showError(
          context: context,
          message: 'Error al actualizar los ítems: $e',
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
    final isStaffRole = widget.role == 'cook' || widget.role == 'barista';

    // Si es cocinero, solo necesitamos mostrar ítems de comida
    // Si es barista, solo necesitamos mostrar ítems de bebida
    final filteredItems =
        isStaffRole
            ? items.where((item) {
              final tipo = item['tipo']?.toString().toLowerCase() ?? '';
              return widget.role == 'cook'
                  ? tipo == 'comida'
                  : tipo == 'bebida';
            }).toList()
            : items;

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

              // Indicador de progreso simplificado para roles de staff
              if (estado.toLowerCase() == 'pendiente' && items.isNotEmpty) ...[
                if (isStaffRole)
                  _buildSimplifiedProgressForStaff(items, theme)
                else
                  _buildOrderProgressIndicator(items, theme),
                const SizedBox(height: 8),
              ],

              // Información del cliente (no tan relevante para staff, pero mantenida por contexto)
              if (!isStaffRole || widget.isExpanded) ...[
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
              ],

              // Botones de acción para roles específicos (cook/barista)
              if (isStaffRole && filteredItems.isNotEmpty) ...[
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

              // Si está expandido, mostrar los items
              if (widget.isExpanded && filteredItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isStaffRole
                          ? 'Items para ${widget.role == 'cook' ? 'cocina' : 'barra'}'
                          : 'Detalle del pedido',
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 12),
                    ),

                    // Contador de items pendientes para roles de staff
                    if (isStaffRole)
                      _buildPendingItemsCount(filteredItems, theme),
                  ],
                ),

                const SizedBox(height: 4),

                // Usamos un widget diferente para los roles de staff
                isStaffRole
                    ? _buildStaffItemsList(filteredItems, theme)
                    : _buildFullItemsList(items, theme),

                const SizedBox(height: 10),
                const Divider(height: 1),

                // Total solo visible para admin
                if (!isStaffRole) ...[
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
                ],

                // Botones de acción para administradores
                if (widget.role == 'admin' &&
                    widget.onRefresh != null &&
                    estado != 'completado' &&
                    estado != 'cancelado') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (estado == 'pendiente') ...[
                        // Verificar si el pedido está completamente procesado
                        if (_isOrderReadyToComplete(items)) ...[
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
                // Vista resumida cuando no está expandido
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isStaffRole
                            ? '${filteredItems.length} ${filteredItems.length == 1 ? 'ítem' : 'ítems'} para ${widget.role == 'cook' ? 'preparar' : 'servir'}'
                            : '${items.length} ${items.length == 1 ? 'ítem' : 'ítems'} en total',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isStaffRole)
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

  // Método para mostrar un contador simplificado de items pendientes
  Widget _buildPendingItemsCount(
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    int pendingItems = 0;
    int totalItems = items.length;

    for (var item in items) {
      final bool isCompleted =
          widget.role == 'cook'
              ? (item['completado_cocinero'] ?? false)
              : (item['completado_barista'] ?? false);

      if (!isCompleted) pendingItems++;
    }

    final color = pendingItems == 0 ? Colors.green : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        pendingItems == 0 ? 'Completado' : '$pendingItems pendientes',
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  // Lista de ítems para roles de staff (cocinero o barista)
  Widget _buildStaffItemsList(
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    final isCocinero = widget.role == 'cook';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCocinero ? 'Platos para cocinar:' : 'Bebidas para preparar:',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final bool isCompleted =
              isCocinero
                  ? (item['completado_cocinero'] ?? false)
                  : (item['completado_barista'] ?? false);

          return Card(
            color: theme.colorScheme.surface,
            elevation: 0.5,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color:
                    isCompleted
                        ? Colors.green.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap:
                  isCompleted
                      ? null // Desactivar la interacción si ya está completado
                      : () => _updateItemStatus(item['idplato'], true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Nombre e información del ítem
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['nombre']} (${item['cantidad']})',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  isCompleted
                                      ? Colors.green
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (item['notas'] != null &&
                              item['notas'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Notas: ${item['notas']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Checkbox para marcar como completado
                    Checkbox(
                      value: isCompleted,
                      onChanged:
                          isCompleted
                              ? null // Desactivar cambio si ya está completado
                              : (value) {
                                if (value != null && value == true) {
                                  _updateItemStatus(item['idplato'], true);
                                }
                              },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // Lista completa para administradores
  Widget _buildFullItemsList(
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle del pedido:',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final tipo = item['tipo']?.toString().toLowerCase() ?? '';
          final bool isComida = tipo == 'comida';
          final bool isCompleted =
              isComida
                  ? (item['completado_cocinero'] ?? false)
                  : (item['completado_barista'] ?? false);

          return Card(
            color: theme.colorScheme.surface,
            elevation: 0.5,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color:
                    isCompleted
                        ? Colors.green.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap:
                  isCompleted
                      ? null // Desactivar la interacción si ya está completado
                      : () => _updateItemStatus(item['idplato'], true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Ícono según tipo
                    Icon(
                      isComida ? Icons.restaurant : Icons.local_cafe,
                      color:
                          isComida
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    // Nombre e información del ítem
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['nombre']} (${item['cantidad']})',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  isCompleted
                                      ? Colors.green
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isComida ? 'Comida' : 'Bebida',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isComida
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item['notas'] != null &&
                              item['notas'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Notas: ${item['notas']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Checkbox para marcar como completado
                    if (widget.role ==
                        'admin') // Solo mostrar checkbox si es admin
                      Checkbox(
                        value: isCompleted,
                        onChanged:
                            isCompleted
                                ? null // Desactivar cambio si ya está completado
                                : (value) {
                                  if (value != null && value == true) {
                                    _updateItemStatus(item['idplato'], true);
                                  }
                                },
                        activeColor: Colors.green,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // Indicador de progreso simplificado para los roles de staff
  Widget _buildSimplifiedProgressForStaff(
    List<Map<String, dynamic>> items,
    ThemeData theme,
  ) {
    // Filtrar solo los items relevantes para el rol actual
    final String tipo = widget.role == 'cook' ? 'comida' : 'bebida';

    int total = 0;
    int completed = 0;

    for (var item in items) {
      if (item['tipo']?.toString().toLowerCase() == tipo) {
        total++;
        final bool isCompleted =
            widget.role == 'cook'
                ? (item['completado_cocinero'] ?? false)
                : (item['completado_barista'] ?? false);

        if (isCompleted) completed++;
      }
    }

    // Si no hay items de este tipo, no mostrar nada
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'No hay items de ${tipo == 'comida' ? 'comida' : 'bebida'} en este pedido',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final double progress = total > 0 ? completed / total : 0.0;
    final bool isComplete = completed == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.role == 'cook' ? Icons.restaurant : Icons.local_cafe,
              size: 14,
              color: isComplete ? Colors.green : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '$completed/$total ${widget.role == 'cook' ? 'comidas' : 'bebidas'} completadas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isComplete ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: isComplete ? Colors.green : theme.colorScheme.primary,
            minHeight: 6,
          ),
        ),
      ],
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
    final theme = Theme.of(context); // Obtener el tema actual

    // Si estamos intentando completar, verificar primero si está todo listo
    if (status == 'completado') {
      bool todosCompletados = _isOrderReadyToComplete(items);

      if (!todosCompletados) {
        // Ofrecer completar todos los ítems automáticamente
        CustomModal.showConfirmation(
          context: context,
          title: 'Completar pedido',
          message:
              'Hay ítems pendientes. ¿Deseas marcar todos como completados y finalizar el pedido?',
          confirmText: 'Completar todo',
          cancelText: 'Cancelar',
          confirmColor: Colors.green,
        ).then((confirmed) async {
          if (confirmed) {
            // Mostrar indicador de carga estilizado con el tema
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Completando ítems...',
                        style: TextStyle(
                          fontFamily: 'MADE TOMMY',
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(8),
                  elevation: 4,
                ),
              );
            }

            // Completar todos los ítems directamente sin confirmaciones adicionales
            await _completarItemsDirectamente(items);

            // Actualizar estado del pedido completo
            if (widget.onStatusChange != null) {
              widget.onStatusChange!(status);
            }
          }
        });
      } else {
        // Si ya está todo completo, solo confirmar la finalización
        CustomModal.showConfirmation(
          context: context,
          title: title,
          message: message,
          confirmText: 'Confirmar',
          cancelText: 'Cancelar',
          confirmColor: Colors.green,
        ).then((confirmed) {
          if (confirmed && widget.onStatusChange != null) {
            widget.onStatusChange!(status);
          }
        });
      }

      return; // No continuar con el diálogo estándar
    }

    // Proceder con el diálogo de confirmación para cancelación
    if (status == 'cancelado') {
      CustomModal.showConfirmation(
        context: context,
        title: title,
        message: message,
        confirmText: 'Confirmar',
        cancelText: 'Cancelar',
        confirmColor: Colors.red,
      ).then((confirmed) {
        if (confirmed && widget.onStatusChange != null) {
          widget.onStatusChange!(status);
        }
      });
    }
  }

  // Método para completar todos los ítems directamente sin confirmaciones adicionales
  Future<void> _completarItemsDirectamente(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      // 1. Encontrar todos los ítems por completar, agrupados por tipo
      final itemsComidaPendientes = <int>[];
      final itemsBebidaPendientes = <int>[];

      for (var item in items) {
        final tipo = item['tipo']?.toString().toLowerCase() ?? '';
        final int platoId = item['idplato'] ?? 0;

        if (tipo == 'comida' && !(item['completado_cocinero'] ?? false)) {
          itemsComidaPendientes.add(platoId);
        } else if (tipo == 'bebida' && !(item['completado_barista'] ?? false)) {
          itemsBebidaPendientes.add(platoId);
        }
      }

      // 2. Completar ítems de comida
      for (int platoId in itemsComidaPendientes) {
        await _ordersService.updateItemStatus(
          widget.order['idpedido'],
          platoId,
          true,
          'cook',
        );
      }

      // 3. Completar ítems de bebida
      for (int platoId in itemsBebidaPendientes) {
        await _ordersService.updateItemStatus(
          widget.order['idpedido'],
          platoId,
          true,
          'barista',
        );
      }

      // 4. Verificar si todo está listo para completar el pedido
      await _ordersService.checkAndUpdateOrderCompletion(
        widget.order['idpedido'],
      );

      // 5. Refrescar interfaz
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    } catch (e) {
      debugPrint('❌ Error al completar ítems directamente: $e');
      if (mounted) {
        final theme = Theme.of(context); // Obtener el tema actual

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onError),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al completar los ítems',
                    style: TextStyle(
                      fontFamily: 'MADE TOMMY',
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            elevation: 4,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
              Expanded(
                child: Text(
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
                  overflow: TextOverflow.ellipsis,
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
      return 'Pedido listo';
    } else if (!comidaCompleta && !bebidaCompleta) {
      return 'Faltan ítems de comida y bebida';
    } else if (!comidaCompleta) {
      return 'Faltan ítems de comida';
    } else {
      return 'Faltan ítems de bebida';
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
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorMensaje,
                  ),
                  overflow: TextOverflow.ellipsis,
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
