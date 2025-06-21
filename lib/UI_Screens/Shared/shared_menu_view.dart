import 'package:flutter/material.dart';
import 'dart:async';
import '/Api_services/menu/get_dishes_service.dart';
import '/Api_services/menu/get_drinks_service.dart';
import '/UI_Screens/Widgets/search_bar.dart' as custom;
import '/UI_Screens/Widgets/category_carousel.dart';
import '/UI_Screens/Widgets/dish_card.dart';
import '/UI_Screens/Admin_Screens/add_dish_modal.dart';
import '/Api_services/menu/add_dish_service.dart';
import '/services/restoration_event_bus.dart';

/// Widget compartido para visualizar el menú tanto por administradores como por clientes
class MenuView extends StatefulWidget {
  /// Rol del usuario (0=admin, 1=cliente, otros roles)
  final int userRole;

  /// Callback para refrescar datos en el padre si es necesario
  final VoidCallback? onRefresh;

  /// Si es true, se iniciará mostrando las bebidas en lugar de los platos
  final bool initialShowDrinks;

  const MenuView({
    Key? key,
    required this.userRole,
    this.onRefresh,
    this.initialShowDrinks = false,
  }) : super(key: key);

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView> {
  final TextEditingController _searchController = TextEditingController();
  final RestorationEventBus _restorationEventBus = RestorationEventBus();
  StreamSubscription<RestorationEvent>? _restorationSubscription;

  List<Map<String, dynamic>> _dishes = [];
  List<Map<String, dynamic>> _drinks = [];
  String? _expandedItemId;
  Set<String> _selectedCategories = {};
  bool _isLoading = false;
  bool _showDrinks = false; // Controlador para mostrar platos o bebidas

  // Categorías de platos
  final List<Map<String, String>> _dishCategories = [
    {'name': 'Tablas', 'image': 'assets/images/tablas.jpg'},
    {'name': 'Panquecas', 'image': 'assets/images/panquecas.jpg'},
    {'name': 'Tostadas francesas', 'image': 'assets/images/tostadas.jpg'},
    {'name': 'Gofres', 'image': 'assets/images/gofres.jpg'},
    {'name': 'Omelettes', 'image': 'assets/images/omelettes.jpg'},
  ];

  // Categorías de bebidas
  final List<Map<String, String>> _drinkCategories = [
    {'name': 'Expresos', 'image': 'assets/images/espresso.jpg'},
    {
      'name': 'Frapuccinos',
      'image': 'assets/images/frapuccino_de_chocolate.jpg',
    },
    {'name': 'Cold Brew', 'image': 'assets/images/Cold-Brew-Coffee.jpg'},
    {'name': 'Jugos', 'image': 'assets/images/smoothie-de-fresas.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _showDrinks = widget.initialShowDrinks;
    _fetchDishes();
    _fetchDrinks();

    // Agregar listener para actualizar la búsqueda en tiempo real
    _searchController.addListener(() {
      setState(() {
        // Solo trigger rebuild cuando cambie el texto
      });
    });

    // 🔄 NUEVO: Listener para eventos de restauración
    _setupRestorationListener();
  }

  /// Configurar listener para eventos de restauración
  void _setupRestorationListener() {
    _restorationSubscription = _restorationEventBus.onRestoration.listen((
      event,
    ) {
      print('🔄 MenuView: Recibido evento de restauración: ${event.type}');

      switch (event.type) {
        case RestorationEventType.batchRestorationsCompleted:
          // Solo recargar cuando se complete el lote de restauraciones
          final data = event.data as Map<String, dynamic>?;
          final restoredDishes =
              (data?['restoredDishes'] as List?)?.cast<String>() ?? [];

          if (restoredDishes.isNotEmpty) {
            print(
              '🔄 MenuView: Recargando menú por ${restoredDishes.length} platos restaurados',
            );
            _refreshMenuData();
          }
          break;
        default:
          // Ignorar otros eventos para evitar múltiples recargas
          break;
      }
    });
  }

  /// Recargar datos del menú de forma optimizada
  Future<void> _refreshMenuData() async {
    print('📋 MenuView: Iniciando recarga de datos del menú...');

    // Usar Future.wait para cargar platos y bebidas en paralelo
    await Future.wait([_fetchDishes(), _fetchDrinks()]);

    print('✅ MenuView: Datos del menú recargados exitosamente');

    // Mostrar feedback visual al usuario solo una vez
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Elementos restaurados - Menú actualizado'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _restorationSubscription?.cancel(); // 🔄 Limpiar subscription
    super.dispose();
  }

  Future<void> _fetchDishes() async {
    try {
      setState(() => _isLoading = true);
      final data = await GetDishesService().getDishes();
      if (mounted) {
        setState(() {
          _dishes = data;
          if (!_showDrinks) _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar platos: $e')));
      }
    }
  }

  Future<void> _fetchDrinks() async {
    try {
      setState(() => _isLoading = true);
      final data = await GetDrinksService().getDrinks();
      if (mounted) {
        setState(() {
          _drinks = data;
          if (_showDrinks) _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar bebidas: $e')));
      }
    }
  }

  void _toggleMenuType(bool showDrinks) {
    if (_showDrinks != showDrinks) {
      setState(() {
        _showDrinks = showDrinks;
        _selectedCategories = {}; // Limpiar categorías seleccionadas al cambiar
      });
    }
  }

  // Función para editar un plato (solo para administradores)
  void _editDish(Map<String, dynamic> dish) async {
    if (widget.userRole != 0) return; // Solo administradores pueden editar

    // Mostrar modal para editar plato
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AddDishModal(
            dish: dish,
            onSuccess: () {
              // Recargar datos después de editar
              _fetchDishes();
              _fetchDrinks();
              if (widget.onRefresh != null) {
                widget.onRefresh!();
              }
            },
          ),
    );

    if (result == true) {
      // Recargar datos después de editar
      _fetchDishes();
      _fetchDrinks();
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    }
  }

  // Función para eliminar un plato (solo para administradores)
  Future<void> _deleteDish(String id) async {
    if (widget.userRole != 0) return; // Solo administradores pueden eliminar

    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Item'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este elemento del menú?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    // Si el usuario confirma la eliminación
    if (confirm == true) {
      try {
        final addDishService = AddDishService();
        final isSuccess = await addDishService.deleteDish(id);

        if (isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Eliminado exitosamente')),
            );
            // Recargar datos tras eliminar
            _fetchDishes();
            _fetchDrinks();
            if (widget.onRefresh != null) {
              widget.onRefresh!();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  // Función para agregar un plato (solo para administradores)
  void _addDish() async {
    if (widget.userRole != 0) return; // Solo administradores pueden agregar

    // Determinar la categoría inicial basada en si estamos en platos o bebidas
    final initialCategory =
        _showDrinks
            ? _drinkCategories.first['name']
            : _dishCategories.first['name'];

    // Determinar el tipo de elemento (plato o bebida) para mensajes
    final itemType = _showDrinks ? 'bebida' : 'plato';

    // Mostrar modal para agregar plato o bebida
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AddDishModal(
            onSuccess: () {
              // Recargar datos después de agregar
              _fetchDishes();
              _fetchDrinks();
              if (widget.onRefresh != null) {
                widget.onRefresh!();
              }
            },
            // Pasar un objeto con la categoría inicial y tipo
            dish: {
              'categoria': initialCategory,
              '_isNewItem': true, // Marcador para indicar que es nuevo
              '_itemType': itemType, // Para personalizar el título
            },
          ),
    );

    if (result == true) {
      // Recargar datos después de agregar
      _fetchDishes();
      _fetchDrinks();
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // El CustomScrollView principal
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Selector de Platos/Bebidas como sliver
            SliverToBoxAdapter(child: _buildMenuTypeSelector(theme)),

            // Barra de búsqueda como sliver
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: 12.0,
                ),
                child: custom.SearchBar(controller: _searchController),
              ),
            ),

            // Carrusel de categorías como sliver
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: SizedBox(
                  height: 120,
                  child: CategoryCarousel(
                    categories:
                        _showDrinks ? _drinkCategories : _dishCategories,
                    multiSelect: true,
                    selectedCategories: _selectedCategories,
                    onCategoryToggled: (category) {
                      setState(() {
                        if (_selectedCategories.contains(category)) {
                          _selectedCategories.remove(category);
                        } else {
                          _selectedCategories.add(category);
                        }
                      });
                    },
                  ),
                ),
              ),
            ),

            // Lista de platos/bebidas como sliver
            _isLoading
                ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
                : _buildItemListSliver(),
          ],
        ),

        // Botón flotante para agregar (solo para administradores)
        if (widget.userRole == 0)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _addDish,
              child: const Icon(Icons.add),
              tooltip: 'Agregar ${_showDrinks ? 'bebida' : 'plato'}',
            ),
          ),
      ],
    );
  }

  Widget _buildMenuTypeSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Selector de Platos
            Expanded(
              child: GestureDetector(
                onTap: () => _toggleMenuType(false),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        !_showDrinks
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          color:
                              !_showDrinks
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Platos',
                          style: TextStyle(
                            color:
                                !_showDrinks
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                            fontFamily: 'MADE TOMMY',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Selector de Bebidas
            Expanded(
              child: GestureDetector(
                onTap: () => _toggleMenuType(true),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        _showDrinks
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_cafe,
                          color:
                              _showDrinks
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bebidas',
                          style: TextStyle(
                            color:
                                _showDrinks
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                            fontFamily: 'MADE TOMMY',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemListSliver() {
    // Usar platos o bebidas según la selección
    final items = _showDrinks ? _drinks : _dishes;
    final categories = _showDrinks ? _drinkCategories : _dishCategories;

    // Filtrar los platos/bebidas según la búsqueda y las categorías seleccionadas
    final filteredItems =
        items.where((item) {
          final nameMatch = item['nombre'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
          final categoryMatch =
              _selectedCategories.isEmpty ||
              _selectedCategories.contains(item['categoria']);

          // Para clientes (rol 1), solo mostrar items disponibles
          if (widget.userRole == 1) {
            return nameMatch &&
                categoryMatch &&
                (item['disponibilidad'] ?? false);
          }

          return nameMatch && categoryMatch;
        }).toList();

    if (filteredItems.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    // Agrupar los items por categoría
    final Map<String, List<Map<String, dynamic>>> itemsByCategory = {};

    // Primero, inicializar todas las categorías del carousel para mantener el orden
    for (var category in categories) {
      itemsByCategory[category['name']!] = [];
    }

    // Añadir una categoría "Otros" para items sin categoría reconocida
    itemsByCategory['Otros'] = [];

    // Agrupar los items filtrados por categoría
    for (var item in filteredItems) {
      final category = item['categoria']?.toString() ?? 'Otros';
      if (itemsByCategory.containsKey(category)) {
        itemsByCategory[category]!.add(item);
      } else {
        itemsByCategory['Otros']!.add(item);
      }
    }

    // Eliminar categorías vacías
    itemsByCategory.removeWhere((key, value) => value.isEmpty);

    // Si no hay categorías con items después del filtrado
    if (itemsByCategory.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    // Crear una lista de widgets para las categorías
    List<Widget> categoryWidgets = [];

    for (int index = 0; index < itemsByCategory.length; index++) {
      final categoryName = itemsByCategory.keys.toList()[index];
      final categoryItems = itemsByCategory[categoryName]!;

      categoryWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de categoría
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  // Buscar la imagen de la categoría en el carousel
                  _buildCategoryIcon(categoryName),
                  const SizedBox(width: 12),
                  Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'MADE TOMMY',
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Divider(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Grid para platos de esta categoría
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildCategoryItemGrid(categoryItems),
            ),
          ],
        ),
      );
    }

    // Agregar padding bottom para el FloatingActionButton
    categoryWidgets.add(
      const SizedBox(height: 80), // Espacio para el FAB
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => categoryWidgets[index],
        childCount: categoryWidgets.length,
      ),
    );
  }

  Widget _buildCategoryItemGrid(List<Map<String, dynamic>> items) {
    // Definiendo tamaños apropiados para la cuadrícula
    const int crossAxisCount = 3;
    const childAspectRatio = 0.65;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 3, // Reducido para aprovechar espacio horizontal
        mainAxisSpacing: 6, // Reducido para aprovechar espacio vertical
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return DishCard(
          dish: items[index],
          userRole: widget.userRole,
          onToggleExpanded: (expanded) {
            setState(() {
              _expandedItemId =
                  expanded ? items[index]['idplato'].toString() : null;
            });
          },
          initialExpanded:
              items[index]['idplato'].toString() == _expandedItemId,
          editDish: widget.userRole == 0 ? _editDish : null,
          deleteDish: widget.userRole == 0 ? _deleteDish : null,
        );
      },
    );
  }

  Widget _buildCategoryIcon(String categoryName) {
    final categories = _showDrinks ? _drinkCategories : _dishCategories;
    final theme = Theme.of(context);

    // Buscar la imagen de categoría correspondiente
    final categoryInfo = categories.firstWhere(
      (c) => c['name'] == categoryName,
      orElse:
          () => {
            'name': categoryName,
            'image':
                _showDrinks
                    ? 'assets/images/panquecas.jpg'
                    : 'assets/images/tablas.jpg',
          },
    );

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          categoryInfo['image']!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              _showDrinks ? Icons.local_cafe : Icons.restaurant_menu,
              color: theme.colorScheme.primary,
              size: 18,
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final String type = _showDrinks ? 'bebidas' : 'platos';
    final IconData icon =
        _showDrinks ? Icons.local_cafe : Icons.restaurant_menu;

    // Obtener los items actuales para pasar a filteredItems
    final items = _showDrinks ? _drinks : _dishes;

    // Filtrar los platos/bebidas según la búsqueda y las categorías seleccionadas
    final filteredItems =
        items.where((item) {
          final nameMatch = item['nombre'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
          final categoryMatch =
              _selectedCategories.isEmpty ||
              _selectedCategories.contains(item['categoria']);

          // Para clientes (rol 1), solo mostrar items disponibles
          if (widget.userRole == 1) {
            return nameMatch &&
                categoryMatch &&
                (item['disponibilidad'] ?? false);
          }

          return nameMatch && categoryMatch;
        }).toList();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay $type disponibles',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'LightHouse',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedCategories.isNotEmpty) ...[
            Text(
              'Prueba quitando filtros de categoría',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategories = {};
                });
              },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Quitar filtros'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Prueba otra búsqueda',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.search_off),
              label: const Text('Limpiar búsqueda'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
          // En modo Admin, mostramos el botón para agregar
          if (widget.userRole == 0 && filteredItems.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addDish,
              icon: const Icon(Icons.add),
              label: Text('Agregar ${_showDrinks ? 'bebida' : 'plato'}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
