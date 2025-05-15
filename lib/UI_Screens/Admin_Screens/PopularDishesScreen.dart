import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widgets/background_scaffold.dart';
import '../Widgets/date_filter_bar.dart';
import '../../Api_services/pedidos/popular_dishes_service.dart';
import '../../Api_services/menu/menu_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PopularDishesScreen extends StatefulWidget {
  const PopularDishesScreen({super.key});

  @override
  State<PopularDishesScreen> createState() => _PopularDishesScreenState();
}

class _PopularDishesScreenState extends State<PopularDishesScreen> {
  final PopularDishesService _popularDishesService = PopularDishesService();
  final MenuService _menuService = MenuService();
  // Clave global para acceder al DateFilterBar
  final GlobalKey<DateFilterBarState> _dateFilterKey = GlobalKey();
  bool _isLoading = true;
  String? _error; // Definición de variable de error
  List<Map<String, dynamic>> _popularDishes = [];
  List<Map<String, dynamic>> _filteredDishes = [];
  String _selectedPeriod =
      'all'; // Período seleccionado: day, week, month, year
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
    _selectedPeriod = 'all';
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
      } else if (_selectedPeriod == 'all') {
        // Si el filtro es "todos", no enviar período específico
        period = null;
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
            categoria: selectedCategory,
          );

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

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';

    double value = 0.0;
    if (amount is double) {
      value = amount;
    } else if (amount is int) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    }

    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(value);
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
        title: Text(
          'Platos Más Populares',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agregar DateFilterBar
          DateFilterBar(
            key: _dateFilterKey,
            initialFilter: _mapPeriodToFilter(_selectedPeriod),
            onFilterChanged: (String filter) {
              setState(() {
                _selectedPeriod = _mapFilterToPeriod(filter);
                // Si se cambia el filtro de período, mantener las categorías seleccionadas
                // para permitir una combinación de ambos filtros
              });
              _loadPopularDishes();
            },
            onCustomDateRangeSelected: (String startDate, String endDate) {
              setState(() {
                _startDate = DateFormat('yyyy-MM-dd').parse(startDate);
                _endDate = DateFormat('yyyy-MM-dd').parse(endDate);
                _selectedPeriod = 'custom';
                // No limpiar categorías al seleccionar un rango de fechas personalizado
              });
              _loadPopularDishes();
            },
          ),

          // Filtros de categoría
          if (_categories.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Categorías:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        if (_selectedCategories.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategories.clear();
                              });
                              _applyFilters();
                            },
                            child: const Text('Limpiar filtros'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children:
                          _categories
                              .map(
                                (category) => _buildCategoryFilter(
                                  category['name'] as String,
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
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
                            'No hay ventas disponibles',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedPeriod == 'custom'
                                ? 'No hay ventas en el rango de fechas seleccionado'
                                : 'No hay ventas para el período seleccionado',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedPeriod = 'all';
                                _selectedCategories.clear();
                              });
                              // Intentar actualizar el filtro en el DateFilterBar
                              _dateFilterKey.currentState?.updateFilter(
                                'todos',
                              );
                              _loadPopularDishes();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Mostrar todos los platos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
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
                                            ? CachedNetworkImage(
                                              imageUrl: dish['imagen_url'],
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              placeholder:
                                                  (context, url) => Container(
                                                    width: 56,
                                                    height: 56,
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.2),
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
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
                                                      ),
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
                                      dish['cantidad_vendida'] == 0
                                          ? 'Sin ventas en este período'
                                          : 'Vendidos: ${dish['cantidad_vendida']}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontFamily: 'MADE TOMMY',
                                            color:
                                                dish['cantidad_vendida'] == 0
                                                    ? Colors.grey
                                                    : null,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Precio del plato
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Precio: ${_formatCurrency(dish['precio'] ?? dish['precio_promedio'] ?? 0.0)}',
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
                                  dish['cantidad_vendida'] == 0
                                      ? 'N/A'
                                      : _formatCurrency(_calcularTotal(dish)),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        dish['cantidad_vendida'] == 0
                                            ? Colors.grey
                                            : Colors.green.shade700,
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

  // Mapea el período interno (week, day, etc.) al filtro del DateFilterBar (semana, hoy, etc.)
  String _mapPeriodToFilter(String period) {
    switch (period) {
      case 'day':
        return 'hoy';
      case 'week':
        return 'semana';
      case 'month':
        return 'mes';
      case 'year':
        return 'año';
      case 'custom':
        return 'personalizado';
      case 'all':
        return 'todos';
      default:
        return 'todos';
    }
  }

  // Mapea el filtro del DateFilterBar al período interno
  String _mapFilterToPeriod(String filter) {
    switch (filter) {
      case 'hoy':
        return 'day';
      case 'semana':
        return 'week';
      case 'mes':
        return 'month';
      case 'año':
        return 'year';
      case 'personalizado':
        return 'custom';
      case 'todos':
        return 'all';
      default:
        return 'all';
    }
  }

  // Método auxiliar para calcular el total de manera segura
  double _calcularTotal(Map<String, dynamic> dish) {
    // Obtener y convertir cantidad_vendida
    var cantidadVendida = dish['cantidad_vendida'];
    double cantidad = 0.0;
    if (cantidadVendida is int) {
      cantidad = cantidadVendida.toDouble();
    } else if (cantidadVendida is double) {
      cantidad = cantidadVendida;
    } else if (cantidadVendida is String) {
      cantidad = double.tryParse(cantidadVendida) ?? 0.0;
    }

    // Obtener y convertir precio
    var precio = dish['precio_promedio'] ?? dish['precio'] ?? 0.0;
    double precioFinal = 0.0;
    if (precio is int) {
      precioFinal = precio.toDouble();
    } else if (precio is double) {
      precioFinal = precio;
    } else if (precio is String) {
      precioFinal = double.tryParse(precio) ?? 0.0;
    }

    return cantidad * precioFinal;
  }
}
