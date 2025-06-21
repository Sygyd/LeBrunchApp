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
  bool _isFiltering = false; // Variable para controlar el estado de filtrado
  String? _error; // Definición de variable de error
  List<Map<String, dynamic>> _popularDishes = [];
  List<Map<String, dynamic>> _filteredDishes = [];
  String _selectedPeriod =
      'all'; // Período seleccionado: day, week, month, year

  // 🔄 NUEVO: Variable para debugging del estado
  String _debugEstado = 'completado';

  // ✨ OPTIMIZACIÓN: Estructura mejorada para categorías jerárquicas
  Map<String, List<Map<String, dynamic>>> _categoriesByType = {
    'comida': [],
    'bebida': [],
  };
  Map<String, bool> _selectedCategories =
      {}; // Categorías seleccionadas como Map
  String? _selectedMainType; // 'comida' o 'bebida' seleccionado

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
    _categoriesByType = {'comida': [], 'bebida': []};
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();

    // Cargar datos iniciales
    _loadCategoriesAndDishes();
  }

  // ✨ OPTIMIZACIÓN: Método mejorado para cargar categorías jerárquicas
  Future<void> _loadCategoriesAndDishes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Paso 1: Cargar las categorías organizadas por tipo
      await _loadCategoriesHierarchical();

      // Paso 2: Cargar los platos populares con límite aumentado
      await _loadPopularDishes(isInitialLoad: true);
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
      _showErrorSnackBar('Error al cargar datos: $e');
    }
  }

  // ✨ OPTIMIZACIÓN: Cargar categorías organizadas jerárquicamente
  Future<void> _loadCategoriesHierarchical() async {
    try {
      final menu = await _menuService.getDishes();

      // Agrupar categorías por tipo (comida/bebida)
      final Map<String, Set<String>> categoriesByType = {
        'comida': {},
        'bebida': {},
      };

      for (var item in menu) {
        if (item['categoria'] != null &&
            item['categoria'].toString().isNotEmpty &&
            item['tipo'] != null) {
          final tipo = item['tipo'].toString().toLowerCase();
          final categoria = item['categoria'].toString();

          if (tipo == 'comida' || tipo == 'bebida') {
            categoriesByType[tipo]?.add(categoria);
          }
        }
      }

      if (mounted) {
        setState(() {
          _categoriesByType = {
            'comida':
                categoriesByType['comida']!
                    .map(
                      (cat) => {
                        'id': cat,
                        'name': cat,
                        'type': 'comida',
                        'icon': 'restaurant',
                      },
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        (a['name'] as String).compareTo(b['name'] as String),
                  ),
            'bebida':
                categoriesByType['bebida']!
                    .map(
                      (cat) => {
                        'id': cat,
                        'name': cat,
                        'type': 'bebida',
                        'icon': 'local_cafe',
                      },
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        (a['name'] as String).compareTo(b['name'] as String),
                  ),
          };
        });
      }

      print('🔍 Categorías cargadas por tipo:');
      print('   Comida: ${_categoriesByType['comida']!.length} categorías');
      print('   Bebida: ${_categoriesByType['bebida']!.length} categorías');
    } catch (e) {
      print('⚠️ Error al cargar categorías: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar categorías: $e';
        });
      }
    }
  }

  // ✨ OPTIMIZACIÓN: Cargar platos populares con límite aumentado
  Future<void> _loadPopularDishes({bool isInitialLoad = false}) async {
    if (!mounted) return;

    // Usar _isFiltering para filtros y _isLoading solo para carga inicial
    setState(() {
      if (isInitialLoad) {
        _isLoading = true;
        _isFiltering = false;
      } else {
        _isLoading = false;
        _isFiltering = true;
      }
      _error = null;
    });

    try {
      final popularDishesService = PopularDishesService();

      String? startDateStr;
      String? endDateStr;
      String? period = _selectedPeriod;
      String? selectedCategory;

      // Calcular fechas específicas según el período seleccionado
      final DateTime now = DateTime.now();

      if (_selectedPeriod == 'custom' &&
          _startDate != null &&
          _endDate != null) {
        // Fechas personalizadas
        startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        period = null; // No enviar período si es personalizado
        print('📅 Usando fechas personalizadas: $startDateStr a $endDateStr');
      } else if (_selectedPeriod == 'day') {
        // HOY: desde las 00:00 hasta las 23:59 del día actual
        startDateStr = DateFormat('yyyy-MM-dd').format(now);
        endDateStr = DateFormat('yyyy-MM-dd').format(now);
        period = null; // Usar fechas específicas en lugar del período
        print('📅 Filtro HOY: $startDateStr (día completo)');
      } else if (_selectedPeriod == 'week') {
        // ESTA SEMANA: últimos 7 días incluyendo hoy
        final DateTime weekAgo = now.subtract(
          const Duration(days: 6),
        ); // 6 días atrás + hoy = 7 días
        startDateStr = DateFormat('yyyy-MM-dd').format(weekAgo);
        endDateStr = DateFormat('yyyy-MM-dd').format(now);
        period = null; // Usar fechas específicas en lugar del período
        print('📅 Filtro SEMANA: $startDateStr a $endDateStr (últimos 7 días)');
      } else if (_selectedPeriod == 'month') {
        // ESTE MES: últimos 30 días
        final DateTime monthAgo = now.subtract(
          const Duration(days: 29),
        ); // 29 días atrás + hoy = 30 días
        startDateStr = DateFormat('yyyy-MM-dd').format(monthAgo);
        endDateStr = DateFormat('yyyy-MM-dd').format(now);
        period = null; // Usar fechas específicas en lugar del período
        print('📅 Filtro MES: $startDateStr a $endDateStr (últimos 30 días)');
      } else if (_selectedPeriod == 'year') {
        // ESTE AÑO: últimos 365 días
        final DateTime yearAgo = now.subtract(
          const Duration(days: 364),
        ); // 364 días atrás + hoy = 365 días
        startDateStr = DateFormat('yyyy-MM-dd').format(yearAgo);
        endDateStr = DateFormat('yyyy-MM-dd').format(now);
        period = null; // Usar fechas específicas en lugar del período
        print('📅 Filtro AÑO: $startDateStr a $endDateStr (últimos 365 días)');
      } else if (_selectedPeriod == 'all') {
        // TODOS: no enviar fechas ni período
        period = null;
        startDateStr = null;
        endDateStr = null;
        print('📅 Filtro TODOS: sin restricciones de fecha');
      }

      // Determinar categoría para el filtro con prioridad correcta
      if (_selectedCategories.isNotEmpty) {
        // Si hay una categoría específica seleccionada, usarla con prioridad
        selectedCategory = _selectedCategories.keys.first;
        print(
          '📊 [OPTIMIZADO] Categoría específica seleccionada: $selectedCategory',
        );
      } else if (_selectedMainType != null) {
        // Si solo hay tipo principal seleccionado, usarlo
        selectedCategory = _selectedMainType;
        print('📊 [OPTIMIZADO] Tipo principal seleccionado: $selectedCategory');
      } else {
        // Sin filtros de categoría
        selectedCategory = null;
        print('📊 [OPTIMIZADO] Sin filtros de categoría aplicados');
      }

      print('🔄 Parámetros de consulta:');
      print('   📅 Período seleccionado en UI: $_selectedPeriod');
      print('   📅 Período enviado al servidor: $period');
      print('   📅 Fecha inicio enviada: $startDateStr');
      print('   📅 Fecha fin enviada: $endDateStr');
      print(
        '   🏷️ Filtro categoría: $selectedCategory (${_selectedMainType != null
            ? "tipo principal"
            : _selectedCategories.isNotEmpty
            ? "categoría específica"
            : "ninguno"})',
      );
      print('   📊 Límite de resultados: 50');

      // Log adicional para debugging
      if (startDateStr != null && endDateStr != null) {
        print('   ⏰ Rango de fechas activo: Sí');
        final startDate = DateTime.parse(startDateStr);
        final endDate = DateTime.parse(endDateStr);
        final daysDifference = endDate.difference(startDate).inDays + 1;
        print('   📊 Días incluidos en el filtro: $daysDifference');
      } else {
        print('   ⏰ Rango de fechas activo: No (todos los datos)');
      }

      // ✨ OPTIMIZACIÓN: Aumentar límite a 50 items o sin límite (SOLO COMPLETADOS)
      List<Map<String, dynamic>> result = await popularDishesService
          .getPopularDishesDirect(
            period: period,
            startDate: startDateStr,
            endDate: endDateStr,
            categoria: selectedCategory,
            limit: 50, // Aumentado de 20 a 50
            estado: _debugEstado, // 🔄 NUEVO: Usar estado de debug
          );

      if (mounted) {
        setState(() {
          _popularDishes = result;
          _filteredDishes = List.from(result); // Inicialmente mostrar todos
          _isLoading = false;
          _isFiltering = false;
        });

        // ✨ MEJORA: Aplicar filtros locales adicionales si es necesario
        _applyFilters();

        print('✅ Datos cargados: ${result.length} platos');
        if (result.isNotEmpty) {
          print('📊 Primeros 3 platos recibidos del servidor:');
          for (int i = 0; i < (result.length > 3 ? 3 : result.length); i++) {
            final dish = result[i];
            print(
              '   ${i + 1}. ${dish['nombre']} (${dish['tipo']}/${dish['categoria']}) - ${dish['cantidad_vendida']} vendidos',
            );
          }

          // Log adicional: verificar si hay datos que no deberían estar según el filtro
          if (_selectedPeriod == 'day') {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            print('🔍 VERIFICACIÓN FILTRO HOY ($today):');
            print('   → Se esperan solo platos vendidos HOY');
            print(
              '   → Si aparecen platos con ventas 0, revisar lógica del servidor',
            );
          } else if (_selectedPeriod == 'week') {
            final weekAgo = DateTime.now().subtract(const Duration(days: 6));
            final weekAgoStr = DateFormat('yyyy-MM-dd').format(weekAgo);
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            print('🔍 VERIFICACIÓN FILTRO SEMANA ($weekAgoStr a $today):');
            print('   → Se esperan solo platos vendidos en los últimos 7 días');
            print(
              '   → Si aparecen platos con ventas 0, revisar lógica del servidor',
            );
          }
        } else {
          print('⚠️ No se recibieron datos del servidor');
          if (_selectedPeriod == 'day') {
            print('   → Posible causa: No hay ventas registradas HOY');
          } else if (_selectedPeriod == 'week') {
            print(
              '   → Posible causa: No hay ventas registradas en los últimos 7 días',
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Error al cargar platos populares: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar platos populares: $e';
          _isLoading = false;
          _isFiltering = false;
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

  // ✨ OPTIMIZACIÓN: Filtros mejorados con soporte para tipos principales
  void _applyFilters() {
    if (_popularDishes.isEmpty) {
      setState(() {
        _filteredDishes = [];
      });
      return;
    }

    List<Map<String, dynamic>> filteredDishes = List.from(_popularDishes);

    // ✨ MEJORA: Si ya se filtró en el servidor, no necesitamos filtrar localmente
    // pero mantenemos la funcionalidad por compatibilidad

    // Filtrar por tipo principal (comida/bebida) - solo si no se hizo en servidor
    if (_selectedMainType != null && _selectedCategories.isEmpty) {
      filteredDishes =
          filteredDishes.where((dish) {
            final dishType = dish['tipo']?.toString().toLowerCase();
            final matches = dishType == _selectedMainType;
            if (!matches) {
              print(
                '🔍 Filtro local: Excluyendo ${dish['nombre']} (tipo: $dishType, buscando: $_selectedMainType)',
              );
            }
            return matches;
          }).toList();
      print(
        '🔍 Filtro local por tipo principal $_selectedMainType: ${filteredDishes.length} platos',
      );
    }

    // Filtrar por categoría específica - solo si no se hizo en servidor
    if (_selectedCategories.isNotEmpty) {
      filteredDishes =
          filteredDishes.where((dish) {
            if (dish['categoria'] == null ||
                dish['categoria'].toString().isEmpty) {
              return false;
            }

            for (var category in _selectedCategories.keys) {
              final matches =
                  dish['categoria'].toString().toLowerCase() ==
                  category.toLowerCase();
              if (matches) {
                return true;
              }
            }
            return false;
          }).toList();
      print(
        '🔍 Filtro local por categoría ${_selectedCategories.keys}: ${filteredDishes.length} platos',
      );
    }

    setState(() {
      _filteredDishes = filteredDishes;
    });

    print('🔍 Resumen de filtros aplicados:');
    print('   🏷️ Tipo principal: $_selectedMainType');
    print('   📂 Categorías específicas: ${_selectedCategories.keys}');
    print(
      '   📊 Platos mostrados: ${_filteredDishes.length} de ${_popularDishes.length}',
    );

    // Debug: mostrar tipos y categorías de los platos filtrados
    if (_filteredDishes.isNotEmpty && _filteredDishes.length <= 10) {
      print('📋 Platos después del filtro:');
      for (int i = 0; i < _filteredDishes.length; i++) {
        final dish = _filteredDishes[i];
        print(
          '   ${i + 1}. ${dish['nombre']} (${dish['tipo']}/${dish['categoria']})',
        );
      }
    }
  }

  // ✨ OPTIMIZACIÓN: Manejo mejorado de selección de tipo principal
  void _toggleMainType(String type) {
    setState(() {
      if (_selectedMainType == type) {
        // Si el mismo tipo está seleccionado, deseleccionar
        _selectedMainType = null;
      } else {
        // Seleccionar nuevo tipo y limpiar categorías específicas
        _selectedMainType = type;
        _selectedCategories.clear();
      }
      _applyFilters();
    });
  }

  // Maneja la selección/deselección de una categoría específica
  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.containsKey(category)) {
        // Si ya estaba seleccionada, deseleccionarla
        _selectedCategories.remove(category);
      } else {
        // Seleccionar categoría y limpiar tipo principal
        _selectedCategories.clear(); // Permitir solo una selección
        _selectedCategories[category] = true;
        _selectedMainType = null; // Limpiar selección de tipo principal
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
      // Mantener filtros de categoría al cambiar el período
      // _selectedCategories.clear(); // Comentado para mantener filtros

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
    _loadPopularDishes(isInitialLoad: false);
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
        // Mantener filtros de categoría al cambiar el período
      });

      // Recargar datos con el nuevo rango de fechas
      _loadPopularDishes(isInitialLoad: false);
    }
  }

  // ✨ OPTIMIZACIÓN: Widget para filtro de tipo principal (Comida/Bebida)
  Widget _buildMainTypeFilter(String type, String label, IconData icon) {
    final isSelected = _selectedMainType == type;
    final color = type == 'comida' ? Colors.orange : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : color),
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _toggleMainType(type),
        backgroundColor: Colors.white,
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  // Widget que construye un filtro de categoría específica
  Widget _buildCategoryFilter(String category, String type) {
    final isSelected = _selectedCategories.containsKey(category);
    final color = type == 'comida' ? Colors.orange : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (_) => _toggleCategory(category),
        backgroundColor: Colors.white,
        selectedColor: color.withOpacity(0.15),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.0),
          side: BorderSide(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
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
    final hasAnyCategories =
        _categoriesByType['comida']!.isNotEmpty ||
        _categoriesByType['bebida']!.isNotEmpty;

    return BackgroundScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
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
            Text(
              'Análisis de ventas',
              style: TextStyle(
                fontFamily: 'Lighthouse',
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
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
        actions: [
          // 🧪 BOTÓN TEMPORAL DE DEBUG - ELIMINAR DESPUÉS
          PopupMenuButton<String>(
            icon: Icon(Icons.bug_report, color: Colors.white),
            onSelected: (String estado) {
              setState(() {
                _debugEstado = estado;
              });
              _loadPopularDishes();
            },
            itemBuilder:
                (BuildContext context) => [
                  PopupMenuItem(value: 'todos', child: Text('Todos')),
                  PopupMenuItem(value: 'pendiente', child: Text('Pendientes')),
                  PopupMenuItem(
                    value: 'completado',
                    child: Text('Completados'),
                  ),
                  PopupMenuItem(value: 'cancelado', child: Text('Cancelados')),
                ],
          ),
        ],
      ),
      body:
          _isLoading &&
                  !_isFiltering // Solo mostrar loading completo en carga inicial
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () => _loadPopularDishes(isInitialLoad: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // DateFilterBar como sliver
                    SliverToBoxAdapter(
                      child: DateFilterBar(
                        key: _dateFilterKey,
                        initialFilter: _mapPeriodToFilter(_selectedPeriod),
                        onFilterChanged: (String filter) {
                          setState(() {
                            _selectedPeriod = _mapFilterToPeriod(filter);
                          });
                          _loadPopularDishes(
                            isInitialLoad: false,
                          ); // Cargar con filtrado
                        },
                        onCustomDateRangeSelected: (
                          String startDate,
                          String endDate,
                        ) {
                          setState(() {
                            _startDate = DateFormat(
                              'yyyy-MM-dd',
                            ).parse(startDate);
                            _endDate = DateFormat('yyyy-MM-dd').parse(endDate);
                            _selectedPeriod = 'custom';
                          });
                          _loadPopularDishes(
                            isInitialLoad: false,
                          ); // Cargar con filtrado
                        },
                      ),
                    ),

                    // Panel de filtros de categoría como sliver
                    SliverToBoxAdapter(child: _buildCategoryFiltersPanel()),

                    // Indicador sutil de filtrado
                    if (_isFiltering)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Actualizando datos...',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Lista de platos populares
                    if (_error != null)
                      SliverFillRemaining(child: _buildErrorState(theme))
                    else if (_filteredDishes.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState(theme))
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final dish = _filteredDishes[index];
                          return _buildDishCard(dish, theme, index);
                        }, childCount: _filteredDishes.length),
                      ),
                  ],
                ),
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

  Color _getRankingColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Oro para el primer lugar
      case 1:
        return Colors.grey.shade400; // Plata para el segundo lugar
      case 2:
        return Colors.brown.shade400; // Bronce para el tercer lugar
      default:
        return Colors.blue.shade400; // Azul para el resto
    }
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

  Widget _buildCategoryFiltersPanel() {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 3,
      color: theme.colorScheme.surface,
      shadowColor: theme.colorScheme.primary.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con botón limpiar - Mejorado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtros por categoría:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_selectedMainType != null || _selectedCategories.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error,
                        width: 1,
                      ),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedMainType = null;
                          _selectedCategories.clear();
                        });
                        _loadPopularDishes(isInitialLoad: false);
                      },
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Limpiar',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ✨ Filtros principales (Comida/Bebida) - Mejorados visualmente
            Text(
              'Tipos principales:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Filtro de Comida - Mejorado
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient:
                          _selectedMainType == 'comida'
                              ? LinearGradient(
                                colors: [
                                  Colors.orange.shade600,
                                  Colors.orange.shade500,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color:
                          _selectedMainType == 'comida'
                              ? null
                              : Colors.orange.shade50,
                      border: Border.all(
                        color: Colors.orange.shade600,
                        width: _selectedMainType == 'comida' ? 2 : 1,
                      ),
                      boxShadow:
                          _selectedMainType == 'comida'
                              ? [
                                BoxShadow(
                                  color: Colors.orange.shade600.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (_selectedMainType == 'comida') {
                              _selectedMainType = null;
                            } else {
                              _selectedMainType = 'comida';
                              _selectedCategories.clear();
                            }
                          });
                          _loadPopularDishes(isInitialLoad: false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant,
                                size: 20,
                                color:
                                    _selectedMainType == 'comida'
                                        ? Colors.white
                                        : Colors.orange.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Comida (${_categoriesByType['comida']!.length})',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        _selectedMainType == 'comida'
                                            ? Colors.white
                                            : Colors.orange.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filtro de Bebida - Mejorado
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient:
                          _selectedMainType == 'bebida'
                              ? LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.blue.shade500,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color:
                          _selectedMainType == 'bebida'
                              ? null
                              : Colors.blue.shade50,
                      border: Border.all(
                        color: Colors.blue.shade600,
                        width: _selectedMainType == 'bebida' ? 2 : 1,
                      ),
                      boxShadow:
                          _selectedMainType == 'bebida'
                              ? [
                                BoxShadow(
                                  color: Colors.blue.shade600.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (_selectedMainType == 'bebida') {
                              _selectedMainType = null;
                            } else {
                              _selectedMainType = 'bebida';
                              _selectedCategories.clear();
                            }
                          });
                          _loadPopularDishes(isInitialLoad: false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_cafe,
                                size: 20,
                                color:
                                    _selectedMainType == 'bebida'
                                        ? Colors.white
                                        : Colors.blue.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bebida (${_categoriesByType['bebida']!.length})',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        _selectedMainType == 'bebida'
                                            ? Colors.white
                                            : Colors.blue.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ✨ Indicador de subcategorías disponibles - Más visible
            if (_selectedMainType != null && _selectedCategories.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (_selectedMainType == 'comida'
                              ? Colors.orange
                              : Colors.blue)
                          .shade100,
                      (_selectedMainType == 'comida'
                              ? Colors.orange
                              : Colors.blue)
                          .shade50,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (_selectedMainType == 'comida'
                                ? Colors.orange
                                : Colors.blue)
                            .shade600,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 16,
                      color:
                          (_selectedMainType == 'comida'
                                  ? Colors.orange
                                  : Colors.blue)
                              .shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Elige una categoría específica de ${_selectedMainType} para filtrar más:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              (_selectedMainType == 'comida'
                                      ? Colors.orange
                                      : Colors.blue)
                                  .shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ✨ Subcategorías de Comida - Sin animaciones
            if (_selectedMainType == 'comida' &&
                _categoriesByType['comida']!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Categorías específicas de comida:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children:
                      _categoriesByType['comida']!.map<Widget>((category) {
                        final categoryName = category['name'] as String;
                        final isSelected = _selectedCategories.containsKey(
                          categoryName,
                        );
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient:
                                isSelected
                                    ? LinearGradient(
                                      colors: [
                                        Colors.orange.shade600,
                                        Colors.orange.shade500,
                                      ],
                                    )
                                    : null,
                            color: isSelected ? null : Colors.orange.shade50,
                            border: Border.all(
                              color: Colors.orange.shade600,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: Colors.orange.shade600
                                            .withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedCategories.remove(categoryName);
                                  } else {
                                    _selectedCategories.clear();
                                    _selectedCategories[categoryName] = true;
                                  }
                                });
                                _loadPopularDishes(isInitialLoad: false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  categoryName,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],

            // ✨ Subcategorías de Bebida - Sin animaciones
            if (_selectedMainType == 'bebida' &&
                _categoriesByType['bebida']!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Categorías específicas de bebida:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children:
                      _categoriesByType['bebida']!.map<Widget>((category) {
                        final categoryName = category['name'] as String;
                        final isSelected = _selectedCategories.containsKey(
                          categoryName,
                        );
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient:
                                isSelected
                                    ? LinearGradient(
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.blue.shade500,
                                      ],
                                    )
                                    : null,
                            color: isSelected ? null : Colors.blue.shade50,
                            border: Border.all(
                              color: Colors.blue.shade600,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: Colors.blue.shade600.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedCategories.remove(categoryName);
                                  } else {
                                    _selectedCategories.clear();
                                    _selectedCategories[categoryName] = true;
                                  }
                                });
                                _loadPopularDishes(isInitialLoad: false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  categoryName,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
        const SizedBox(height: 16),
        Text(
          'Error al cargar datos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Error desconocido',
          style: TextStyle(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _loadPopularDishes(isInitialLoad: false),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDishCard(Map<String, dynamic> dish, ThemeData theme, int index) {
    final nombre = dish['nombre'] ?? 'Sin nombre';
    final categoria = dish['categoria'] ?? 'Sin categoría';
    final precio = dish['precio'] ?? 0.0;
    final cantidadVendida = dish['cantidad_vendida'] ?? 0;
    final imagenUrl = dish['imagen_url'];
    final tipo = dish['tipo'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Ranking badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getRankingColor(index),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Imagen del plato
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  imagenUrl != null && imagenUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: imagenUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.restaurant),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.restaurant),
                            ),
                      )
                      : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.restaurant),
                      ),
            ),
            const SizedBox(width: 16),

            // Información del plato
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(tipo),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          categoria,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$cantidadVendida vendidos',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '\$${precio.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          'No hay platos populares',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No se encontraron platos para el período seleccionado',
          style: TextStyle(color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _loadPopularDishes(isInitialLoad: false),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String? tipo) {
    if (tipo?.toLowerCase() == 'bebida') {
      return Colors.blue.shade600;
    } else {
      return Colors.orange.shade600;
    }
  }

  // Cargar categorías disponibles desde el menú
  Future<void> _loadCategories() async {
    // Definir categorías estáticas basadas en el menú conocido
    setState(() {
      _categoriesByType['comida'] = [
        {'name': 'Tablas'},
        {'name': 'Panquecas'},
        {'name': 'Tostadas Francesas'},
        {'name': 'Gofres'},
        {'name': 'Omelettes'},
      ];
      _categoriesByType['bebida'] = [
        {'name': 'Expresos'},
        {'name': 'Frapuccinos'},
        {'name': 'Cold Brew'},
        {'name': 'Jugos'},
      ];
    });

    print('✅ Categorías cargadas');
  }
}
