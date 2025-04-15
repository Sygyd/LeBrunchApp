import 'package:flutter/material.dart';

class RoleFilterChip extends StatelessWidget {
  final String label;
  final int roleId;
  final bool isSelected;
  final Function(bool) onSelected;
  final Color color;

  const RoleFilterChip({
    super.key,
    required this.label,
    required this.roleId,
    required this.isSelected,
    required this.onSelected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 12,
        child: Icon(_getRoleIcon(), color: Colors.white, size: 12),
      ),
      selectedColor: color.withOpacity(0.2),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.withOpacity(0.3),
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? color : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onSelected: onSelected,
    );
  }

  // Obtener icono basado en el rol
  IconData _getRoleIcon() {
    switch (roleId) {
      case 0:
        return Icons.admin_panel_settings;
      case 1:
        return Icons.person;
      case 2:
        return Icons.restaurant;
      case 3:
        return Icons.coffee;
      default:
        return Icons.people;
    }
  }
}
