import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../Api_services/user_service.dart';
import './add_user_modal.dart';
import './filter_chip.dart';
import '../../../UI_Screens/Widgets/background_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int? _currentUserId; // ID del usuario actualmente logueado

  // Estado para controlar si el menú está expandido
  bool _isExpanded = false;

  // Set para almacenar los filtros de rol seleccionados
  final Set<int> _selectedRoles = {};

  // Opciones para ordenar usuarios
  String _sortBy = "nombre"; // Por defecto ordenar por nombre
  bool _sortAscending = true; // Por defecto ascendente

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Carga los usuarios desde el servicio
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usersData = await _userService.getAllUsers();
      print('📋 Datos crudos recibidos para usuarios: $usersData');

      final users = usersData.map((data) => User.fromJson(data)).toList();

      print('👥 Usuarios procesados: ${users.length}');
      for (var user in users) {
        print(
          '  - ${user.nombreCompleto} (${user.email}): id=${user.id}, rol=${user.rol} (${user.rolNombre})',
        );
      }

      // Obtener el ID del usuario actual
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id');
      print(
        '🔑 ID del usuario actual (SharedPreferences): $currentUserId (${currentUserId.runtimeType})',
      );

      // Imprimir todas las claves guardadas en SharedPreferences para diagnóstico
      print('🔐 Todas las claves en SharedPreferences:');
      final keys = prefs.getKeys();
      for (var key in keys) {
        print('  - $key: ${prefs.get(key)} (${prefs.get(key)?.runtimeType})');
      }

      // Verificar explícitamente si se pudo obtener el ID
      if (currentUserId == null) {
        print(
          '⚠️ No se pudo obtener el ID del usuario actual - Verificar login.dart',
        );
      }

      if (mounted) {
        setState(() {
          _users = users;
          _currentUserId = currentUserId;
          _applyFilters(); // Aplicar filtros iniciales
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error al cargar usuarios: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error al cargar usuarios: $e');
      }
    }
  }

  // Mostrar SnackBar con mensaje de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Mostrar SnackBar con mensaje de éxito
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // Aplicar filtros de búsqueda, rol y ordenamiento a la lista de usuarios
  void _applyFilters() {
    final query = _searchQuery.toLowerCase();

    print(
      '🔍 Aplicando filtros - Búsqueda: "$query", Roles seleccionados: $_selectedRoles, Ordenado por: $_sortBy (${_sortAscending ? "ASC" : "DESC"})',
    );
    print('📊 Total de usuarios antes de filtrar: ${_users.length}');

    // Paso 1: Filtrar por texto de búsqueda y rol
    final List<User> filtered =
        _users.where((user) {
          // Filtrar por texto de búsqueda
          final matchesQuery =
              query.isEmpty ||
              user.nombreCompleto.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.cedula.contains(query);

          // Filtrar por roles seleccionados (si hay alguno seleccionado)
          final matchesRole =
              _selectedRoles.isEmpty || _selectedRoles.contains(user.rol);

          final matches = matchesQuery && matchesRole;
          print(
            '👤 Usuario: ${user.nombreCompleto}, Rol: ${user.rol} (${user.rolNombre}), Coincide: $matches',
          );

          return matches;
        }).toList();

    // Paso 2: Ordenar la lista filtrada
    filtered.sort((a, b) {
      int compareResult;

      switch (_sortBy) {
        case "cedula":
          compareResult = a.cedula.compareTo(b.cedula);
          break;
        case "email":
          compareResult = a.email.compareTo(b.email);
          break;
        case "nombre":
        default:
          compareResult = a.nombreCompleto.compareTo(b.nombreCompleto);
          break;
      }

      // Invertir el resultado si es orden descendente
      return _sortAscending ? compareResult : -compareResult;
    });

    print('📝 Resultados filtrados: ${filtered.length} usuarios');

    setState(() {
      _filteredUsers = filtered;
    });
  }

  // Agregar o quitar un rol del conjunto de filtros
  void _toggleRoleFilter(int role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
      _applyFilters();
    });
  }

  // Mostrar el diálogo para agregar un nuevo usuario con rol específico
  void _showAddUserModal({int? preselectedRole}) {
    setState(() {
      _isExpanded = false; // Cerrar menú al seleccionar una opción
    });

    showDialog(
      context: context,
      builder:
          (context) => AddUserModal(
            onUserAdded: (User newUser) async {
              print(
                '👤 Usuario agregado: ${newUser.nombreCompleto}, rol: ${newUser.rol} (${newUser.rolNombre})',
              );

              // Recargar todos los usuarios desde el servidor para asegurar que tenemos la lista actual
              await _loadUsers();

              // Mostrar modal de confirmación con el rol del usuario agregado
              if (mounted) {
                _showSuccessModal(newUser);
              }
            },
            initialRol: preselectedRole,
          ),
    );
  }

  // Mostrar modal de confirmación de usuario agregado
  void _showSuccessModal(User user) {
    // Obtener datos del rol para personalizar el modal
    final Color roleColor = Color(user.rolColor);
    final IconData roleIcon = _getRoleIconData(user.rolIcono);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            content: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado con color del rol
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: roleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(roleIcon, color: Colors.white, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          '¡Registro Exitoso!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'MADE TOMMY',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido con detalles del usuario
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Se ha registrado exitosamente:',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'MADE TOMMY',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: roleColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: roleColor,
                                radius: 16,
                                child: Icon(
                                  roleIcon,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.nombreCompleto,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'MADE TOMMY',
                                    ),
                                  ),
                                  Text(
                                    user.rolNombre,
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'MADE TOMMY',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
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
                          child: const Text(
                            'Aceptar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'MADE TOMMY',
                            ),
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
  }

  // Obtener el IconData directamente desde el nombre del icono
  IconData _getRoleIconData(String iconName) {
    switch (iconName) {
      case 'admin_panel_settings':
        return Icons.admin_panel_settings;
      case 'person':
        return Icons.person;
      case 'restaurant':
        return Icons.restaurant;
      case 'coffee':
        return Icons.coffee;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackgroundScaffold(
      body: Stack(
        children: [
          // Contenido principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de búsqueda
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar usuarios...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface.withOpacity(0.7),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                    ),
                  ),

                  // Fila para opciones de filtro y ordenamiento
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        // Dropdown para seleccionar campo de ordenamiento
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: DropdownButton<String>(
                            value: _sortBy,
                            underline: Container(),
                            icon: const Icon(Icons.arrow_drop_down),
                            borderRadius: BorderRadius.circular(10),
                            items: [
                              DropdownMenuItem(
                                value: "nombre",
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 16),
                                    const SizedBox(width: 8),
                                    const Text("Nombre"),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: "cedula",
                                child: Row(
                                  children: [
                                    const Icon(Icons.badge, size: 16),
                                    const SizedBox(width: 8),
                                    const Text("Cédula"),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: "email",
                                child: Row(
                                  children: [
                                    const Icon(Icons.email, size: 16),
                                    const SizedBox(width: 8),
                                    const Text("Email"),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _sortBy = newValue;
                                  _applyFilters();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Botón para alternar orden ascendente/descendente
                        InkWell(
                          onTap: () {
                            setState(() {
                              _sortAscending = !_sortAscending;
                              _applyFilters();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _sortAscending ? "ASC" : "DESC",
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Chip que muestra el conteo de usuarios filtrados
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            "${_filteredUsers.length} usuarios",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chips de filtrado por rol
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          RoleFilterChip(
                            label: 'Administradores',
                            roleId: 0,
                            isSelected: _selectedRoles.contains(0),
                            onSelected: (value) => _toggleRoleFilter(0),
                            color: Color(0xFF9C27B0),
                          ),
                          const SizedBox(width: 8),
                          RoleFilterChip(
                            label: 'Clientes',
                            roleId: 1,
                            isSelected: _selectedRoles.contains(1),
                            onSelected: (value) => _toggleRoleFilter(1),
                            color: Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 8),
                          RoleFilterChip(
                            label: 'Cocineros',
                            roleId: 2,
                            isSelected: _selectedRoles.contains(2),
                            onSelected: (value) => _toggleRoleFilter(2),
                            color: Color(0xFFE57373),
                          ),
                          const SizedBox(width: 8),
                          RoleFilterChip(
                            label: 'Baristas',
                            roleId: 3,
                            isSelected: _selectedRoles.contains(3),
                            onSelected: (value) => _toggleRoleFilter(3),
                            color: Color(0xFF4DD0E1),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),

                  // Lista de usuarios filtrados
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredUsers.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                              onRefresh: _loadUsers,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  bottom: 80,
                                ), // Espacio para la navegación
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  return _buildUserCard(user, theme);
                                },
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),

          // Overlay oscuro cuando el menú está expandido
          if (_isExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                child: AnimatedOpacity(
                  opacity: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(color: Colors.black),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  // Construir botones flotantes con animación de expansión
  Widget _buildFloatingActionButtons() {
    return Container(
      alignment: Alignment.bottomRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Botones de opciones (solo visible cuando está expandido)
          AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Administrador
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _isExpanded ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  // Delay para el primer botón
                  builder: (context, value, child) {
                    // Delay artificial - solo aparece después de 60ms cuando se expande
                    double actualValue =
                        _isExpanded
                            ? (value < 0.2 ? 0.0 : (value - 0.2) / 0.8)
                            : 0.0;

                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - actualValue)),
                      child: Opacity(
                        opacity: actualValue,
                        child: _buildActionButton(
                          icon: Icons.admin_panel_settings,
                          color: const Color(0xFF9C27B0),
                          tooltip: 'Agregar Administrador',
                          onPressed:
                              () => _showAddUserModal(preselectedRole: 0),
                          label: 'Administrador',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Cocinero
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _isExpanded ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  // Delay para el segundo botón
                  builder: (context, value, child) {
                    // Delay artificial - aparece después de 120ms cuando se expande
                    double actualValue =
                        _isExpanded
                            ? (value < 0.4 ? 0.0 : (value - 0.4) / 0.6)
                            : 0.0;

                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - actualValue)),
                      child: Opacity(
                        opacity: actualValue,
                        child: _buildActionButton(
                          icon: Icons.restaurant,
                          color: const Color(0xFFE57373),
                          tooltip: 'Agregar Cocinero',
                          onPressed:
                              () => _showAddUserModal(preselectedRole: 2),
                          label: 'Cocinero',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Barista
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _isExpanded ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  // Delay para el tercer botón
                  builder: (context, value, child) {
                    // Delay artificial - aparece después de 180ms cuando se expande
                    double actualValue =
                        _isExpanded
                            ? (value < 0.6 ? 0.0 : (value - 0.6) / 0.4)
                            : 0.0;

                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - actualValue)),
                      child: Opacity(
                        opacity: actualValue,
                        child: _buildActionButton(
                          icon: Icons.coffee,
                          color: const Color(0xFF4DD0E1),
                          tooltip: 'Agregar Barista',
                          onPressed:
                              () => _showAddUserModal(preselectedRole: 3),
                          label: 'Barista',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Botón principal (siempre visible y en posición fija)
          Container(
            margin: const EdgeInsets.only(bottom: 80, right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      _isExpanded
                          ? Colors.red.withOpacity(0.4)
                          : Theme.of(context).primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Ink(
                  decoration: ShapeDecoration(
                    color:
                        _isExpanded
                            ? Colors.red.shade400
                            : Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      turns:
                          _isExpanded
                              ? 0.125
                              : 0.0, // 45 grados al expandir (convierte + en x)
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Botón de acción para cada rol
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Container(
      width: 200,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(23),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Construir la tarjeta de usuario
  Widget _buildUserCard(User user, ThemeData theme) {
    // Verificación detallada del usuario actual logueado con impresión de debug
    final bool isCurrentUser = user.id == _currentUserId;
    print(
      '🔍 Comparando usuario: ${user.id} con currentUserId: $_currentUserId => isCurrentUser: $isCurrentUser',
    );

    // Color para el icono de eliminar
    final Color deleteIconColor = isCurrentUser ? Colors.grey : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Color(user.rolColor),
          child: _getRoleIcon(user.rolIcono),
        ),
        title: Text(
          user.nombreCompleto + (isCurrentUser ? ' (Tú)' : ''),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Email: ${user.email}', style: theme.textTheme.bodySmall),
            Text('Cédula: ${user.cedula}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(user.rolColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(user.rolColor).withOpacity(0.3),
                ),
              ),
              child: Text(
                user.rolNombre,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Color(user.rolColor),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.info, color: theme.colorScheme.primary),
              onPressed: () {
                _showUserDetails(user);
              },
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.orange),
              onPressed: () {
                _showEditUserForm(user);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: deleteIconColor),
              onPressed:
                  isCurrentUser
                      ? () {
                        // Mostrar mensaje informativo si intentan eliminar al usuario actual
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'No puedes eliminar tu propia cuenta mientras estás conectado',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      : () {
                        _showDeleteConfirmation(user);
                      },
            ),
          ],
        ),
      ),
    );
  }

  // Obtener el widget de icono basado en el nombre del icono
  Widget _getRoleIcon(String iconName) {
    // Usar los mismos iconos que se utilizan en los floating action buttons
    IconData iconData;
    switch (iconName) {
      case 'admin_panel_settings':
        iconData = Icons.admin_panel_settings;
        break;
      case 'person':
        iconData = Icons.person;
        break;
      case 'restaurant':
        iconData = Icons.restaurant;
        break;
      case 'coffee':
        iconData = Icons.coffee;
        break;
      default:
        iconData = Icons.help;
        break;
    }
    return Icon(iconData, color: Colors.white);
  }

  // Construir el estado vacío (cuando no hay usuarios que mostrar)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No se encontraron usuarios',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta cambiar los filtros o agrega nuevos usuarios',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Mostrar detalles del usuario
  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Detalles de Usuario',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('ID', '${user.id}'),
                _buildDetailRow('Nombre', user.nombre),
                _buildDetailRow('Apellido', user.apellido),
                _buildDetailRow('Cédula', user.cedula),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Rol', user.rolNombre),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditUserForm(user);
                },
                child: Text('Editar', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  // Mostrar formulario de edición de usuario
  void _showEditUserForm(User user) {
    // Controladores para los campos de texto
    final nombreController = TextEditingController(text: user.nombre);
    final apellidoController = TextEditingController(text: user.apellido);
    final cedulaController = TextEditingController(text: user.cedula);
    final emailController = TextEditingController(text: user.email);

    // Valor inicial para el rol
    int selectedRol = user.rol;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    'Editar Usuario',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Información del usuario actual con estilo visual
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Color(user.rolColor).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(user.rolColor).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(user.rolColor),
                                child: _getRoleIcon(user.rolIcono),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.nombreCompleto,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'ID: ${user.id}',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Campos de formulario
                        TextField(
                          controller: nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),

                        TextField(
                          controller: apellidoController,
                          decoration: InputDecoration(
                            labelText: 'Apellido',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),

                        TextField(
                          controller: cedulaController,
                          decoration: InputDecoration(
                            labelText: 'Cédula',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),

                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Selector de rol
                        DropdownButtonFormField<int>(
                          value: selectedRol,
                          decoration: InputDecoration(
                            labelText: 'Rol',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Administrador'),
                            ),
                            DropdownMenuItem(value: 1, child: Text('Cliente')),
                            DropdownMenuItem(value: 2, child: Text('Cocinero')),
                            DropdownMenuItem(value: 3, child: Text('Barista')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedRol = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed:
                          () => _updateUser(
                            user.id,
                            nombreController.text,
                            apellidoController.text,
                            cedulaController.text,
                            emailController.text,
                            selectedRol,
                          ),
                      child: Text(
                        'Guardar',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
          ),
    ).then((_) {
      // Liberar los controladores cuando se cierre el diálogo
      nombreController.dispose();
      apellidoController.dispose();
      cedulaController.dispose();
      emailController.dispose();
    });
  }

  // Actualizar usuario en la base de datos
  void _updateUser(
    int userId,
    String nombre,
    String apellido,
    String cedula,
    String email,
    int rol,
  ) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Actualizando usuario...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      final userData = {
        'nombre': nombre,
        'apellido': apellido,
        'cedula': cedula,
        'email': email,
        'rol': rol.toString(), // Convertir a string para el API
      };

      // Llamar al servicio para actualizar el usuario
      await _userService.updateUser(userId.toString(), userData);

      // Cerrar el diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();
      // Cerrar el diálogo de edición
      Navigator.of(context).pop();

      // Recargar la lista de usuarios
      await _loadUsers();

      // Mostrar mensaje de éxito
      _showSuccessSnackBar('Usuario actualizado con éxito');
    } catch (e) {
      // Cerrar el diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      // Mostrar mensaje de error
      _showErrorSnackBar('Error al actualizar usuario: $e');
    }
  }

  // Construir una fila de detalle para el diálogo
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Mostrar confirmación de eliminación de usuario
  void _showDeleteConfirmation(User user) {
    // Verificar si es el usuario actual loggeado
    final bool isCurrentUser = user.id == _currentUserId;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isCurrentUser ? 'No se puede eliminar' : 'Eliminar Usuario',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? Colors.orange : null,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser
                      ? 'No puedes eliminar tu propia cuenta mientras estás conectado.'
                      : '¿Estás seguro que deseas eliminar este usuario?',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(user.rolColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(user.rolColor).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(user.rolColor),
                        radius: 16,
                        child: _getRoleIcon(user.rolIcono),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.nombreCompleto,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              user.rolNombre,
                              style: TextStyle(
                                color: Color(user.rolColor),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isCurrentUser ? 'Entendido' : 'Cancelar'),
              ),
              if (!isCurrentUser)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context); // Cerrar el diálogo

                    // Mostrar indicador de carga
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Eliminando usuario...'),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    try {
                      // Llamar al servicio para eliminar el usuario
                      final bool success = await _userService.deleteUser(
                        user.id.toString(),
                      );

                      // Cerrar el diálogo de carga
                      Navigator.of(context, rootNavigator: true).pop();

                      if (success) {
                        // Actualizar la lista de usuarios
                        await _loadUsers();

                        // Mostrar mensaje de éxito
                        _showSuccessSnackBar('Usuario eliminado con éxito');
                      }
                    } catch (e) {
                      // Cerrar el diálogo de carga
                      Navigator.of(context, rootNavigator: true).pop();

                      // Manejo de errores específicos
                      if (e.toString().contains("propia cuenta") ||
                          e.toString().contains("logueado")) {
                        _showErrorSnackBar(
                          'No puedes eliminar tu propia cuenta mientras estás conectado',
                        );
                      } else {
                        // Mostrar mensaje de error genérico
                        _showErrorSnackBar('Error al eliminar el usuario: $e');
                      }
                    }
                  },
                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
    );
  }
}
