import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Api_services/cart_service.dart';
import '../Widgets/custom_modal.dart';

class DishCard extends StatefulWidget {
  final Map<String, dynamic> dish;
  final int? userRole;
  final Function(Map<String, dynamic>)? editDish;
  final Function(String)? deleteDish;
  final double? parentWidth;
  final bool initialExpanded;
  final Function(bool) onToggleExpanded;

  const DishCard({
    Key? key,
    required this.dish,
    required this.userRole,
    this.editDish,
    this.deleteDish,
    this.parentWidth,
    this.initialExpanded = false,
    required this.onToggleExpanded,
  }) : super(key: key);

  @override
  State<DishCard> createState() => _DishCardState();
}

class _DishCardState extends State<DishCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  // Para almacenar referencias a widgets ancestros de forma segura
  ScaffoldMessengerState? _scaffoldMessenger;
  NavigatorState? _navigator;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Almacenar referencias a widgets ancestros mientras el widget está activo
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    _navigator = Navigator.of(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Método para mostrar un snackbar de forma segura
  void _showSnackBar(String message, {SnackBarAction? action}) {
    if (_scaffoldMessenger != null) {
      // Crear una acción segura si se proporciona una
      SnackBarAction? safeAction;

      if (action != null) {
        safeAction = SnackBarAction(
          label: action.label,
          onPressed: () {
            // Llamar primero al callback original
            action.onPressed();
          },
        );
      }

      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text(message),
          action: safeAction,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para navegar de forma segura
  void _navigateTo(String route) {
    if (_navigator != null && _navigator!.mounted) {
      _navigator!.pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price =
        widget.dish['precio'] != null
            ? double.tryParse(widget.dish['precio'].toString()) ?? 0.0
            : 0.0;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
          _controller.forward();
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
          _controller.reverse();
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              color: theme.colorScheme.surface,
              surfaceTintColor: theme.colorScheme.surfaceTint,
              elevation: _isHovered ? 6 : 1,
              shadowColor: theme.colorScheme.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      _isHovered
                          ? theme.colorScheme.primary.withOpacity(0.3)
                          : Colors.transparent,
                  width: 1.5,
                ),
              ),
              margin: const EdgeInsets.all(4),
              child: InkWell(
                onTap: () => _showDetailModal(context),
                borderRadius: BorderRadius.circular(16),
                splashColor: theme.colorScheme.primary.withOpacity(0.1),
                highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Imagen más grande
                    Hero(
                      tag: 'dish-image-${widget.dish['idplato']}',
                      child: Container(
                        width: double.infinity,
                        height: 200, // Ajuste del tamaño de la imagen
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildDishImage(
                          context,
                          theme,
                          double.infinity,
                          140,
                        ),
                      ),
                    ),
                    // Contenido compacto con colores del tema
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre y precio en la misma línea
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.dish['nombre'] ?? 'Sin nombre',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontFamily: 'LightHouse',
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'MADE TOMMY',
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Indicador de disponibilidad mejorado
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (widget.dish['disponibilidad'] ?? false)
                                      ? const Color(0xFF3EA69B)
                                      : theme.colorScheme.error.withOpacity(
                                        0.1,
                                      ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (widget.dish['disponibilidad'] ?? false)
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color:
                                      (widget.dish['disponibilidad'] ?? false)
                                          ? theme.colorScheme.primaryContainer
                                          : theme.colorScheme.error,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  (widget.dish['disponibilidad'] ?? false)
                                      ? 'Disponible'
                                      : 'No disponible',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        (widget.dish['disponibilidad'] ?? false)
                                            ? theme.colorScheme.primaryContainer
                                            : theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Resto del código sin cambios
  void _showDetailModal(BuildContext context) {
    final theme = Theme.of(context);
    final price =
        widget.dish['precio'] != null
            ? double.tryParse(widget.dish['precio'].toString()) ?? 0.0
            : 0.0;

    // Notificar al padre que se abrió el modal
    widget.onToggleExpanded(true);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: theme.colorScheme.surface,
          elevation: 8,
          shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 30,
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 550, minWidth: 300),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado con título y botón de cerrar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.dish['nombre'] ?? 'Sin nombre',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFamily: 'LightHouse',
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onToggleExpanded(false);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Imagen centrada y grande
                    Center(
                      child: Hero(
                        tag: 'dish-image-${widget.dish['idplato']}',
                        child: Container(
                          width: double.infinity,
                          height: 250, // Tamaño ajustado
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.15,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildDishImage(
                            context,
                            theme,
                            double.infinity,
                            250,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Disponibilidad y precio
                    _buildAvailabilityAndPrice(context, theme, price),

                    Divider(
                      height: 40,
                      thickness: 1,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),

                    // Contenido
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección de ingredientes
                        _buildInfoSection(
                          context,
                          'Ingredientes:',
                          widget.dish['ingredientes'] ?? 'No especificados',
                          Icons.rice_bowl_outlined,
                        ),

                        // Sección de descripción (si existe)
                        if (widget.dish['descripcion'] != null &&
                            widget.dish['descripcion'].toString().isNotEmpty)
                          _buildInfoSection(
                            context,
                            'Descripción:',
                            widget.dish['descripcion'] ?? '',
                            Icons.description_outlined,
                          ),
                      ],
                    ),

                    // Botones de acción según el rol
                    if (widget.userRole == 0) ...[
                      // Botones de administrador
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.editDish?.call(widget.dish);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.deleteDish?.call(
                                widget.dish['idplato'].toString(),
                              );
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Eliminar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (widget.userRole == 1 &&
                        (widget.dish['disponibilidad'] ?? false)) ...[
                      // Botón de agregar al carrito para cliente
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Agregar al carrito
                            _addToCart(context);
                          },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Agregar al Pedido'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) => widget.onToggleExpanded(false));
  }

  // Método para añadir al carrito
  void _addToCart(BuildContext context) {
    // Datos del plato
    final id = widget.dish['idplato'].toString();
    final name = widget.dish['nombre'] ?? 'Producto sin nombre';
    final price =
        widget.dish['precio'] != null
            ? double.tryParse(widget.dish['precio'].toString()) ?? 0.0
            : 0.0;
    final imageUrl = widget.dish['imagen_url'] ?? '';

    // Agregar al carrito usando el servicio de carrito
    final cartService = CartService();
    cartService.addItem(
      id: id,
      name: name,
      price: price,
      imageUrl: imageUrl,
      originalData: widget.dish,
    );

    // Cerrar el diálogo
    Navigator.of(context).pop();

    // Mostrar modal de confirmación
    CustomModal.showSuccess(
      context: context,
      title: '¡Añadido al Carrito!',
      message: '$name ha sido añadido a tu pedido',
      buttonText: 'Ver Carrito',
      onPressed: () {
        // Navegar a la pantalla del carrito
        _navigateTo('/cart');
      },
    );
  }

  // Nuevo método para construir secciones de información
  Widget _buildInfoSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir la imagen del plato
  Widget _buildDishImage(
    BuildContext context,
    ThemeData theme,
    double width,
    double height,
  ) {
    return widget.dish['imagen_url'] != null &&
            widget.dish['imagen_url'].isNotEmpty
        ? CachedNetworkImage(
          imageUrl: widget.dish['imagen_url'],
          fit: BoxFit.cover,
          width: width,
          height: height,
          placeholder:
              (context, url) => Container(
                color: theme.colorScheme.surfaceVariant,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          errorWidget:
              (context, url, error) => Container(
                color: theme.colorScheme.surfaceVariant,
                child: Icon(
                  Icons.fastfood,
                  size: height * 0.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 100),
        )
        : Container(
          color: theme.colorScheme.surfaceVariant,
          child: Icon(
            Icons.image_not_supported,
            size: height * 0.4,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
  }

  // Método para construir la información de disponibilidad y precio
  Widget _buildAvailabilityAndPrice(
    BuildContext context,
    ThemeData theme,
    double price,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Disponibilidad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                (widget.dish['disponibilidad'] ?? false)
                    ? const Color(0xFF3EA69B)
                    : theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  (widget.dish['disponibilidad'] ?? false)
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.error,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                (widget.dish['disponibilidad'] ?? false)
                    ? Icons.check_circle
                    : Icons.cancel,
                color:
                    (widget.dish['disponibilidad'] ?? false)
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                (widget.dish['disponibilidad'] ?? false)
                    ? 'Disponible'
                    : 'No disponible',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      (widget.dish['disponibilidad'] ?? false)
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Precio
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_money,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                price.toStringAsFixed(2),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'MADE TOMMY',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
