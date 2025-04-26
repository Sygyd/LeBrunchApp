import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widgets/background_scaffold.dart';
import '../../Api_services/pedidos/popular_dishes_service.dart';
import '../../Api_services/menu/menu_service.dart';

class PopularDishesScreen extends StatefulWidget {
  const PopularDishesScreen({super.key});

  @override
  State<PopularDishesScreen> createState() => _PopularDishesScreenState();
}

class _PopularDishesScreenState extends State<PopularDishesScreen> {
  final PopularDishesService _popularDishesService = PopularDishesService();
  final MenuService _menuService = MenuService();
  bool _isLoading = true;
  String? _error; // Definición de variable de error
  List<Map<String, dynamic>> _popularDishes = [];
  List<Map<String, dynamic>> _filteredDishes = [];
  String _selectedPeriod =
      'week'; // Período seleccionado: day, week, month, year
  List<Map<String, dynamic>> _categories = []; // Lista de categorías
  Map<String, bool> _selectedCategories =
      {}; // Categorías seleccionadas como Map

  // Variables para el rango de fechas personalizado
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Inicializar estados
    _isLoading = true;
    _selectedCategories = {};
    _selectedPeriod = 'week';
    _categories = [];
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();

    // Cargar datos iniciales
    _loadCategoriesAndDishes();
  }

  // Método para cargar categorías y platos en un solo flujo
  Future<void> _loadCategoriesAndDishes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Paso 1: Cargar las categorías
      await _loadCategories();

      // Paso 2: Cargar los platos populares
      await _loadPopularDishes();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
      _showErrorSnackBar('Error al cargar datos: $e');
    }
  }

  // Carga las categorías desde el menú
  Future<void> _loadCategories() async {
    try {
      final menu =
          await _menuService.getDishes(); // Uso de método correcto getDishes

      // Extraer categorías únicas del menú
      final Set<String> categories = {};

      for (var item in menu) {
        if (item['categoria'] != null &&
            item['categoria'].toString().isNotEmpty) {
          categories.add(item['categoria']);
        }
      }

      // Convertir a lista y ordenar alfabéticamente
      final sortedCategories = categories.toList()..sort();

      if (mounted) {
        setState(() {
          _categories =
              sortedCategories
                  .map((cat) => {'id': cat, 'name': cat, 'icon': 'restaurant'})
                  .toList();
        });
      }

      print('🔍 Categorías cargadas: $_categories');
    } catch (e) {
      print('⚠️ Error al cargar categorías: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar categorías: $e';
        });
      }
    }
  }

  // Carga los platos populares según los filtros seleccionados
  Future<void> _loadPopularDishes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final popularDishesService = PopularDishesService();

      String? startDateStr;
      String? endDateStr;
      String? period = _selectedPeriod;
      String? selectedCategory;

      // Formatear fechas si el período es personalizado
      if (_selectedPeriod == 'custom' &&
          _startDate != null &&
          _endDate != null) {
        startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        period = null; // No enviar período si es personalizado
      }

      // Obtener la categoría seleccionada, si hay alguna
      if (_selectedCategories.isNotEmpty) {
        selectedCategory = _selectedCategories.keys.first;
      }

      print(
        '🔄 Cargando platos populares con: período=$period, inicio=$startDateStr, fin=$endDateStr, categoría=$selectedCategory',
      );

      // Intentar obtener platos populares con método directo primero
      List<Map<String, dynamic>> result = await popularDishesService
          .getPopularDishesDirect(
            period: period,
            startDate: startDateStr,
            endDate: endDateStr,
            category: selectedCategory,
          );

      // Si no hay resultados y se aplicaron filtros, intentar sin filtros
      if (result.isEmpty &&
          (selectedCategory != null || startDateStr != null)) {
        // Mostrar mensaje informativo
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontraron platos con los filtros seleccionados. Mostrando todos los platos populares.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Limpiar filtros de categoría
        setState(() {
          _selectedCategories.clear();
        });

        // Intentar obtener todos los platos sin filtros
        result = await popularDishesService.getPopularDishesDirect();
      }

      if (mounted) {
        setState(() {
          _popularDishes = result;
          _filteredDishes = List.from(result); // Inicialmente mostrar todos
          _isLoading = false;
        });

        // Aplicar filtros a los resultados obtenidos
        _applyFilters();
      }
    } catch (e) {
      print('⚠️ Error al cargar platos populares: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar platos populares: $e';
          _isLoading = false;
        });
        _showErrorSnackBar('No se pudieron cargar los platos populares');
      }
    }
  }

  // Mostrar un SnackBar con mensaje de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Aplica los filtros seleccionados a la lista de platos
  void _applyFilters() {
    if (_popularDishes.isEmpty) {
      setState(() {
        _filteredDishes = [];
      });
      return;
    }

    // Si no hay categorías seleccionadas, mostrar todos los platos
    if (_selectedCategories.isEmpty) {
      setState(() {
        _filteredDishes = List.from(_popularDishes);
      });
      return;
    }

    final filteredDishes =
        _popularDishes.where((dish) {
          // Verificar si el plato tiene una categoría válida
          if (dish['categoria'] == null ||
              dish['categoria'].toString().isEmpty) {
            return false;
          }

          // Comprobar si la categoría del plato coincide con alguna seleccionada
          for (var category in _selectedCategories.keys) {
            if (dish['categoria'].toString().toLowerCase() ==
                category.toLowerCase()) {
              return true;
            }
          }

          return false;
        }).toList();

    setState(() {
      _filteredDishes = filteredDishes;
    });

    print('🔍 Filtros aplicados: ${_selectedCategories.keys}');
    print(
      '📊 Platos mostrados: ${_filteredDishes.length} de ${_popularDishes.length}',
    );
  }

  // Maneja la selección/deselección de una categoría
  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.containsKey(category)) {
        // Si ya estaba seleccionada, deseleccionarla
        _selectedCategories.remove(category);
      } else {
        // Si no estaba seleccionada, seleccionarla (y deseleccionar otras)
        _selectedCategories.clear(); // Permitir solo una selección
        _selectedCategories[category] = true;
      }

      // Aplicar filtros
      _applyFilters();
    });
  }

  // Actualiza el período seleccionado y recarga los datos
  void _updatePeriod(String period) {
    if (_selectedPeriod == period) {
      return; // Si es el mismo período, no hacer nada
    }

    setState(() {
      _selectedPeriod = period;
      // Limpiar cualquier filtro de categoría al cambiar el período
      _selectedCategories.clear();

      // Actualizar fechas para el período seleccionado
      switch (period) {
        case 'day':
          _startDate = DateTime.now();
          _endDate = DateTime.now();
          break;
        case 'week':
          _startDate = DateTime.now().subtract(const Duration(days: 7));
          _endDate = DateTime.now();
          break;
        case 'month':
          _startDate = DateTime.now().subtract(const Duration(days: 30));
          _endDate = DateTime.now();
          break;
        case 'year':
          _startDate = DateTime.now().subtract(const Duration(days: 365));
          _endDate = DateTime.now();
          break;
        // No actualizar fechas para 'custom'
      }
    });

    // Recargar datos con el nuevo período
    _loadPopularDishes();
  }

  // Selecciona el rango de fechas personalizado
  Future<void> _selectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2021), // Fecha mínima permitida
      lastDate: DateTime.now(), // Fecha máxima permitida (hoy)
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _endDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
        _selectedPeriod = 'custom';
        // Limpiar cualquier filtro de categoría al cambiar el período
        _selectedCategories.clear();
      });

      // Recargar datos con el nuevo rango de fechas
      _loadPopularDishes();
    }
  }

  // Widget que construye un filtro de categoría
  Widget _buildCategoryFilter(String category) {
    final isSelected = _selectedCategories.containsKey(category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (_) => _toggleCategory(category),
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        checkmarkColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // Widget que construye un filtro de período
  Widget _buildPeriodFilter(String period, String label) {
    final isSelected = _selectedPeriod == period;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _updatePeriod(period),
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // Widget para mostrar la información del período seleccionado
  Widget _buildDateInfo() {
    String dateInfo = '';

    switch (_selectedPeriod) {
      case 'day':
        dateInfo = 'Hoy';
        break;
      case 'week':
        dateInfo = 'Últimos 7 días';
        break;
      case 'month':
        dateInfo = 'Últimos 30 días';
        break;
      case 'year':
        dateInfo = 'Último año';
        break;
      case 'custom':
        if (_startDate != null && _endDate != null) {
          final start = DateFormat('dd/MM/yyyy').format(_startDate!);
          final end = DateFormat('dd/MM/yyyy').format(_endDate!);
          dateInfo = 'Del $start al $end';
        } else {
          dateInfo = 'Rango personalizado';
        }
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        dateInfo,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(amount);
  }

  // Formatear rango de fechas para mostrar
  String _formatDateRange() {
    if (_startDate == null) return '';

    final formatter = DateFormat('dd/MM/yyyy');
    final start = formatter.format(_startDate!);

    if (_endDate == null || _endDate!.isAtSameMomentAs(_startDate!)) {
      return start;
    }

    final end = formatter.format(_endDate!);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackgroundScaffold(
      appBar: AppBar(
        title: const Text(
          'Platos Más Populares',
          style: TextStyle(
            fontFamily: 'MADE TOMMY',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de período con scroll horizontal
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Período de análisis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      _buildPeriodFilter('day', 'Hoy'),
                      const SizedBox(width: 8),
                      _buildPeriodFilter('week', 'Esta semana'),
                      const SizedBox(width: 8),
                      _buildPeriodFilter('month', 'Este mes'),
                      const SizedBox(width: 8),
                      _buildPeriodFilter('year', 'Este año'),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.date_range),
                        label: Text(
                          _selectedPeriod == 'custom' && _startDate != null
                              ? _formatDateRange()
                              : 'Personalizado',
                        ),
                        backgroundColor:
                            _selectedPeriod == 'custom'
                                ? theme.colorScheme.primary.withOpacity(0.2)
                                : null,
                        onPressed: _selectDateRange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filtro por categorías
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrar por categoría',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'MADE TOMMY',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Opción para mostrar todas las categorías
                        FilterChip(
                          label: const Text('Todas'),
                          selected: _selectedCategories.isEmpty,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategories = {};
                              });
                              // Cargar los datos nuevamente al quitar los filtros
                              _loadPopularDishes();
                            }
                          },
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color:
                                _selectedCategories.isEmpty
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                            fontFamily: 'MADE TOMMY',
                          ),
                        ),
                        ..._categories.map((category) {
                          final categoryId = category['id'] as String;
                          final isSelected = _selectedCategories.containsKey(
                            categoryId,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: FilterChip(
                              label: Text(category['name'] as String),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedCategories.remove(categoryId);
                                  } else {
                                    _selectedCategories.clear();
                                    _selectedCategories[categoryId] = true;
                                  }
                                });
                                // Cargar datos nuevamente con el filtro actualizado
                                _loadPopularDishes();
                              },
                              selectedColor: theme.colorScheme.primary,
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                fontFamily: 'MADE TOMMY',
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Resumen de platos
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredDishes.length} platos encontrados',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadPopularDishes,
                  tooltip: 'Actualizar datos',
                ),
              ],
            ),
          ),

          // Lista de platos populares
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                    : _filteredDishes.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay datos disponibles',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Prueba con otros filtros o período',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredDishes.length,
                      itemBuilder: (context, index) {
                        final dish = _filteredDishes[index];
                        final rank = index + 1;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.transparent,
                                  // Imagen del plato o fallback
                                  child: ClipOval(
                                    child:
                                        dish['imagen_url'] != null
                                            ? Image.network(
                                              dish['imagen_url'],
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return Container(
                                                  width: 56,
                                                  height: 56,
                                                  color: theme
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.2),
                                                  child: Icon(
                                                    Icons.restaurant,
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .primary,
                                                  ),
                                                );
                                              },
                                            )
                                            : Container(
                                              width: 56,
                                              height: 56,
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.2),
                                              child: Icon(
                                                Icons.restaurant,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                  ),
                                ),
                                // Ranking
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _getRankColor(rank, theme),
                                    child: Text(
                                      '$rank',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              dish['nombre'] ?? 'Plato sin nombre',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'LightHouse',
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                // Categoría
                                if (dish['categoria'] != null) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.category_outlined,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dish['categoria'].toString(),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontFamily: 'MADE TOMMY',
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                // Cantidad vendida
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Vendidos: ${dish['cantidad_vendida'] ?? 0}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontFamily: 'MADE TOMMY'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Precio promedio
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Precio: ${_formatCurrency(dish['precio_promedio'] ?? 0.0)}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontFamily: 'MADE TOMMY'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(
                                    (dish['cantidad_vendida'] ?? 0) *
                                        (dish['precio_promedio'] ?? 0),
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    fontFamily: 'MADE TOMMY',
                                  ),
                                ),
                                Text(
                                  'Total',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, String label) {
    final isSelected = _selectedPeriod == period;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _updatePeriod(period);
        }
      },
      backgroundColor: Colors.transparent,
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontFamily: 'MADE TOMMY',
      ),
    );
  }

  Color _getRankColor(int rank, ThemeData theme) {
    if (rank == 1) return Colors.amber; // Oro
    if (rank == 2) return Colors.blueGrey.shade300; // Plata
    if (rank == 3) return Colors.brown.shade300; // Bronce
    return theme.colorScheme.primary; // Color por defecto
  }
}
