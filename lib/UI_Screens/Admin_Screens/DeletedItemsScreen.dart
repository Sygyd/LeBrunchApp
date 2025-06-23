import 'package:flutter/material.dart';
import '/Api_services/soft_delete_service.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';
import '/theme/theme.dart';
import '/services/restoration_event_bus.dart';

/// Pantalla para administradores que muestra elementos eliminados
/// y permite restaurarlos usando el sistema de soft delete
class DeletedItemsScreen extends StatefulWidget {
  const DeletedItemsScreen({Key? key}) : super(key: key);

  @override
  State<DeletedItemsScreen> createState() => _DeletedItemsScreenState();
}

class _DeletedItemsScreenState extends State<DeletedItemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SoftDeleteService _softDeleteService = SoftDeleteService();
  final RestorationEventBus _restorationEventBus = RestorationEventBus();

  // Estados de carga
  bool _isLoadingDishes = false;
  bool _isLoadingUsers = false;

  // Listas de elementos eliminados
  List<Map<String, dynamic>> _deletedDishes = [];
  List<Map<String, dynamic>> _deletedUsers = [];

  // Estadísticas
  Map<String, int> _stats = {};

  // Rastrear elementos restaurados durante esta sesión
  final Set<String> _restoredDishIds = <String>{};
  final Set<String> _restoredUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    // Notificar restauraciones en lote antes de cerrar la pantalla
    _notifyBatchRestorations();

    _tabController.dispose();
    super.dispose();
  }

  /// Notificar todas las restauraciones realizadas durante esta sesión
  void _notifyBatchRestorations() {
    if (_restoredDishIds.isNotEmpty || _restoredUserIds.isNotEmpty) {
      print('🔄 DeletedItemsScreen: Notificando restauraciones en lote');
      print('   - Platos restaurados: ${_restoredDishIds.length}');
      print('   - Usuarios restaurados: ${_restoredUserIds.length}');

      _restorationEventBus.notifyBatchRestorationsCompleted(
        _restoredDishIds.toList(),
        _restoredUserIds.toList(),
      );
    }
  }

  /// Cargar todos los datos
  Future<void> _loadData() async {
    await Future.wait([
      _loadDeletedDishes(),
      _loadDeletedUsers(),
      _loadStats(),
    ]);
  }

  /// Cargar platos eliminados
  Future<void> _loadDeletedDishes() async {
    setState(() => _isLoadingDishes = true);
    try {
      final dishes = await _softDeleteService.getDeletedDishes();
      setState(() => _deletedDishes = dishes);
    } catch (e) {
      _showErrorSnackBar('Error al cargar platos eliminados: $e');
    } finally {
      setState(() => _isLoadingDishes = false);
    }
  }

  /// Cargar usuarios eliminados
  Future<void> _loadDeletedUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await _softDeleteService.getDeletedUsers();
      setState(() => _deletedUsers = users);
    } catch (e) {
      _showErrorSnackBar('Error al cargar usuarios eliminados: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  /// Cargar estadísticas
  Future<void> _loadStats() async {
    try {
      final stats = await _softDeleteService.getDeletedItemsStats();
      setState(() => _stats = stats);
    } catch (e) {
      print('Error al cargar estadísticas: $e');
    }
  }

  /// Mostrar mensaje de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mostrar mensaje de éxito
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Restaurar un plato
  Future<void> _restoreDish(String dishId, String dishName) async {
    final confirm = await _showRestoreConfirmDialog(
      'Restaurar Plato',
      '¿Estás seguro de que deseas restaurar "$dishName"?',
    );

    if (confirm == true) {
      try {
        print(
          '🔄 DeletedItemsScreen: Iniciando restauración de plato $dishId ($dishName)',
        );

        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Restaurando "$dishName"...'),
              ],
            ),
            duration: Duration(seconds: 10),
            backgroundColor: Colors.blue,
          ),
        );

        final success = await _softDeleteService.restoreDish(dishId);

        // Limpiar el SnackBar de carga
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (success) {
          print('✅ DeletedItemsScreen: Plato restaurado exitosamente');

          // 🔄 NUEVO: Rastrear plato restaurado (notificación solo al salir)
          _restoredDishIds.add(dishId);

          _showSuccessSnackBar('Plato "$dishName" restaurado exitosamente');

          // Recargar datos con un pequeño delay para dar tiempo al servidor
          await Future.delayed(Duration(milliseconds: 500));
          await Future.wait([_loadDeletedDishes(), _loadStats()]);

          print(
            '📊 DeletedItemsScreen: Datos recargados después de restauración',
          );
        } else {
          print(
            '⚠️ DeletedItemsScreen: Restauración reportada como no exitosa',
          );
          _showErrorSnackBar('No se pudo restaurar el plato "$dishName"');
        }
      } catch (e) {
        print('❌ DeletedItemsScreen: Error al restaurar plato: $e');

        // Limpiar el SnackBar de carga si está visible
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        String errorMessage = 'Error al restaurar plato: $e';

        // Personalizar mensajes de error más amigables
        if (e.toString().contains('Tiempo de espera')) {
          errorMessage = 'La operación tardó demasiado. Intenta nuevamente.';
        } else if (e.toString().contains('Error de conexión')) {
          errorMessage =
              'No se pudo conectar al servidor. Verifica tu conexión.';
        } else if (e.toString().contains('ya está restaurado')) {
          errorMessage = 'El plato ya había sido restaurado anteriormente.';
          // En este caso, recargar los datos para actualizar la UI
          await Future.delayed(Duration(milliseconds: 300));
          await Future.wait([_loadDeletedDishes(), _loadStats()]);
        }

        _showErrorSnackBar(errorMessage);
      }
    }
  }

  /// Restaurar un usuario
  Future<void> _restoreUser(String userId, String userName) async {
    final confirm = await _showRestoreConfirmDialog(
      'Restaurar Usuario',
      '¿Estás seguro de que deseas restaurar al usuario "$userName"?',
    );

    if (confirm == true) {
      try {
        await _softDeleteService.restoreUser(userId);

        // 🔄 NUEVO: Rastrear usuario restaurado (notificación solo al salir)
        _restoredUserIds.add(userId);

        _showSuccessSnackBar('Usuario "$userName" restaurado exitosamente');
        await Future.wait([_loadDeletedUsers(), _loadStats()]);
      } catch (e) {
        _showErrorSnackBar('Error al restaurar usuario: $e');
      }
    }
  }

  /// Mostrar diálogo de confirmación para restaurar
  Future<bool?> _showRestoreConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              title,
              style: TextStyle(
                fontFamily: 'LightHouse',
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            content: Text(
              content,
              style: const TextStyle(fontFamily: 'LightHouse'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontFamily: 'LightHouse',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text(
                  'Restaurar',
                  style: TextStyle(fontFamily: 'LightHouse'),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackgroundScaffold(
      appBar: AppBar(
        title: Text(
          'Elementos Eliminados',
          style: TextStyle(
            fontFamily: 'Lighthouse',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFF3ea69b),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 70.0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF3ea69b),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            image: DecorationImage(
              image: AssetImage('assets/images/fondo-flores-2.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header con estadísticas (sin título ya que está en AppBar)
          _buildStatsHeader(theme),

          // Tabs
          _buildTabBar(theme),

          const SizedBox(height: 16),

          // Contenido de las tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDishesTab(), _buildUsersTab()],
            ),
          ),
        ],
      ),
    );
  }

  /// Construir header con estadísticas
  Widget _buildStatsHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3ea69b),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/images/fondo-flores-2.png'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Row(
        children: [
          _buildStatCard(
            'Platos',
            _stats['deletedDishes']?.toString() ?? '0',
            Icons.restaurant,
            theme,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Usuarios',
            _stats['deletedUsers']?.toString() ?? '0',
            Icons.people,
            theme,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Total',
            _stats['total']?.toString() ?? '0',
            Icons.delete,
            theme,
          ),
        ],
      ),
    );
  }

  /// Construir tarjeta de estadística
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3ea69b), size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'MADE TOMMY',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3ea69b),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily:
                    'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para labels que pueden contener números
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir barra de tabs
  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF3ea69b),
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: const Color(0xFF3ea69b),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFF3ea69b).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Lighthouse',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Lighthouse',
          fontSize: 14,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.restaurant), text: 'Platos Eliminados'),
          Tab(icon: Icon(Icons.people), text: 'Usuarios Eliminados'),
        ],
      ),
    );
  }

  /// Construir tab de platos eliminados
  Widget _buildDishesTab() {
    if (_isLoadingDishes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deletedDishes.isEmpty) {
      return _buildEmptyState(
        'No hay platos eliminados',
        'Todos los platos están activos en el sistema',
        Icons.restaurant,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeletedDishes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deletedDishes.length,
        itemBuilder: (context, index) {
          final dish = _deletedDishes[index];
          return _buildDishCard(dish);
        },
      ),
    );
  }

  /// Construir tab de usuarios eliminados
  Widget _buildUsersTab() {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deletedUsers.isEmpty) {
      return _buildEmptyState(
        'No hay usuarios eliminados',
        'Todos los usuarios están activos en el sistema',
        Icons.people,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeletedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deletedUsers.length,
        itemBuilder: (context, index) {
          final user = _deletedUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  /// Construir estado vacío
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3ea69b).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF3ea69b)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Lighthouse',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3ea69b),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Lighthouse',
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Construir tarjeta de plato eliminado
  Widget _buildDishCard(Map<String, dynamic> dish) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF3ea69b).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre y botón restaurar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontFamily:
                              'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para nombres de platos que pueden contener números
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3ea69b),
                        ),
                      ),
                      Text(
                        dish['categoria'] ?? 'Sin categoría',
                        style: TextStyle(
                          fontFamily:
                              'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para categorías que pueden contener números
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      () => _restoreDish(
                        dish['idplato'].toString(),
                        dish['nombre'] ?? 'Sin nombre',
                      ),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text(
                    'Restaurar',
                    style: TextStyle(
                      fontFamily: 'MADE TOMMY',
                    ), // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para consistencia
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ea69b),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Información adicional
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: const Color(0xFF3ea69b),
                ),
                const SizedBox(width: 4),
                Text(
                  '\$${dish['precio']?.toString() ?? '0.00'}',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: const Color(0xFF3ea69b),
                ),
                const SizedBox(width: 4),
                Text(
                  _softDeleteService.formatDeletedDate(dish['deleted_at']),
                  style: TextStyle(
                    fontFamily:
                        'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para fechas con números
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            // Eliminado por
            if (dish['deleted_by_name'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: const Color(0xFF3ea69b)),
                  const SizedBox(width: 4),
                  Text(
                    'Eliminado por: ${_softDeleteService.getDeletedByName(dish)}',
                    style: TextStyle(
                      fontFamily:
                          'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para nombres que pueden contener números
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construir tarjeta de usuario eliminado
  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF3ea69b).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre y botón restaurar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'
                            .trim(),
                        style: const TextStyle(
                          fontFamily:
                              'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para nombres que pueden contener números
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3ea69b),
                        ),
                      ),
                      Text(
                        _softDeleteService.getRoleName(
                          int.tryParse(user['rol']?.toString() ?? '1') ?? 1,
                        ),
                        style: TextStyle(
                          fontFamily:
                              'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para roles que pueden contener números
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      () => _restoreUser(
                        user['id'].toString(),
                        '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'
                            .trim(),
                      ),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text(
                    'Restaurar',
                    style: TextStyle(
                      fontFamily: 'MADE TOMMY',
                    ), // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para consistencia
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ea69b),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Información adicional
            Row(
              children: [
                Icon(Icons.email, size: 16, color: const Color(0xFF3ea69b)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    user['email'] ?? 'Sin email',
                    style: TextStyle(
                      fontFamily:
                          'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para emails que pueden contener números
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: const Color(0xFF3ea69b),
                ),
                const SizedBox(width: 4),
                Text(
                  _softDeleteService.formatDeletedDate(user['deleted_at']),
                  style: TextStyle(
                    fontFamily:
                        'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para fechas con números
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            // Eliminado por
            if (user['deleted_by_name'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: const Color(0xFF3ea69b)),
                  const SizedBox(width: 4),
                  Text(
                    'Eliminado por: ${_softDeleteService.getDeletedByName(user)}',
                    style: TextStyle(
                      fontFamily:
                          'MADE TOMMY', // 🔧 CAMBIADO: Lighthouse → MADE TOMMY para nombres que pueden contener números
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
