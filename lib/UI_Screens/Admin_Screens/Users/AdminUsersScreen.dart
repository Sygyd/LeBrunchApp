import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user.dart';
import '../../../Api_services/user_service.dart';
import './add_user_modal.dart';
import './filter_chip.dart';
import '../../../UI_Screens/Widgets/background_scaffold.dart';
import '../../../UI_Screens/Widgets/custom_modal.dart';
import 'package:http/http.dart' as http;

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
  bool _currentUserIsSuperAdmin =
      false; // Flag para identificar si el usuario actual es super admin

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
    print('🚀 Iniciando AdminUsersScreen...');
    _loadCurrentUserInfo().then((_) {
      print('📊 Estado después de cargar info del usuario:');
      print('   ID actual: $_currentUserId');
      print('   Es Super Admin: $_currentUserIsSuperAdmin');
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Verificar los permisos del usuario actual
  Future<void> _loadCurrentUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id');
      final isSuperAdmin = prefs.getBool('is_super_admin') ?? false;
      final userRole = prefs.getInt('user_rol');
      final userName = prefs.getString('user_name');

      print('🔑 Datos del usuario desde SharedPreferences:');
      print('   user_id: $currentUserId');
      print('   is_super_admin: $isSuperAdmin');
      print('   user_rol: $userRole');
      print('   user_name: $userName');

      setState(() {
        _currentUserId = currentUserId;
        _currentUserIsSuperAdmin = isSuperAdmin;
      });

      print('🔑 Permisos del usuario actual:');
      print('   ID: $currentUserId');
      print('   Es Super Admin: $isSuperAdmin');

      // Verificar si el rol es admin (0) en caso de que is_super_admin sea false
      if (!isSuperAdmin && userRole == 0) {
        print('   ✓ Usuario es admin normal (rol 0)');
      } else if (!isSuperAdmin && userRole != 0) {
        print('   ⚠️ Usuario NO es admin (rol $userRole)');
      }
    } catch (e) {
      print('❌ Error verificando permisos: $e');
    }
  }

  // Carga los usuarios desde el servicio
  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final usersData = await _userService.getAllUsers();
      final List<User> users =
          usersData.map((data) => User.fromJson(data)).toList();
      print('📥 Usuarios cargados desde la API: ${users.length}');

      // Debug específico: listar todos los usuarios administrativos
      print('👑 DEBUG CARGA: Usuarios administrativos encontrados:');
      for (final user in users) {
        if (user.rol == "00" || user.rol == "0") {
          print(
            '   - ${user.nombreCompleto}: rol="${user.rol}" (${user.rolNombre})',
          );
        }
      }

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      print('❌ Error al cargar usuarios: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorModal(
          'Error al cargar usuarios. Comprueba que el servidor esté activo (192.168.1.121:3000)',
        );
      }
    }
  }

  // Mostrar modal con mensaje de error
  void _showErrorModal(String message) {
    CustomModal.showError(context: context, message: message);
  }

  // Mostrar modal con mensaje de éxito
  void _showSuccessMessage(String message) {
    CustomModal.showSuccess(context: context, message: message);
  }

  // Función helper para ordenar roles respetando la jerarquía correcta
  int _compareRoles(String rolA, String rolB) {
    // Definir el orden de prioridad: Super Admin (00) -> Admin (0) -> Cliente (1) -> Cook (2) -> Barista (3)
    const Map<String, int> rolePriority = {
      '00': 0, // Super Admin - mayor prioridad (más pequeño = primero)
      '0': 1, // Admin
      '1': 2, // Cliente
      '2': 3, // Cocinero
      '3': 4, // Barista
    };

    final int priorityA =
        rolePriority[rolA] ?? 999; // Si no se encuentra, poner al final
    final int priorityB = rolePriority[rolB] ?? 999;

    final result = priorityA.compareTo(priorityB);

    print(
      '🏆 _compareRoles: "$rolA" (prioridad $priorityA) vs "$rolB" (prioridad $priorityB) = $result',
    );

    // Explicación del resultado
    if (result < 0) {
      print('   → "$rolA" tiene mayor prioridad que "$rolB" (viene ANTES)');
    } else if (result > 0) {
      print('   → "$rolB" tiene mayor prioridad que "$rolA" (viene ANTES)');
    } else {
      print('   → "$rolA" y "$rolB" tienen la misma prioridad');
    }

    // Debug específico para Super Admin
    if (rolA == "00" || rolB == "00") {
      print('🚨 SUPER ADMIN DETECTADO en comparación!');
      if (rolA == "00" && rolB == "0") {
        print('🚨 Comparando Super Admin (00) vs Admin (0)');
        print('   Super Admin prioridad: 0, Admin prioridad: 1');
        print('   Resultado: $result (negativo = Super Admin primero) ✅');
      } else if (rolA == "0" && rolB == "00") {
        print('🚨 Comparando Admin (0) vs Super Admin (00)');
        print('   Admin prioridad: 1, Super Admin prioridad: 0');
        print('   Resultado: $result (positivo = Super Admin primero) ✅');
      } else if (rolA == "00") {
        print(
          '🚨 Super Admin vs ${rolB}: Super Admin debería ganar (resultado negativo)',
        );
      } else if (rolB == "00") {
        print(
          '🚨 ${rolA} vs Super Admin: Super Admin debería ganar (resultado positivo)',
        );
      }
    }

    return result;
  }

  // Aplicar filtros de búsqueda y ordenamiento
  void _applyFilters() {
    print(
      '🔍 ================== INICIO DEBUG APLICAR FILTROS ==================',
    );
    print('🔍 Aplicando filtros...');
    final String query = _searchQuery.toLowerCase();
    print('📊 Total de usuarios antes de filtrar: ${_users.length}');
    print('🔄 Ordenando por: $_sortBy (${_sortAscending ? "ASC" : "DESC"})');
    print('🎯 Roles seleccionados: $_selectedRoles');

    // Debug específico: mostrar todos los usuarios Super Admin o Admin
    print('👑 USUARIOS CON ROL ADMINISTRATIVO EN LA BASE:');
    for (final user in _users) {
      if (user.rol == "00" || user.rol == "0") {
        print(
          '   - ${user.nombreCompleto}: rol="${user.rol}" (${user.rolNombre})',
        );
      }
    }

    // Paso 1: Filtrar por texto de búsqueda y rol
    final List<User> filtered =
        _users.where((user) {
          // Filtrar por texto de búsqueda
          final matchesQuery =
              query.isEmpty ||
              user.nombreCompleto.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.cedula.contains(query);

          // Convertir el rol del usuario (string) a entero para comparar con _selectedRoles
          // NOTA ESPECIAL: Super Admin ("00") se trata como administrador (0) para efectos de filtrado
          int userRolInt;
          if (user.rol == "00") {
            userRolInt =
                0; // Super Admin se considera como administrador para filtrado
          } else {
            userRolInt =
                int.tryParse(user.rol) ?? 1; // Default a cliente si falla
          }

          // Filtrar por roles seleccionados (si hay alguno seleccionado)
          final matchesRole =
              _selectedRoles.isEmpty || _selectedRoles.contains(userRolInt);

          final matches = matchesQuery && matchesRole;

          // Debug específico para usuarios administrativos
          if (user.rol == "00" || user.rol == "0") {
            print('🔍 ADMIN/SUPER DEBUG: ${user.nombreCompleto}');
            print('   - Rol original: "${user.rol}"');
            print('   - Rol int para filtro: $userRolInt');
            print('   - Coincide con query: $matchesQuery');
            print('   - Coincide con rol: $matchesRole');
            print('   - ¿Pasa filtro final?: $matches');
          }

          return matches;
        }).toList();

    print('📝 Usuarios después del filtrado: ${filtered.length}');

    // Debug: mostrar usuarios filtrados antes del ordenamiento
    if (filtered.isNotEmpty) {
      print('👥 USUARIOS FILTRADOS (antes de ordenar):');
      for (int i = 0; i < filtered.length; i++) {
        final user = filtered[i];
        print(
          '   ${i + 1}. ${user.nombreCompleto} - Rol: "${user.rol}" (${user.rolNombre})',
        );
      }
    }

    // Paso 2: Ordenar la lista filtrada
    print('🔄 ================== INICIO ORDENAMIENTO ==================');

    filtered.sort((a, b) {
      int compareResult;

      print(
        '🔄 Comparando: ${a.nombreCompleto} (rol:"${a.rol}") vs ${b.nombreCompleto} (rol:"${b.rol}")',
      );

      switch (_sortBy) {
        case "rol":
          // Para ordenamiento por rol, usar ÚNICAMENTE la jerarquía de roles (sin otros criterios)
          compareResult = _compareRoles(a.rol, b.rol);
          print('🔄 Ordenando por ROL PURO: resultado = $compareResult');
          break;

        case "nombre":
          // Para ordenamiento por nombre, usar comparación case-insensitive
          compareResult = a.nombreCompleto.toLowerCase().compareTo(
            b.nombreCompleto.toLowerCase(),
          );
          if (compareResult == 0) {
            compareResult = _compareRoles(a.rol, b.rol);
          }
          print(
            '🔄 Ordenando por NOMBRE (case-insensitive): resultado = $compareResult',
          );
          break;

        case "cedula":
          // Para ordenamiento por cédula, usar cédula como criterio principal
          compareResult = a.cedula.compareTo(b.cedula);
          if (compareResult == 0) {
            compareResult = _compareRoles(a.rol, b.rol);
          }
          print('🔄 Ordenando por CEDULA: resultado = $compareResult');
          break;

        case "email":
          // Para ordenamiento por email, usar email como criterio principal (case-insensitive)
          compareResult = a.email.toLowerCase().compareTo(
            b.email.toLowerCase(),
          );
          if (compareResult == 0) {
            compareResult = _compareRoles(a.rol, b.rol);
          }
          print(
            '🔄 Ordenando por EMAIL (case-insensitive): resultado = $compareResult',
          );
          break;

        default:
          // Por defecto, ordenar por nombre con jerarquía de roles como desempate (case-insensitive)
          compareResult = a.nombreCompleto.toLowerCase().compareTo(
            b.nombreCompleto.toLowerCase(),
          );
          if (compareResult == 0) {
            compareResult = _compareRoles(a.rol, b.rol);
          }
          print(
            '🔄 Ordenando por DEFAULT (nombre case-insensitive): resultado = $compareResult',
          );
          break;
      }

      // Aplicar orden ascendente o descendente
      final finalResult = _sortAscending ? compareResult : -compareResult;
      print('🔄 Resultado final (con ASC/DESC aplicado): $finalResult');
      print('🔄 ========================================');

      return finalResult;
    });

    print('🔄 ================== FIN ORDENAMIENTO ==================');
    print('📝 Resultados filtrados: ${filtered.length} usuarios');
    print('🏷️ Roles seleccionados: $_selectedRoles');

    // Mostrar el orden final para debugging con más detalle
    print('📋 ================== ORDEN FINAL ==================');
    for (int i = 0; i < filtered.length && i < 10; i++) {
      final user = filtered[i];
      String destacado = "";
      if (user.rol == "00") {
        destacado = " ⭐ SUPER ADMIN ⭐";
      } else if (user.rol == "0") {
        destacado = " 🔑 ADMIN";
      }
      print(
        '   ${i + 1}. ${user.nombreCompleto} - Rol: "${user.rol}" (${user.rolNombre})$destacado',
      );
    }
    print('📋 ================== FIN DEBUG ==================');

    setState(() {
      _filteredUsers = filtered;
    });
  }

  // Agregar o quitar un rol del conjunto de filtros
  void _toggleRoleFilter(int role) {
    print('🎯 Toggle filter para rol: $role');
    print('🎯 Estado actual de _selectedRoles: $_selectedRoles');

    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
        print('🎯 Removido rol $role de filtros activos');
      } else {
        _selectedRoles.add(role);
        print('🎯 Agregado rol $role a filtros activos');

        // Debug: mostrar qué usuarios coincidirán con este filtro
        if (role == 0) {
          final matchingUsers =
              _users
                  .where((user) => user.rol == "0" || user.rol == "00")
                  .toList();
          print('🎯 Filtro Administradores (0) incluirá:');
          for (final user in matchingUsers) {
            print('   - ${user.nombreCompleto} (rol: "${user.rol}")');
          }
        }
      }
      print('🎯 Nuevo estado de _selectedRoles: $_selectedRoles');
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
    final IconData roleIcon = _getRoleIconData(user.rolIcon);

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
          // Contenido principal con scroll unificado
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Barra de búsqueda como sliver
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),

                  // Fila de opciones de filtro y ordenamiento como sliver
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          // Dropdown para seleccionar campo de ordenamiento
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.3,
                                ),
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
                                DropdownMenuItem(
                                  value: "rol",
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.admin_panel_settings,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text("Rol"),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  print('🔄 Dropdown de ordenamiento cambiado');
                                  print('🔄 Valor anterior: $_sortBy');
                                  print('🔄 Nuevo valor: $newValue');
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
                              print('🔄 Toggle ASC/DESC presionado');
                              print(
                                '🔄 Estado anterior: ${_sortAscending ? "ASC" : "DESC"}',
                              );
                              setState(() {
                                _sortAscending = !_sortAscending;
                                print(
                                  '🔄 Nuevo estado: ${_sortAscending ? "ASC" : "DESC"}',
                                );
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
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
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
                  ),

                  // Chips de filtrado por rol como sliver
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),

                  // Lista de usuarios o estado vacío como sliver
                  _filteredUsers.isEmpty
                      ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 80,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedRoles.isNotEmpty
                                    ? 'No se encontraron usuarios'
                                    : 'No hay usuarios registrados',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedRoles.isNotEmpty
                                    ? 'Prueba ajustando los filtros'
                                    : 'Agrega el primer usuario usando el botón +',
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 24),
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
                      : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final user = _filteredUsers[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: _buildUserCard(user, theme),
                          );
                        }, childCount: _filteredUsers.length),
                      ),
                ],
              ),
            ),
          ),

          // Backdrop semi-transparente cuando está expandido
          if (_isExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                child: Container(
                  // CORRECCIÓN: Eliminado AnimatedOpacity problemático
                  color: Colors.black.withOpacity(0.3), // Opacidad fija
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Administrador
                _buildActionButton(
                  icon: Icons.admin_panel_settings,
                  color: const Color(0xFF9C27B0),
                  tooltip: 'Agregar Administrador',
                  onPressed: () => _showAddUserModal(preselectedRole: 0),
                  label: 'Administrador',
                ),
                const SizedBox(height: 12),
                // Cocinero
                _buildActionButton(
                  icon: Icons.restaurant,
                  color: const Color(0xFFE57373),
                  tooltip: 'Agregar Cocinero',
                  onPressed: () => _showAddUserModal(preselectedRole: 2),
                  label: 'Cocinero',
                ),
                const SizedBox(height: 12),
                // Barista
                _buildActionButton(
                  icon: Icons.coffee,
                  color: const Color(0xFF4DD0E1),
                  tooltip: 'Agregar Barista',
                  onPressed: () => _showAddUserModal(preselectedRole: 3),
                  label: 'Barista',
                ),
                const SizedBox(
                  height: 20,
                ), // Más espacio para evitar la bottom nav bar
              ],
            ),

          // Botón principal (siempre visible y en posición fija)
          Container(
            margin: const EdgeInsets.only(
              bottom: 80,
              right: 6,
            ), // Aumentado para evitar la bottom nav bar
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
                    child: Icon(Icons.add, color: Colors.white, size: 28),
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
      width: 180, // Reducido para mejor ajuste en pantallas pequeñas
      height: 48, // Ligeramente más alto para mejor toque
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
    final bool isCurrentUser = user.id == _currentUserId;
    final bool canDeleteThisUser = _canDeleteUser(user);
    final bool canEditThisUser = _canEditUser(user);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation:
          user.isSuperAdmin == true ? 8 : 3, // Más elevación para super admin
      shadowColor:
          user.isSuperAdmin == true
              ? Color(user.rolColor).withOpacity(0.5)
              : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            user.isSuperAdmin == true
                ? BorderSide(color: Color(user.rolColor), width: 2)
                : BorderSide.none,
      ),
      child: Container(
        decoration:
            user.isSuperAdmin == true
                ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Color(user.rolColor).withOpacity(0.1),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
                : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: Color(user.rolColor),
                radius: 24,
                child: Icon(
                  _getRoleIcon(user.rolIcon),
                  color: Colors.white,
                  size: user.isSuperAdmin == true ? 28 : 24,
                ),
              ),
              // Corona/escudo para super admin
              if (user.isSuperAdmin == true)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  user.nombreCompleto,
                  style: TextStyle(
                    fontWeight:
                        user.isSuperAdmin == true
                            ? FontWeight.bold
                            : FontWeight.w600,
                    fontSize: user.isSuperAdmin == true ? 16 : 15,
                  ),
                ),
              ),
              if (isCurrentUser)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tú',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Color(user.rolColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(user.rolColor).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      user.rolNombre,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(user.rolColor),
                      ),
                    ),
                  ),
                  if (user.isSuperAdmin == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield, color: Colors.amber, size: 12),
                          SizedBox(width: 2),
                          Text(
                            'SUPER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de editar (solo si tiene permisos)
              if (canEditThisUser)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditUserDialog(user),
                  tooltip: 'Editar usuario',
                ),
              // Botón de eliminar (solo si tiene permisos y no es super admin)
              if (canDeleteThisUser && user.isSuperAdmin != true)
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    size: 20,
                    color: isCurrentUser ? Colors.grey : Colors.red,
                  ),
                  onPressed:
                      isCurrentUser
                          ? null
                          : () => _showDeleteConfirmation(user),
                  tooltip:
                      isCurrentUser
                          ? 'No puedes eliminarte'
                          : 'Eliminar usuario',
                ),
              // Indicador de protección para super admin
              if (user.isSuperAdmin == true)
                Tooltip(
                  message: 'Super Administrador - Protegido contra eliminación',
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Verificar si el usuario actual puede eliminar a otro usuario
  bool _canDeleteUser(User targetUser) {
    // REGLA 1: Nadie puede eliminar al super admin principal (rol "00")
    if (targetUser.rol == '00') {
      print('❌ No se puede eliminar super admin');
      return false;
    }

    // REGLA 2: El usuario no puede eliminarse a sí mismo
    if (targetUser.id == _currentUserId) {
      print('❌ No se puede auto-eliminar');
      return false;
    }

    // REGLA 3: Solo super admin puede eliminar otros administradores (rol "0")
    if (targetUser.rol == '0' && !_currentUserIsSuperAdmin) {
      print('❌ Solo super admin puede eliminar otros admins');
      return false;
    }

    // REGLA 4: Verificar que el usuario actual tenga permisos de administrador
    final currentUser = _users.firstWhere(
      (u) => u.id == _currentUserId,
      orElse:
          () => User(
            id: -1,
            nombre: '',
            apellido: '',
            email: '',
            cedula: '',
            rol: '',
          ),
    );

    // Solo admins y super admins pueden eliminar usuarios
    final isCurrentUserAdmin =
        currentUser.rol == '0' ||
        currentUser.rol == '00' ||
        _currentUserIsSuperAdmin;
    if (!isCurrentUserAdmin) {
      print('❌ Usuario actual no es admin');
      return false;
    }

    print('✅ Usuario ${targetUser.nombreCompleto} puede ser eliminado');
    return true;
  }

  // Verificar si el usuario actual puede editar a otro usuario
  bool _canEditUser(User targetUser) {
    // REGLA 1: Super admin puede editar a todos (excepto cambiar su propio rol)
    if (_currentUserIsSuperAdmin) {
      print('✅ Super admin puede editar a ${targetUser.nombreCompleto}');
      return true;
    }

    // REGLA 2: Usuario puede editar su propia información básica (no el rol)
    if (targetUser.id == _currentUserId) {
      print('✅ Usuario puede editar su propia información');
      return true;
    }

    // REGLA 3: Verificar si el usuario actual es admin normal (rol "0")
    final currentUser = _users.firstWhere(
      (u) => u.id == _currentUserId,
      orElse:
          () => User(
            id: -1,
            nombre: '',
            apellido: '',
            email: '',
            cedula: '',
            rol: '',
          ),
    );

    // Admin normal (rol "0") puede editar usuarios no-admin (roles 1, 2, 3)
    if (currentUser.rol == '0') {
      // No puede editar super admin ni otros admins
      if (targetUser.rol == '00' || targetUser.rol == '0') {
        print('❌ Admin normal no puede editar super admin u otros admins');
        return false;
      }
      print(
        '✅ Admin normal puede editar usuario no-admin ${targetUser.nombreCompleto}',
      );
      return true;
    }

    // Si no es admin ni super admin, no puede editar a otros
    print(
      '❌ Usuario actual no tiene permisos para editar a ${targetUser.nombreCompleto}',
    );
    return false;
  }

  // Mostrar confirmación de eliminación de usuario (con protecciones mejoradas)
  void _showDeleteConfirmation(User user) {
    // Verificar protecciones adicionales
    final bool isCurrentUser = user.id == _currentUserId;
    final bool isSuperAdmin = user.isSuperAdmin == true;
    final bool isAdmin = user.rol == '0';
    final bool canDelete = _canDeleteUser(user);

    // Determinar el tipo de mensaje según el caso específico
    String title;
    String message;
    Color? titleColor;
    IconData titleIcon = Icons.warning;

    if (isSuperAdmin) {
      title = 'Super Administrador Protegido';
      message =
          'El Super Administrador principal no puede ser eliminado por razones de seguridad del sistema.\n\nEsta protección es fundamental para mantener la integridad del sistema.';
      titleColor = Colors.amber[700];
      titleIcon = Icons.shield;
    } else if (isCurrentUser) {
      title = 'No Puedes Eliminarte';
      message =
          'No puedes eliminar tu propia cuenta mientras estás conectado al sistema.\n\nSi necesitas eliminar tu cuenta, solicita ayuda al Super Administrador.';
      titleColor = Colors.orange;
      titleIcon = Icons.person_off;
    } else if (isAdmin && !_currentUserIsSuperAdmin) {
      title = 'Administrador Protegido';
      message =
          'Solo el Super Administrador puede eliminar otros administradores.\n\nEsta restricción protege la estructura administrativa del sistema.';
      titleColor = Colors.red[700];
      titleIcon = Icons.admin_panel_settings;
    } else if (!canDelete) {
      title = 'Sin Permisos';
      message =
          'No tienes permisos suficientes para eliminar usuarios.\n\nSolo los administradores pueden realizar esta acción.';
      titleColor = Colors.red[700];
      titleIcon = Icons.no_accounts;
    } else {
      title = 'Confirmar Eliminación';
      message =
          '¿Estás seguro que deseas eliminar este usuario?\n\nEsta acción marcará al usuario como eliminado pero conservará sus datos por seguridad.';
      titleColor = null;
      titleIcon = Icons.delete_outline;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(titleIcon, color: titleColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 14)),
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
                      Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(user.rolColor),
                            radius: 16,
                            child: Icon(
                              _getRoleIcon(user.rolIcon),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          if (user.isSuperAdmin == true)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.nombreCompleto,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              user.rolNombre,
                              style: TextStyle(
                                color: Color(user.rolColor),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'ID: ${user.id}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Mostrar información adicional sobre permisos si es relevante
                if (!canDelete && !isSuperAdmin && !isCurrentUser) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentUserIsSuperAdmin
                                ? 'Tienes permisos completos de Super Administrador'
                                : 'Tu rol actual permite eliminar solo usuarios no-administrativos',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(canDelete ? 'Cancelar' : 'Entendido'),
              ),
              if (canDelete && !isSuperAdmin && !isCurrentUser)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Cerrar el diálogo

                    // Mostrar indicador de carga
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Dialog(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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

                      // Verificar si el widget sigue montado antes de usar Navigator
                      if (!mounted) return;

                      // Cerrar el diálogo de carga
                      Navigator.of(context, rootNavigator: true).pop();

                      if (success) {
                        // Actualizar la lista de usuarios
                        await _loadUsers();

                        // Mostrar mensaje de éxito
                        if (mounted) {
                          _showSuccessMessage('Usuario eliminado con éxito');
                        }
                      }
                    } catch (e) {
                      // Verificar si el widget sigue montado antes de usar Navigator
                      if (!mounted) return;

                      // Cerrar el diálogo de carga
                      Navigator.of(context, rootNavigator: true).pop();

                      // Manejo de errores específicos basados en los códigos del servidor
                      String errorMessage = 'Error al eliminar el usuario';

                      final errorString = e.toString().toLowerCase();

                      if (errorString.contains("superadmin_protegido") ||
                          errorString.contains("super administrador")) {
                        errorMessage =
                            'El Super Administrador no puede ser eliminado';
                      } else if (errorString.contains("autoeliminar") ||
                          errorString.contains("propia cuenta")) {
                        errorMessage =
                            'No puedes eliminar tu propia cuenta mientras estás conectado';
                      } else if (errorString.contains("sin_permisos") ||
                          errorString.contains("permisos")) {
                        errorMessage =
                            'No tienes permisos para eliminar este usuario';
                      } else if (errorString.contains("sin_permisos_admin")) {
                        errorMessage =
                            'Solo el Super Administrador puede eliminar otros administradores';
                      } else if (errorString.contains("token_invalido")) {
                        errorMessage =
                            'Tu sesión ha expirado. Por favor, inicia sesión nuevamente';
                      } else if (errorString.contains("sin_autorizacion")) {
                        errorMessage =
                            'No tienes autorización para realizar esta acción';
                      }

                      if (mounted) {
                        _showErrorModal(errorMessage);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Eliminar'),
                ),
            ],
          ),
    );
  }

  // Mostrar diálogo de edición de usuario con protecciones para super admin
  void _showEditUserDialog(User user) {
    // Verificar permisos antes de mostrar el diálogo
    final bool canEdit = _canEditUser(user);
    final bool isCurrentUser = user.id == _currentUserId;
    final bool isSuperAdmin = user.isSuperAdmin == true;

    if (!canEdit) {
      _showErrorModal('No tienes permisos para editar este usuario');
      return;
    }

    // Controladores para los campos de texto
    final nombreController = TextEditingController(text: user.nombre);
    final apellidoController = TextEditingController(text: user.apellido);
    final cedulaController = TextEditingController(text: user.cedula);
    final emailController = TextEditingController(text: user.email);
    final contrasenaController = TextEditingController();

    // Valor inicial para el rol
    String selectedRol = user.rol;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (builderContext, setStateLocal) => AlertDialog(
                title: Row(
                  children: [
                    if (isSuperAdmin) ...[
                      const Icon(Icons.shield, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        'Editar Usuario',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSuperAdmin ? Colors.amber[700] : null,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Información del usuario actual
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Color(user.rolColor).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(user.rolColor).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Color(user.rolColor),
                                  child: Icon(
                                    _getRoleIcon(user.rolIcon),
                                    color: Colors.white,
                                  ),
                                ),
                                if (isSuperAdmin)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.nombreCompleto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${user.id}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Aviso de protección para super admin
                      if (isSuperAdmin)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'El rol del Super Administrador no puede ser modificado',
                                  style: TextStyle(
                                    color: Colors.amber[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Campos de formulario
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: apellidoController,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: cedulaController,
                        decoration: const InputDecoration(
                          labelText: 'Cédula',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Campo de contraseña
                      TextField(
                        controller: contrasenaController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          hintText: 'Dejar en blanco para no cambiar',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setStateLocal(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de rol (con restricciones corregidas)
                      DropdownButtonFormField<String>(
                        value: selectedRol,
                        decoration: InputDecoration(
                          labelText: 'Rol',
                          border: const OutlineInputBorder(),
                          // Lógica de permisos para editar roles:
                          // - Solo super admin puede cambiar roles
                          // - Super admin no puede cambiar su propio rol
                          // - Nadie puede asignar rol de super admin excepto super admin
                          enabled:
                              _currentUserIsSuperAdmin &&
                              !isSuperAdmin &&
                              !isCurrentUser,
                          helperText: _getRoleEditHelperText(
                            isSuperAdmin,
                            isCurrentUser,
                          ),
                          helperMaxLines: 2,
                        ),
                        items: _buildRoleDropdownItems(),
                        onChanged:
                            (_currentUserIsSuperAdmin &&
                                    !isSuperAdmin &&
                                    !isCurrentUser)
                                ? (value) {
                                  setStateLocal(() {
                                    selectedRol = value!;
                                  });
                                }
                                : null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      final nombre = nombreController.text.trim();
                      final apellido = apellidoController.text.trim();
                      final cedula = cedulaController.text.trim();
                      final email = emailController.text.trim();
                      final contrasena = contrasenaController.text.trim();

                      // Validaciones básicas
                      if (nombre.isEmpty ||
                          apellido.isEmpty ||
                          cedula.isEmpty ||
                          email.isEmpty) {
                        _showErrorModal('Todos los campos son requeridos');
                        return;
                      }

                      Navigator.pop(dialogContext);
                      _updateUser(
                        user.id,
                        nombre,
                        apellido,
                        cedula,
                        email,
                        selectedRol,
                        contrasena,
                      );
                    },
                    child: const Text(
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

  // Actualizar usuario en la base de datos con protecciones
  void _updateUser(
    int userId,
    String nombre,
    String apellido,
    String cedula,
    String email,
    String rol,
    String contrasena,
  ) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
      };

      // Solo añadir rol si el usuario actual es super admin
      if (_currentUserIsSuperAdmin) {
        userData['rol'] = rol;
        print('🔑 Super admin modificando rol a: $rol');
      } else {
        print('🔑 Admin normal - no enviando campo rol');
      }

      // Solo añadir contraseña si se ha proporcionado una nueva
      if (contrasena.isNotEmpty) {
        userData['contrasena'] = contrasena;
      }

      print('📝 Datos a enviar: $userData');

      // Llamar al servicio para actualizar el usuario
      await _userService.updateUser(userId.toString(), userData);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // Recargar la lista de usuarios
      await _loadUsers();

      if (mounted) {
        _showSuccessMessage('Usuario actualizado con éxito');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      String errorMessage = 'Error al actualizar usuario';

      print('❌ Error completo al actualizar usuario: $e');

      // Detectar tipos específicos de error basados en los códigos del servidor
      final errorString = e.toString().toLowerCase();

      // Manejar errores específicos del servidor actualizado
      if (errorString.contains('token_invalido')) {
        errorMessage =
            'Tu sesión ha expirado. Por favor, inicia sesión nuevamente';
      } else if (errorString.contains('sin_autorizacion')) {
        errorMessage = 'No tienes autorización para realizar esta acción';
      } else if (errorString.contains('sin_permisos_editar')) {
        errorMessage = 'No tienes permisos para editar usuarios';
      } else if (errorString.contains('superadmin_protegido')) {
        errorMessage =
            'Solo el Super Administrador puede editar su propia cuenta';
      } else if (errorString.contains('sin_permisos_admin')) {
        errorMessage =
            'Solo el Super Administrador puede editar otros administradores';
      } else if (errorString.contains('cedula_duplicada')) {
        errorMessage = 'La cédula ya está registrada por otro usuario';
      } else if (errorString.contains('email_duplicado')) {
        errorMessage = 'El email ya está registrado por otro usuario';
      } else if (errorString.contains('sin_permisos_superadmin')) {
        errorMessage =
            'Solo el Super Administrador puede asignar el rol de Super Administrador';
      } else if (errorString.contains('superadmin_inmutable')) {
        errorMessage = 'El rol del Super Administrador principal es inmutable';
      } else if (errorString.contains('sin_permisos_rol_admin')) {
        errorMessage =
            'Solo el Super Administrador puede cambiar roles de administradores';
      } else if (errorString.contains('rol_invalido')) {
        errorMessage = 'El rol especificado no es válido';
      } else if (errorString.contains('usuario_no_encontrado')) {
        errorMessage = 'El usuario no fue encontrado o ha sido eliminado';
      } else {
        // Intentar extraer mensaje JSON del servidor como fallback
        try {
          final RegExp jsonRegex = RegExp(r'\{.*\}');
          final match = jsonRegex.firstMatch(e.toString());
          if (match != null) {
            final jsonString = match.group(0)!;
            final Map<String, dynamic> errorData = json.decode(jsonString);
            final String? serverMessage = errorData['message'] as String?;

            if (serverMessage != null && serverMessage.isNotEmpty) {
              errorMessage = serverMessage;
            }
          }
        } catch (parseError) {
          // Fallback para errores de red o conexión
          if (errorString.contains('network') ||
              errorString.contains('connection')) {
            errorMessage =
                'Error de conexión con el servidor. Verifica tu conexión a internet';
          } else if (errorString.contains('timeout')) {
            errorMessage = 'Tiempo de espera agotado. Intenta nuevamente';
          } else if (errorString.contains('socket')) {
            errorMessage =
                'Error de conexión. Verifica que el servidor esté disponible';
          }
        }
      }

      print('📝 Mensaje de error final mostrado: $errorMessage');

      if (mounted) {
        _showErrorModal(errorMessage);
      }
    }
  }

  // Obtener texto de ayuda para el selector de rol
  String _getRoleEditHelperText(bool isSuperAdmin, bool isCurrentUser) {
    if (isSuperAdmin) {
      return 'El rol del Super Administrador no puede ser modificado';
    } else if (isCurrentUser) {
      return 'No puedes cambiar tu propio rol';
    } else if (!_currentUserIsSuperAdmin) {
      return 'Solo el Super Administrador puede editar roles de otros usuarios';
    } else {
      return 'Selecciona el nuevo rol para este usuario';
    }
  }

  // Construir lista de elementos para el selector de rol
  List<DropdownMenuItem<String>> _buildRoleDropdownItems() {
    return [
      const DropdownMenuItem(value: '00', child: Text('Super Administrador')),
      const DropdownMenuItem(value: '0', child: Text('Administrador')),
      const DropdownMenuItem(value: '1', child: Text('Cliente')),
      const DropdownMenuItem(value: '2', child: Text('Cocinero')),
      const DropdownMenuItem(value: '3', child: Text('Barista')),
    ];
  }

  // Obtener icono del rol
  IconData _getRoleIcon(String iconName) {
    switch (iconName) {
      case 'admin_panel_settings':
        return Icons.admin_panel_settings;
      case 'person':
        return Icons.person;
      case 'restaurant':
        return Icons.restaurant;
      case 'coffee':
        return Icons.coffee;
      case 'shield':
        return Icons.shield;
      default:
        return Icons.help;
    }
  }
}
