import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../Api_services/user_service.dart';
import './add_user_modal.dart';
import './filter_chip.dart';
import '../../../UI_Screens/Widgets/background_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      // Usar siempre la IP fija
      const String fixedIp = '192.168.1.121';
      final prefs = await SharedPreferences.getInstance();

      // Guardar en ambas claves para futura consistencia
      await prefs.setString('server_ip', fixedIp);
      await prefs.setString('serverIp', fixedIp);

      print('🔌 Intentando conectar con el servidor: $fixedIp');

      // Verificar que el servicio esté disponible haciendo un ping
      bool serverAlive = false;
      try {
        final pingResponse = await http
            .get(Uri.parse('http://$fixedIp:3000/pedidos/stats/count'))
            .timeout(const Duration(seconds: 3));

        serverAlive =
            pingResponse.statusCode >= 200 && pingResponse.statusCode < 300;
        print(
          '🔄 Ping al servidor: ${pingResponse.statusCode} (${serverAlive ? "✅ Conectado" : "❌ Error"})',
        );
      } catch (e) {
        print('⚠️ Error de conexión en ping al servidor: $e');
      }

      // Intentar cargar usuarios desde el servicio
      final usersData = await _userService.getAllUsers();
      print('📋 Datos recibos para usuarios: ${usersData.length} registros');

      final users = usersData.map((data) => User.fromJson(data)).toList();

      if (users.isNotEmpty) {
        print('👥 Usuarios procesados: ${users.length}');
        for (var user in users) {
          print(
            '  - ${user.nombreCompleto} (${user.email}): id=${user.id}, rol=${user.rol} (${user.rolNombre})',
          );
        }
      } else {
        print('⚠️ No se pudieron obtener usuarios del servicio principal');

        // Intento alternativo directamente usando HTTP si el servidor está disponible
        if (serverAlive) {
          try {
            print('🔄 Intento directo a la API de usuarios...');
            final directResponse = await http
                .get(
                  Uri.parse('http://$fixedIp:3000/users'),
                  headers: {'Content-Type': 'application/json'},
                )
                .timeout(const Duration(seconds: 5));

            if (directResponse.statusCode == 200) {
              final List<dynamic> directData = json.decode(directResponse.body);
              print(
                '📤 Datos obtenidos directamente: ${directData.length} registros',
              );

              final directUsers =
                  directData
                      .map(
                        (data) => User.fromJson(data as Map<String, dynamic>),
                      )
                      .toList();

              print(
                '👥 Usuarios procesados directamente: ${directUsers.length}',
              );

              if (mounted) {
                setState(() {
                  _users = directUsers;
                  _applyFilters();
                  _isLoading = false;
                });
                return; // Salir si tuvimos éxito con la conexión directa
              }
            } else {
              print(
                '❌ Error en respuesta directa: ${directResponse.statusCode}',
              );
            }
          } catch (directError) {
            print('❌ Error en conexión directa: $directError');
          }
        }
      }

      // Obtener el ID del usuario actual
      final currentUserId = prefs.getInt('user_id');
      print(
        '🔑 ID del usuario actual (SharedPreferences): $currentUserId (${currentUserId.runtimeType})',
      );

      if (mounted) {
        setState(() {
          _users = users;
          _currentUserId = currentUserId;
          _applyFilters(); // Aplicar filtros iniciales
          _isLoading = false;
        });
      }

      // Mensaje informativo cuando no hay usuarios
      if (users.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverAlive
                  ? 'No se encontraron usuarios en la base de datos. ¿Has registrado alguno?'
                  : 'No se pudo conectar al servidor ($fixedIp:3000). Comprueba que el servidor esté activo.',
            ),
            backgroundColor: serverAlive ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al cargar usuarios: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar(
          'Error al cargar usuarios. Comprueba que el servidor esté activo (192.168.1.121:3000)',
        );
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
                      // Prevenir enfoque automático
                      autofocus: false,
                      focusNode: FocusNode(),
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

                  // Mostrar mensaje cuando no hay usuarios
                  _filteredUsers.isEmpty
                      ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron usuarios',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedRoles.isNotEmpty
                                    ? 'Intenta con otros filtros de búsqueda'
                                    : 'No hay usuarios registrados o no se pudo conectar al servidor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              if (_searchQuery.isNotEmpty ||
                                  _selectedRoles.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedRoles.clear();
                                      _searchController.clear();
                                      _applyFilters();
                                    });
                                  },
                                  icon: const Icon(Icons.filter_alt_off),
                                  label: const Text('Limpiar filtros'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB85C38),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      : Expanded(child: _buildUserList()),
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
          if (_isExpanded) // Solo renderizar cuando está expandido
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Administrador
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    // Delay para el primer botón
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
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
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    // Delay para el segundo botón
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
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
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    // Delay para el tercer botón
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
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
            margin: const EdgeInsets.only(bottom: 20, right: 6),
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
    final contrasenaController = TextEditingController();

    // Valor inicial para el rol
    int selectedRol = user.rol;
    // Estado para controlar la visibilidad de la contraseña
    bool obscurePassword = true;

    // Usar un StatefulBuilder que está desacoplado del contexto original
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (builderContext, setStateLocal) => AlertDialog(
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
                      SizedBox(height: 12),

                      // Campo de contraseña con botón para mostrar/ocultar
                      TextField(
                        controller: contrasenaController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          hintText: 'Dejar en blanco para no cambiar',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              // Usar setState local del StatefulBuilder
                              setStateLocal(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
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
                          // Usar setState local del StatefulBuilder
                          setStateLocal(() {
                            selectedRol = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Guardar los valores primero
                      final nombre = nombreController.text;
                      final apellido = apellidoController.text;
                      final cedula = cedulaController.text;
                      final email = emailController.text;
                      final contrasena = contrasenaController.text;
                      final rol = selectedRol;

                      // Cerrar diálogo de edición
                      Navigator.pop(dialogContext);

                      // Mostrar diálogo de confirmación
                      showDialog(
                        context: context,
                        builder:
                            (confirmContext) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              title: Text(
                                '¿Confirmar cambios?',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Estás seguro que deseas guardar los cambios para este usuario?',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Color(
                                        user.rolColor,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(
                                          user.rolColor,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Color(
                                                user.rolColor,
                                              ),
                                              child: _getRoleIcon(
                                                user.rolIcono,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                user.nombreCompleto,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Text(
                                          'Nombre: $nombre $apellido',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Cédula: $cedula',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Email: $email',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Rol: ${_getRoleName(rol)}',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        if (contrasena.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.key,
                                                  size: 16,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                ),
                                                SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    'Se cambiará la contraseña',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                  onPressed: () {
                                    Navigator.pop(confirmContext);

                                    // Liberar controladores
                                    nombreController.dispose();
                                    apellidoController.dispose();
                                    cedulaController.dispose();
                                    emailController.dispose();
                                    contrasenaController.dispose();
                                  },
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontFamily: 'MADE TOMMY',
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(confirmContext);

                                    // Liberar controladores
                                    nombreController.dispose();
                                    apellidoController.dispose();
                                    cedulaController.dispose();
                                    emailController.dispose();
                                    contrasenaController.dispose();

                                    // Realizar actualización
                                    _updateUser(
                                      user.id,
                                      nombre,
                                      apellido,
                                      cedula,
                                      email,
                                      rol,
                                      contrasena,
                                    );
                                  },
                                  child: Text('Confirmar'),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Text(
                      'Guardar',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
        );
      },
    );
  }

  // Obtener el nombre del rol basado en el valor entero
  String _getRoleName(int rol) {
    switch (rol) {
      case 0:
        return 'Administrador';
      case 1:
        return 'Cliente';
      case 2:
        return 'Cocinero';
      case 3:
        return 'Barista';
      default:
        return 'Cliente';
    }
  }

  // Actualizar usuario en la base de datos
  void _updateUser(
    int userId,
    String nombre,
    String apellido,
    String cedula,
    String email,
    int rol,
    String contrasena,
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

      // Solo añadir contraseña si se ha proporcionado una nueva
      if (contrasena.isNotEmpty) {
        userData['contrasena'] = contrasena;
      }

      // Llamar al servicio para actualizar el usuario
      await _userService.updateUser(userId.toString(), userData);

      // Cerrar el diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      // Recargar la lista de usuarios
      await _loadUsers();

      // Mostrar diálogo de éxito
      showDialog(
        context: context,
        builder:
            (successContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                '¡Cambios Realizados!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 70,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Los cambios al usuario han sido realizados exitosamente.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: Size(120, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(successContext);
                    },
                    child: Text(
                      'Aceptar',
                      style: TextStyle(fontFamily: 'MADE TOMMY'),
                    ),
                  ),
                ),
              ],
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: EdgeInsets.only(bottom: 16),
            ),
      );
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

  Widget _buildUserList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _filteredUsers.isEmpty
        ? _buildEmptyState()
        : RefreshIndicator(
          onRefresh: _loadUsers,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: ListView.builder(
              key: ValueKey<int>(_filteredUsers.length),
              padding: const EdgeInsets.only(
                bottom: 20,
              ), // Espacio para la navegación
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                // Usar AnimatedOpacity para animar la entrada de las tarjetas
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.easeInOut,
                  child: _buildUserCard(user, Theme.of(context)),
                );
              },
            ),
          ),
        );
  }

  // Diálogo para configurar la IP del servidor
  void _showConfigDialog(String currentIp) {
    // Siempre usar la IP fija 192.168.1.121
    const String fixedIp = '192.168.1.121';
    final TextEditingController ipController = TextEditingController(
      text: fixedIp,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Configuración del Servidor'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'La aplicación está configurada para conectarse al servidor usando la dirección IP $fixedIp.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección IP',
                    hintText: '192.168.1.121',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false, // Deshabilitar la edición
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('server_ip', fixedIp);
                  await prefs.setString('serverIp', fixedIp);

                  if (!mounted) return;
                  Navigator.pop(context);

                  // Mostrar mensaje de confirmación
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Usando la IP fija del servidor: 192.168.1.121',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Recargar los usuarios
                  _loadUsers();
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
  }
}
