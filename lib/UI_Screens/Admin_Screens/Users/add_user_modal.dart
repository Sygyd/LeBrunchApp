import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../Api_services/user_service.dart';

class AddUserModal extends StatefulWidget {
  final Function(User) onUserAdded;
  final int? initialRol;

  const AddUserModal({super.key, required this.onUserAdded, this.initialRol});

  @override
  State<AddUserModal> createState() => _AddUserModalState();
}

class _AddUserModalState extends State<AddUserModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userService = UserService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  int _selectedRole = 1; // Cliente por defecto
  bool _isLoading = false;
  bool _passwordVisible = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Si hay un rol inicial, usarlo
    if (widget.initialRol != null) {
      _selectedRole = widget.initialRol!;
    }

    // Configurar animaciones
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Iniciar animación
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Obtener color según el rol seleccionado
  Color _getRoleColor() {
    switch (_selectedRole) {
      case 0:
        return const Color(0xFF9C27B0); // Admin - morado
      case 2:
        return const Color(0xFFE57373); // Cocinero - rojo
      case 3:
        return const Color(0xFF4DD0E1); // Barista - azul
      case 1:
      default:
        return const Color(0xFF2196F3); // Cliente - azul
    }
  }

  // Obtener icono según el rol seleccionado
  IconData _getRoleIcon() {
    switch (_selectedRole) {
      case 0:
        return Icons.admin_panel_settings;
      case 2:
        return Icons.restaurant;
      case 3:
        return Icons.coffee;
      case 1:
      default:
        return Icons.person;
    }
  }

  // Mostrar el título según el rol seleccionado
  String get _dialogTitle {
    switch (_selectedRole) {
      case 0:
        return 'Agregar Administrador';
      case 2:
        return 'Agregar Cocinero';
      case 3:
        return 'Agregar Barista';
      case 1:
      default:
        return 'Agregar Usuario';
    }
  }

  // Procesar el envío del formulario
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Asegurar que estamos usando el rol correcto
        int rolToUse = widget.initialRol ?? _selectedRole;
        print('Creando usuario con rol: $rolToUse'); // Debug

        // Crear los datos del usuario en formato adecuado para la API
        final userData = {
          'nombre': _nameController.text.trim(),
          'apellido': _lastNameController.text.trim(),
          'cedula': _idNumberController.text.trim(),
          'email': _emailController.text.trim(),
          'contrasena': _passwordController.text,
          'rol':
              rolToUse
                  .toString(), // Convertir a string para asegurar compatibilidad
        };

        final user = await _userService.addUser(userData);

        // Crear un modelo de usuario a partir de los datos devueltos
        final newUser = User(
          id: user['idpersona'] ?? 0,
          nombre: user['nombre'] ?? '',
          apellido: user['apellido'] ?? '',
          cedula: user['cedula'] ?? '',
          email: user['email'] ?? '',
          rol: rolToUse, // Usar el mismo rol que enviamos
        );

        if (mounted) {
          // Animar salida antes de cerrar el diálogo
          await _animationController.reverse();
          if (mounted) {
            Navigator.of(context).pop();
            widget.onUserAdded(newUser);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
          _showErrorMessage();
        }
      } finally {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      }
    }
  }

  // Mostrar mensaje de error
  void _showErrorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $_errorMessage'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _getRoleColor();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: theme.colorScheme.surface,
              child: child,
            ),
          ),
        );
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del diálogo
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getRoleIcon(), color: roleColor, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _dialogTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'MADE TOMMY',
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Selector de rol (solo si no hay un rol preseleccionado)
                if (widget.initialRol == null) ...[
                  Text(
                    'Seleccionar Rol',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'MADE TOMMY',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedRole,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(10),
                        icon: Icon(Icons.arrow_drop_down, color: roleColor),
                        items: [
                          _buildRoleItem(
                            0,
                            'Administrador',
                            Icons.admin_panel_settings,
                            const Color(0xFF9C27B0),
                          ),
                          _buildRoleItem(
                            1,
                            'Cliente',
                            Icons.person,
                            const Color(0xFF2196F3),
                          ),
                          _buildRoleItem(
                            2,
                            'Cocinero',
                            Icons.restaurant,
                            const Color(0xFFE57373),
                          ),
                          _buildRoleItem(
                            3,
                            'Barista',
                            Icons.coffee,
                            const Color(0xFF4DD0E1),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRole = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Campos de información personal
                Text(
                  'Información Personal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
                const SizedBox(height: 16),

                // Nombre y Apellido en fila
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'Nombre',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Apellido',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cédula
                _buildTextField(
                  controller: _idNumberController,
                  label: 'Cédula',
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Campos de cuenta
                Text(
                  'Información de Cuenta',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                _buildTextField(
                  controller: _emailController,
                  label: 'Correo Electrónico',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Requerido';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contraseña
                _buildTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !_passwordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: roleColor.withOpacity(0.7),
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Requerido';
                    }
                    if (value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () async {
                                await _animationController.reverse();
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface
                            .withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontFamily: 'MADE TOMMY',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: roleColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 3,
                      ),
                      child:
                          _isLoading
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                'Guardar',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'MADE TOMMY',
                                ),
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Construir un elemento de la lista desplegable de roles
  DropdownMenuItem<int> _buildRoleItem(
    int value,
    String label,
    IconData icon,
    Color color,
  ) {
    return DropdownMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'MADE TOMMY',
            ),
          ),
        ],
      ),
    );
  }

  // Construir un campo de texto con estilo consistente
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final roleColor = _getRoleColor();

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'MADE TOMMY'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          fontFamily: 'MADE TOMMY',
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: roleColor.withOpacity(0.7),
          size: 22,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: roleColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }
}
