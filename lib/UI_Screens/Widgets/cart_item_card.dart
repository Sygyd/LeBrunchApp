import 'package:flutter/material.dart';
import '../../models/cart_item.dart';

class CartItemCard extends StatefulWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final Function(String?) onUpdateNotes;

  const CartItemCard({
    Key? key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onUpdateNotes,
  }) : super(key: key);

  @override
  State<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends State<CartItemCard> {
  late TextEditingController _notesController;
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: imagen y detalles
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen del producto
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildItemImage(theme),
                ),

                const SizedBox(width: 12),

                // Información del producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre y botón de eliminar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'LightHouse',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: theme.colorScheme.error,
                            tooltip: 'Eliminar del carrito',
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onRemove,
                          ),
                        ],
                      ),

                      // Precio unitario
                      Text(
                        '\$${widget.item.price.toStringAsFixed(2)} c/u',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Control de cantidad
                      Row(
                        children: [
                          _buildQuantityButton(
                            onPressed: widget.onDecrease,
                            icon: Icons.remove,
                            theme: theme,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              '${widget.item.quantity}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          _buildQuantityButton(
                            onPressed: widget.onIncrease,
                            icon: Icons.add,
                            theme: theme,
                          ),

                          const Spacer(),

                          // Precio total
                          Text(
                            '\$${widget.item.totalPrice.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
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

            // Notas
            _buildNotesSection(theme),
          ],
        ),
      ),
    );
  }

  // Widget para la imagen del producto
  Widget _buildItemImage(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          widget.item.imageUrl.isNotEmpty
              ? Image.network(
                widget.item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Icon(
                      Icons.image_not_supported,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              )
              : Icon(
                Icons.fastfood,
                size: 32,
                color: theme.colorScheme.onSurfaceVariant,
              ),
    );
  }

  // Widget para los botones de aumentar/disminuir cantidad
  Widget _buildQuantityButton({
    required VoidCallback onPressed,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        color: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      ),
    );
  }

  // Widget para las notas del producto
  Widget _buildNotesSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child:
          _isEditingNotes
              ? _buildNotesEditor(theme)
              : _buildNotesDisplay(theme),
    );
  }

  Widget _buildNotesDisplay(ThemeData theme) {
    return InkWell(
      onTap: () {
        setState(() {
          _isEditingNotes = true;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.item.notes?.isNotEmpty == true
                    ? widget.item.notes!
                    : 'Añadir instrucciones especiales...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      widget.item.notes?.isNotEmpty == true
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                  fontStyle:
                      widget.item.notes?.isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instrucciones especiales:',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            hintText: 'Ej: Sin cebolla, término medio, etc.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          style: theme.textTheme.bodyMedium,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _notesController.text = widget.item.notes ?? '';
                  _isEditingNotes = false;
                });
              },
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final notes = _notesController.text.trim();
                widget.onUpdateNotes(notes.isEmpty ? null : notes);
                setState(() {
                  _isEditingNotes = false;
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}
