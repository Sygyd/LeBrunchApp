import 'package:flutter/material.dart';
import '../../Api_services/cart_service.dart';
import '../../Api_services/gemini_service.dart';
import '../../models/cart_item.dart';
import '../Widgets/cart_item_card.dart';
import '../Widgets/custom_modal.dart';
import '../../Api_services/pedidos/create_order_service.dart';
import 'package:le_brunch_app/Api_services/pedidos/popular_dishes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/cart_event_bus.dart';
import 'dart:convert';
import '../../services/user_preferences_service.dart';

class CartScreen extends StatefulWidget {
  final bool isEmbedded;
  final Function(int)? onTabChange;

  const CartScreen({super.key, this.isEmbedded = false, this.onTabChange});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  final CartService _cartService = CartService();
  final GeminiService _geminiService = GeminiService();
  final PopularDishesService _popularDishesService = PopularDishesService();
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();
  // Lista modificable de items del carrito
  List<CartItem> _cartItems = [];
  List<Map<String, dynamic>> _recommendedDishes = [];
  bool _isLoading = true;
  bool _lastEmptyCart = true;

  // Suscripción al EventBus
  StreamSubscription<CartEvent>? _cartEventSubscription;

  @override
  void initState() {
    super.initState();
    print('📱 CartScreen: initState INICIADO');

    // Agregar observer para detectar cambios de estado de la app
    WidgetsBinding.instance.addObserver(this);

    // Suscribirse a eventos INMEDIATAMENTE para no perder ningún evento
    _subscribeToCartEvents();

    // OPTIMIZACIÓN: Cargar datos inmediatamente si están disponibles
    final currentItems = _cartService.items;
    if (currentItems.isNotEmpty) {
      print(
        '📱 CartScreen: Datos encontrados inmediatamente, cargando sin delay',
      );
      _cartItems = List<CartItem>.from(currentItems);
      _isLoading = false;
      // Cargar recomendaciones en background sin bloquear UI
      Future.microtask(() => _loadRecommendationsQuietly());
    }

    // Inicialización ligera en background
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('📱 CartScreen: addPostFrameCallback ejecutándose');
      await _initializeCartOptimized();
      _checkChatSync();
      // Verificar si llegamos desde ChatScreen (importante para la integración con chat)
      await _checkIfCameFromChat();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Cuando la app vuelve al primer plano, verificar si hay cambios en el carrito
    if (state == AppLifecycleState.resumed && mounted) {
      print(
        '📱 CartScreen: App volvió al primer plano, refrescando carrito...',
      );
      _refreshCartQuietly();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('📱 CartScreen: didChangeDependencies ejecutándose');

    // Verificar si hay cambios en el carrito cada vez que las dependencias cambian
    if (mounted) {
      _refreshCartQuietly();
    }
  }

  @override
  void dispose() {
    // Cancelar la suscripción al EventBus
    _cartEventSubscription?.cancel();
    // Cancelar timer de recomendaciones
    _recommendationsTimer?.cancel();
    // Remover observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refrescar carrito sin mostrar loading
  Future<void> _refreshCartQuietly() async {
    try {
      print('📱 CartScreen: Refrescando carrito silenciosamente...');

      // Obtener items más recientes del servicio
      final items = _cartService.items;
      print('📱 CartScreen: Items encontrados: ${items.length}');

      // Actualizar solo si hay diferencias
      if (items.length != _cartItems.length) {
        print(
          '📱 CartScreen: Detectado cambio en carrito (${_cartItems.length} -> ${items.length})',
        );
        setState(() {
          _cartItems = List<CartItem>.from(items);
        });
      }
    } catch (e) {
      print('❌ Error al refrescar carrito silenciosamente: $e');
    }
  }

  // Cargar recomendaciones en background sin afectar UI
  Future<void> _loadRecommendationsQuietly() async {
    try {
      if (_cartItems.isEmpty) return;

      print('📱 CartScreen: Cargando recomendaciones en background...');

      // Solo cargar si no tenemos recomendaciones
      if (_recommendedDishes.isEmpty) {
        final recommendations = await _generateRecommendations();
        if (mounted && recommendations.isNotEmpty) {
          setState(() {
            _recommendedDishes = recommendations.take(3).toList();
          });
        }
      }
    } catch (e) {
      print('❌ Error al cargar recomendaciones silenciosamente: $e');
    }
  }

  // Inicialización optimizada y ligera
  Future<void> _initializeCartOptimized() async {
    try {
      // Solo hacer verificaciones básicas si ya tenemos datos cargados
      if (_cartItems.isNotEmpty) {
        print(
          '📱 CartScreen: Items ya cargados, solo verificando contadores...',
        );
        await _syncCountersOnly();
        return;
      }

      print('📱 CartScreen: Carga completa necesaria...');

      // Solo cargar si realmente no hay datos
      setState(() {
        _isLoading = true;
      });

      // Carga robusta pero sin ensureCartSynchronized pesado
      final items = await _cartService.getCartItemsWithSync();

      if (mounted) {
        setState(() {
          _cartItems = List<CartItem>.from(items);
          _isLoading = false;
        });

        // Cargar recomendaciones en background
        if (_cartItems.isNotEmpty) {
          Future.microtask(() => _loadRecommendationsQuietly());
        }
      }
    } catch (e) {
      print('❌ Error en inicialización optimizada: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Solo sincronizar contadores sin recargar todo
  Future<void> _syncCountersOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemCount = _cartItems.length;

      await prefs.setInt('cart_item_count', itemCount);
      await prefs.setInt('current_cart_count', itemCount);
      await prefs.setInt('last_nav_cart_count', itemCount);
      await prefs.setInt('nav_bar_badge_count', itemCount);

      print('📱 CartScreen: Contadores sincronizados: $itemCount');
    } catch (e) {
      print('❌ Error al sincronizar contadores: $e');
    }
  }

  // Método separado para inicialización del carrito
  Future<void> _initializeCart() async {
    print('📱 CartScreen: _initializeCart INICIANDO');

    setState(() {
      _isLoading = true;
    });

    try {
      // CRÍTICO: Verificar el estado del CartService ANTES de hacer cualquier cosa
      print('🔍 CartScreen: Estado inicial del CartService:');
      print('   - Items en memoria: ${_cartService.items.length}');
      print('   - Item count: ${_cartService.itemCount}');
      print(
        '   - IsInitialized: ${_cartService.toString().contains('_isInitialized')}',
      );

      // Verificar qué userId está usando el CartService
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('current_user_id');
      final userIdFromPrefs = prefs.getInt('user_id');
      print('   - UserId en SharedPrefs (current_user_id): $storedUserId');
      print('   - UserId en SharedPrefs (user_id): $userIdFromPrefs');

      print('📱 CartScreen: Obteniendo items directamente del servicio...');

      // 1. PRIMERO obtener items directos del servicio (sin reset para no perder datos)
      final directItems = _cartService.items;
      print(
        '📱 CartScreen: Items directos del servicio: ${directItems.length}',
      );

      // 2. También cargar desde almacenamiento para estar seguros
      final storedItems = await _cartService.getCartItemsWithSync();
      print('📱 CartScreen: Items desde almacenamiento: ${storedItems.length}');

      // 3. CRÍTICO: Si el servicio está vacío pero hay datos en SharedPreferences, forzar recuperación
      if (directItems.isEmpty && storedItems.isEmpty) {
        print('🔍 CartScreen: Ambas fuentes vacías, verificando contadores...');
        final badgeCount = prefs.getInt('nav_bar_badge_count') ?? 0;
        final cartItemCount = prefs.getInt('cart_item_count') ?? 0;

        print('   - Badge count: $badgeCount');
        print('   - Cart item count: $cartItemCount');

        if (badgeCount > 0 || cartItemCount > 0) {
          print(
            '⚠️ CartScreen: DISCREPANCIA DETECTADA - contadores indican items pero carrito vacío',
          );
          print(
            '🔧 CartScreen: Intentando recuperación desde todas las claves posibles...',
          );

          // Intentar cargar directamente desde las claves de storage específicas
          await _forceLoadFromAllStorageKeys();
        }
      }

      // 4. Usar los que tengan más items (probablemente los más actualizados)
      final items =
          directItems.length >= storedItems.length ? directItems : storedItems;
      print(
        '📱 CartScreen: Usando ${items.length} items (fuente: ${directItems.length >= storedItems.length ? "servicio" : "almacenamiento"})',
      );

      // 4. SIEMPRE usar los items encontrados (sin lógica compleja de recuperación)
      setState(() {
        _cartItems = List<CartItem>.from(items);
        _isLoading = false;
      });

      print('📱 CartScreen: Estado actualizado con ${_cartItems.length} items');

      // Debug: Mostrar los items cargados
      for (int i = 0; i < _cartItems.length; i++) {
        final item = _cartItems[i];
        print('   Item $i: ${item.name} x${item.quantity} (\$${item.price})');
      }

      // 3. Verificar contador y actualizar SharedPreferences
      final itemCount = _cartItems.length;

      // Guardar contador en todas las claves para máxima consistencia
      await prefs.setInt('cart_item_count', itemCount);
      await prefs.setInt('current_cart_count', itemCount);
      await prefs.setInt('last_nav_cart_count', itemCount);
      await prefs.setInt('nav_bar_badge_count', itemCount);

      // Guardar timestamp para diagnóstico
      await prefs.setString(
        'cart_last_load_timestamp',
        DateTime.now().toIso8601String(),
      );

      // 4. Suscribirse a eventos para mantener sincronización
      _subscribeToCartEvents();

      // 5. Cargar recomendaciones si hay items
      if (_cartItems.isNotEmpty) {
        _loadRecommendations();
      }

      // 6. Solo sincronizar contadores (sin sincronización pesada)
      await _syncCountersOnly();
    } catch (e) {
      print('❌ Error en inicialización del carrito: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Verificar y corregir contadores del carrito
  Future<void> _verifyCartCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final badgeCount = prefs.getInt('last_nav_cart_count') ?? -1;
      final serviceCount = _cartService.itemCount;

      if (badgeCount != serviceCount) {
        print(
          '⚠️ CartScreen: Discrepancia detectada: Badge=$badgeCount vs Service=$serviceCount',
        );
        // Corregir contadores
        await prefs.setInt('cart_item_count', serviceCount);
        await prefs.setInt('current_cart_count', serviceCount);
        await prefs.setInt('last_nav_cart_count', serviceCount);
      }
    } catch (e) {
      print('❌ Error al verificar contadores: $e');
    }
  }

  // Método para suscribirse a los eventos del carrito
  void _subscribeToCartEvents() {
    print('📱 CartScreen: Configurando suscripción a eventos del carrito...');

    // Cancelar suscripción anterior si existe
    _cartEventSubscription?.cancel();

    _cartEventSubscription = _cartService.cartEvents.listen((event) {
      print('📱 CartScreen: Evento de carrito recibido - ${event.type}');
      print('📱 CartScreen: Datos del evento: ${event.data}');

      // Para cualquier cambio en el carrito, actualizar inmediatamente
      if (mounted) {
        // Obtener items más recientes del servicio
        final items = _cartService.items;
        print('📱 CartScreen: Items actuales en servicio: ${items.length}');

        // Manejar específicamente la navegación desde Chat
        if (event.type == CartEventType.navToCartFromChat) {
          print('⭐ CartScreen: Detectado evento de navegación desde Chat');

          setState(() {
            _cartItems = List<CartItem>.from(items);
            _isLoading = false;
          });

          // Mostrar mensaje de confirmación
          if (mounted && _cartItems.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Items del chat agregados al carrito (${_cartItems.length})',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Cargar recomendaciones basadas en los nuevos items
          _loadRecommendations();
          return;
        }

        // Para CUALQUIER otro evento, actualizar inmediatamente
        print('📱 CartScreen: Actualizando UI con ${items.length} items');

        setState(() {
          _cartItems = List<CartItem>.from(items);
          _isLoading = false;
        });

        // Actualizar recomendaciones solo si el carrito cambió significativamente
        if (event.type == CartEventType.itemAdded ||
            event.type == CartEventType.cartCleared ||
            event.type == CartEventType.cartLoaded ||
            event.type == CartEventType.forceRefresh) {
          print(
            '📱 CartScreen: Cargando recomendaciones debido a ${event.type}',
          );
          _loadRecommendations();
        }
      }
    });

    print('📱 CartScreen: Suscripción a eventos configurada exitosamente');
  }

  /// Refrescar los datos del carrito
  Future<void> _refreshCart() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // 1. Obtener los datos más actualizados del carrito
      final cartService = CartService();

      // Forzar una carga completa desde almacenamiento
      final items = await cartService.getCartItemsWithSync();

      // 2. Verificar si hay datos y actualizar UI
      if (mounted) {
        setState(() {
          _cartItems = items;
          _isLoading = false;
          _recommendedDishes =
              []; // Limpiar recomendaciones para forzar recarga
        });

        // 3. Verificar si hay ítems y actualizar recomendaciones si es necesario
        if (_cartItems.isNotEmpty) {
          _loadRecommendations();
        }

        print(
          '🔄 CartScreen: Carrito actualizado con ${_cartItems.length} ítems',
        );
      }

      // 4. Verificar si hay estado inconsistente en el contador del badge
      final prefs = await SharedPreferences.getInstance();
      final badgeCount = prefs.getInt('nav_bar_badge_count') ?? 0;

      // Si hay discrepancia entre el badge y el carrito actual, corregir
      if (badgeCount != _cartItems.length) {
        await prefs.setInt('nav_bar_badge_count', _cartItems.length);
        await prefs.setInt('cart_item_count', _cartItems.length);
        await prefs.setInt('current_cart_count', _cartItems.length);
        print(
          '⚠️ Corregida discrepancia de contador: Badge=$badgeCount vs Carrito=${_cartItems.length}',
        );
      }
    } catch (e) {
      print('❌ Error al refrescar carrito: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Genera recomendaciones basadas en el carrito actual
  Future<List<Map<String, dynamic>>> _generateRecommendations() async {
    try {
      // Obtener los platos más populares usando el servicio especializado
      final popularDishes = await _popularDishesService.getPopularDishesDirect(
        period: 'month', // Usar datos del último mes
        limit: 6, // Obtener más platos de los necesarios para filtrado
      );

      print(
        '📊 Obtenidos ${popularDishes.length} platos populares para recomendaciones',
      );

      // Filtrar platos que ya están en el carrito
      final cartItemIds = _cartItems.map((item) => item.id).toSet();

      final filteredDishes =
          popularDishes.where((dish) {
            final dishId = dish['idplato']?.toString() ?? '';
            return !cartItemIds.contains(dishId);
          }).toList();

      // Si no hay suficientes recomendaciones después de filtrar, añadir algunos aleatorios
      if (filteredDishes.length < 3) {
        // Obtener platos aleatorios del menú como respaldo
        final menuItems = await _geminiService.getFullMenu();

        // Filtrar los que ya están en el carrito o en las recomendaciones
        final existingIds = {
          ...cartItemIds,
          ...filteredDishes.map((dish) => dish['idplato']?.toString() ?? ''),
        };

        final additionalItems =
            menuItems?.where((dish) {
              final dishId = dish['idplato']?.toString() ?? '';
              return !existingIds.contains(dishId);
            }).toList() ??
            [];

        // Mezclar para obtener resultados aleatorios
        if (additionalItems.isNotEmpty) {
          additionalItems.shuffle();
          filteredDishes.addAll(
            additionalItems
                .take(3 - filteredDishes.length)
                .cast<Map<String, dynamic>>(),
          );
        }
      }

      return filteredDishes.take(3).toList();
    } catch (e) {
      print('Error al generar recomendaciones: $e');
      return [];
    }
  }

  // Añadir este método en _CartScreenState
  Future<void> _checkChatSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_chat_cart_sync');

    if (lastSync != null) {
      final data = jsonDecode(lastSync);
      final syncTime = DateTime.parse(data['timestamp']);

      // Sincronizar solo si es reciente (últimos 5 minutos)
      if (DateTime.now().difference(syncTime) < Duration(minutes: 5)) {
        final items = List<Map<String, dynamic>>.from(data['items']);

        setState(() {
          _cartItems =
              items
                  .map(
                    (item) => CartItem(
                      id: item['idplato']?.toString() ?? UniqueKey().toString(),
                      name: item['nombre'],
                      price: double.parse(item['precio'].toString()),
                      imageUrl: item['imagen_url'] ?? '',
                      quantity: item['quantity'] ?? 1,
                      notes: item['notes'],
                      originalData: item,
                    ),
                  )
                  .toList();
        });

        // Mostrar feedback al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${items.length} ítems añadidos desde el chat'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  void _addRecommendedDishToCart(Map<String, dynamic> dish) async {
    try {
      final name = dish['nombre'] as String;
      final price = double.parse(dish['precio'].toString());
      final imageUrl = dish['imagen_url'] as String?;
      final id =
          dish['idplato']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Usar los parámetros nombrados correctamente según el método en CartService
      _cartService.addItem(
        id: id,
        name: name,
        price: price,
        imageUrl: imageUrl ?? '',
        quantity: 1,
        originalData: dish,
      );

      // Actualizar preferencias del usuario
      await _userPreferencesService.updateOrderedDish(name);

      // Mostrar mensaje de confirmación
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('¡$name añadido al carrito!')));
    } catch (e) {
      print('Error al añadir plato recomendado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo añadir el plato al carrito.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('📱 CartScreen: build() ejecutándose');
    print('📱 CartScreen: _isLoading = $_isLoading');
    print('📱 CartScreen: _cartItems.length = ${_cartItems.length}');

    // Debug: Mostrar items actuales en el build
    if (_cartItems.isNotEmpty) {
      print('📱 CartScreen: Items en _cartItems:');
      for (int i = 0; i < _cartItems.length; i++) {
        final item = _cartItems[i];
        print('   ${i + 1}. ${item.name} x${item.quantity} (\$${item.price})');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          // Botón para sincronizar el contador del badge con el carrito
          IconButton(
            icon: Icon(Icons.sync),
            tooltip: 'Sincronizar contador',
            onPressed: () async {
              try {
                setState(() {
                  _isLoading = true;
                });

                final prefs = await SharedPreferences.getInstance();
                final badgeCount = prefs.getInt('nav_bar_badge_count') ?? 0;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sincronizando contador: $badgeCount'),
                    duration: Duration(milliseconds: 1000),
                  ),
                );

                // Si hay un contador en la barra pero el carrito está vacío, intentar recuperación
                if (badgeCount > 0 && _cartItems.isEmpty) {
                  final recoveredItems = await _tryRecoverItemsFromPrefs();

                  if (recoveredItems.isNotEmpty) {
                    setState(() {
                      _cartItems = recoveredItems;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Items recuperados: ${recoveredItems.length}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No se pudieron recuperar los items'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }

                setState(() {
                  _isLoading = false;
                });
              } catch (e) {
                print('❌ Error al sincronizar contador: $e');
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
          // Botón para forzar recarga del carrito
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Forzar recarga',
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });

              // Mostrar mensaje de carga
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Recargando carrito...'),
                  duration: Duration(milliseconds: 1000),
                ),
              );

              // MEJOR: Solo forzar actualización ligera
              await _refreshCartQuietly();

              // Mostrar datos actualizados
              if (mounted) {
                setState(() {
                  _cartItems = List<CartItem>.from(_cartService.items);
                });
              }
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _cartItems.isEmpty
              ? SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tu carrito está vacío',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Agrega productos desde el menú o pide recomendaciones a Brunchy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: Icon(Icons.menu_book),
                              label: Text('Ver menú'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                // Implementar navegación al menú
                                if (widget.isEmbedded &&
                                    widget.onTabChange != null) {
                                  // Registrar la navegación antes de cambiar
                                  await _registerNavigationFromCart(1);
                                  widget.onTabChange!(1);
                                } else {
                                  // Registrar la navegación
                                  await _registerNavigationFromCart(1);

                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setInt('navigate_to_tab', 1);
                                  await prefs.setString(
                                    'navigation_timestamp',
                                    DateTime.now().toIso8601String(),
                                  );
                                  if (mounted) {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/client_home',
                                      (route) => false,
                                      arguments: {'initialIndex': 1},
                                    );
                                  }
                                }
                              },
                            ),
                            // Agregar un botón para verificar inconsistencias si el badge muestra items pero la pantalla está vacía
                            FutureBuilder<int>(
                              future: _getCartCountFromBadge(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data! > 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: TextButton.icon(
                                      icon: Icon(Icons.sync_problem),
                                      label: Text(
                                        'Verificar items del carrito (${snapshot.data})',
                                      ),
                                      onPressed: () {
                                        // Forzar actualización completa del carrito
                                        _forceRefreshCart();
                                      },
                                    ),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Mostrar recomendaciones incluso cuando el carrito está vacío
                    if (_recommendedDishes.isNotEmpty)
                      _buildRecommendedSection(),

                    // Mover el botón de actualizar después de las recomendaciones
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: TextButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Actualizar recomendaciones'),
                        onPressed: () async {
                          setState(() {
                            _isLoading = true;
                          });
                          await _forceRefreshCart();
                        },
                      ),
                    ),

                    // Mostrar indicador de carga si no hay recomendaciones todavía
                    if (_recommendedDishes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                'Cargando recomendaciones...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              CircularProgressIndicator(strokeWidth: 2),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
              : Stack(
                children: [
                  ListView(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return Dismissible(
                            key: Key(item.id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) async {
                              _cartService.removeItem(item.id);
                              setState(() {
                                _cartItems = List<CartItem>.from(_cartItems)
                                  ..removeAt(index);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${item.name} eliminado del carrito',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: CartItemCard(
                              item: item,
                              onIncrease: () async {
                                _cartService.updateQuantity(
                                  item.id,
                                  item.quantity + 1,
                                );

                                // Optimistic update - actualizar UI inmediatamente
                                setState(() {
                                  _cartItems = List<CartItem>.from(_cartItems);
                                  _cartItems[index] = _cartItems[index]
                                      .copyWith(quantity: item.quantity + 1);
                                });
                              },
                              onDecrease: () async {
                                if (item.quantity > 1) {
                                  _cartService.updateQuantity(
                                    item.id,
                                    item.quantity - 1,
                                  );

                                  // Optimistic update - actualizar UI inmediatamente
                                  setState(() {
                                    _cartItems = List<CartItem>.from(
                                      _cartItems,
                                    );
                                    _cartItems[index] = _cartItems[index]
                                        .copyWith(quantity: item.quantity - 1);
                                  });
                                } else {
                                  _cartService.removeItem(item.id);

                                  // Optimistic update - actualizar UI inmediatamente
                                  setState(() {
                                    _cartItems = List<CartItem>.from(_cartItems)
                                      ..removeAt(index);
                                  });
                                }
                              },
                              onRemove: () async {
                                _cartService.removeItem(item.id);

                                // Optimistic update - actualizar UI inmediatamente
                                setState(() {
                                  _cartItems = List<CartItem>.from(_cartItems)
                                    ..removeAt(index);
                                });
                              },
                              onUpdateNotes: (newNotes) async {
                                _cartService.updateNotes(item.id, newNotes);

                                // Optimistic update - actualizar UI inmediatamente
                                setState(() {
                                  _cartItems = List<CartItem>.from(_cartItems);
                                  _cartItems[index] = _cartItems[index]
                                      .copyWith(notes: newNotes);
                                });
                              },
                            ),
                          );
                        },
                      ),
                      // Mostrar recomendaciones si hay
                      if (_recommendedDishes.isNotEmpty)
                        _buildRecommendedSection(),
                      const SizedBox(height: 140),
                    ],
                  ),
                  // Botón para proceder al checkout y total
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildCheckoutBar(),
                  ),
                ],
              ),
    );
  }

  Widget _buildRecommendedSection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Recomendaciones para ti',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedDishes.length,
              itemBuilder: (context, index) {
                final dish = _recommendedDishes[index];
                return GestureDetector(
                  onTap: () => _addRecommendedDishToCart(dish),
                  child: Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Image.network(
                            dish['imagen_url'] ??
                                'https://via.placeholder.com/120',
                            height: 70,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.grey[600],
                                  ),
                                ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish['nombre'] ?? 'Plato',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '\$${dish['precio'] ?? '0.00'}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
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

  Widget _buildCheckoutBar() {
    // Calcular el total directamente desde los items en pantalla
    // para evitar discrepancias entre la pantalla y el CartService
    final totalAmount = _cartItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final itemCount = _cartItems.fold(0, (sum, item) => sum + item.quantity);

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ($itemCount items)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmOrder,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmar Pedido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (BuildContext dialogContext) =>
                const Center(child: CircularProgressIndicator()),
      );

      final cartItems = _cartItems; // Usar la lista actual en pantalla

      if (cartItems.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop();
          await CustomModal.showError(
            context: context,
            title: 'Carrito Vacío',
            message: 'No hay productos en el carrito para confirmar el pedido.',
            buttonText: 'Entendido',
          );
        }
        return;
      }

      final createOrderService = CreateOrderService();
      final result = await createOrderService.createOrder(cartItems);

      if (!context.mounted) return;

      Navigator.of(context).pop();

      if (result['success']) {
        final orderId = result['orderData']?['idpedido'];
        if (orderId != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('current_order_id', orderId);
          } catch (e) {
            print('Error al guardar el ID del pedido: $e');
          }
        }

        // Actualizar las preferencias del usuario con los platos ordenados
        try {
          final userPreferencesService = UserPreferencesService();
          for (var item in cartItems) {
            await userPreferencesService.updateOrderedDish(item.name);
          }
          print('✅ Preferencias de usuario actualizadas correctamente');
        } catch (e) {
          print('❌ Error al actualizar preferencias de usuario: $e');
        }

        _cartService.clear();

        // Actualizar UI inmediatamente (optimistic update)
        setState(() {
          _cartItems = [];
          _recommendedDishes = [];
        });

        // Forzar una notificación explícita para que todos los componentes sepan que el carrito está vacío
        await _cartService.forceNotifyListeners();

        if (context.mounted) {
          await CustomModal.showSuccess(
            context: context,
            title: '¡Pedido Confirmado!',
            message:
                'Tu pedido ${orderId != null ? "#$orderId" : ""} ha sido confirmado con éxito.',
            buttonText: 'Aceptar',
            onPressed: () {},
          );

          if (widget.isEmbedded && widget.onTabChange != null) {
            widget.onTabChange!(0);
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (context.mounted) {
          await CustomModal.showError(
            context: context,
            title: 'Error al Confirmar Pedido',
            message: result['message'] ?? 'No se pudo crear el pedido',
            buttonText: 'Entendido',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();

        await CustomModal.showError(
          context: context,
          title: 'Error Inesperado',
          message: 'Ocurrió un error al procesar tu pedido: $e',
          buttonText: 'Entendido',
        );
      }
    }
  }

  // Método para forzar la actualización completa del carrito
  Future<void> _forceRefreshCart() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Mostrar mensaje de actualización
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Actualizando carrito...'),
          duration: Duration(milliseconds: 1000),
        ),
      );

      // 1. Obtener datos actuales del servicio
      final cartService = CartService();
      final currentItems = cartService.items;

      // 2. Actualizar UI inmediatamente si hay datos
      if (currentItems.isNotEmpty && mounted) {
        setState(() {
          _cartItems = List<CartItem>.from(currentItems);
          _isLoading = false;
        });
      } else {
        // Solo hacer carga completa si no hay datos inmediatos
        await _refreshCart();
      }

      // 3. Forzar actualización del contador en la barra de navegación
      await cartService.saveCountToSharedPrefs();

      // 4. Verificar si hay discrepancias
      await _verifyCartCounters();

      // 5. Notificar éxito si se encontraron items
      if (_cartItems.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Carrito actualizado: ${_cartItems.length} items'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al forzar actualización del carrito: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar carrito'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Debounce para evitar múltiples cargas simultáneas
  Timer? _recommendationsTimer;
  bool _isLoadingRecommendations = false;

  // Método para cargar recomendaciones con debounce
  Future<void> _loadRecommendations() async {
    // Cancelar timer previo si existe
    _recommendationsTimer?.cancel();

    // Evitar múltiples cargas simultáneas
    if (_isLoadingRecommendations) {
      print(
        '📱 CartScreen: Carga de recomendaciones ya en progreso, saltando...',
      );
      return;
    }

    // Solo cargar si no tenemos recomendaciones
    if (_recommendedDishes.isNotEmpty) {
      print('📱 CartScreen: Recomendaciones ya cargadas, saltando...');
      return;
    }

    // Debounce: Esperar 500ms antes de cargar
    _recommendationsTimer = Timer(Duration(milliseconds: 500), () async {
      await _loadRecommendationsInternal();
    });
  }

  // Método interno para cargar recomendaciones
  Future<void> _loadRecommendationsInternal() async {
    if (_isLoadingRecommendations) return;

    _isLoadingRecommendations = true;
    try {
      print('📱 CartScreen: Cargando recomendaciones...');
      final recommendations = await _generateRecommendations();
      if (mounted && recommendations.isNotEmpty) {
        setState(() {
          _recommendedDishes = recommendations.take(3).toList();
        });
        print(
          '📱 CartScreen: ${_recommendedDishes.length} recomendaciones cargadas',
        );
      }
    } catch (e) {
      print('❌ Error al cargar recomendaciones: $e');
    } finally {
      _isLoadingRecommendations = false;
    }
  }

  /// Método para registrar la navegación desde CartScreen a otra pantalla
  Future<void> _registerNavigationFromCart(int toScreenIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      // Registrar que estamos navegando desde el carrito
      await prefs.setBool('navigating_from_cart_screen', true);
      await prefs.setString('cart_exit_timestamp', timestamp);

      // Registrar el contador actual de forma redundante
      final cartService = CartService();
      final currentCount = cartService.itemCount;

      // Guardar en todas las claves posibles para máxima redundancia
      await prefs.setInt('cart_count_before_navigation', currentCount);
      await prefs.setInt('cart_item_count', currentCount);
      await prefs.setInt('current_cart_count', currentCount);
      await prefs.setInt('last_nav_cart_count', currentCount);
      await prefs.setInt('nav_bar_badge_count', currentCount);

      // Si navegamos específicamente a la pantalla de chat (índice 2)
      if (toScreenIndex == 2) {
        print(
          '⚠️ CartScreen: Navegando a ChatScreen, guardando contador: $currentCount',
        );
        await prefs.setBool('coming_from_cart_screen', true);
        await prefs.setString('cart_to_chat_timestamp', timestamp);

        // Guardar información para asegurar que el contador se mantenga
        await prefs.setInt('cart_count_for_chat', currentCount);
        await prefs.setString(
          'cart_items_backup',
          jsonEncode(
            cartService.items
                .map(
                  (item) => {
                    'id': item.id,
                    'name': item.name,
                    'price': item.price,
                    'imageUrl': item.imageUrl,
                    'quantity': item.quantity,
                    'notes': item.notes,
                    'originalData': item.originalData,
                  },
                )
                .toList(),
          ),
        );
      }

      print(
        '✅ CartScreen: Navegación registrada a pantalla $toScreenIndex con contador: $currentCount',
      );
    } catch (e) {
      print('❌ Error al registrar navegación desde carrito: $e');
    }
  }

  // Método para intentar recuperar items del carrito desde SharedPreferences
  Future<List<CartItem>> _tryRecoverItemsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Buscar en las posibles claves de backup
      final backupKeys = ['cart_items_backup', 'cart_backup_data'];
      String? backupData;

      for (final key in backupKeys) {
        final data = prefs.getString(key);
        if (data != null && data.isNotEmpty) {
          backupData = data;
          print('📱 CartScreen: Encontrado backup en $key');
          break;
        }
      }

      // Si encontramos datos de backup, intentar reconstruir los items
      if (backupData != null && backupData.isNotEmpty) {
        try {
          final List<dynamic> decodedData = jsonDecode(backupData);
          print(
            '📱 CartScreen: Decodificados ${decodedData.length} items del backup',
          );

          // Reconstruir los items
          final recoveredItems =
              decodedData
                  .map((itemData) {
                    try {
                      return CartItem(
                        id: itemData['id'] ?? '',
                        name: itemData['name'] ?? 'Item sin nombre',
                        price: (itemData['price'] ?? 0.0).toDouble(),
                        imageUrl: itemData['imageUrl'] ?? '',
                        quantity: itemData['quantity'] ?? 1,
                        notes: itemData['notes'],
                        originalData: itemData['originalData'] ?? {},
                      );
                    } catch (e) {
                      print('❌ Error al reconstruir item del backup: $e');
                      return null;
                    }
                  })
                  .whereType<CartItem>()
                  .toList();

          if (recoveredItems.isNotEmpty) {
            // Si recuperamos items, también actualizarlos en el servicio
            final cartService = CartService();

            // Desactivar notificaciones durante la actualización masiva
            cartService.setNotificationsEnabled(false);

            // Limpiar el carrito actual
            await cartService.clear();

            // Añadir cada item recuperado
            for (final item in recoveredItems) {
              await cartService.addItem(
                id: item.id,
                name: item.name,
                price: item.price,
                imageUrl: item.imageUrl,
                quantity: item.quantity,
                notes: item.notes,
                originalData: item.originalData,
              );
            }

            // Reactivar notificaciones
            cartService.setNotificationsEnabled(true);

            // Forzar actualización de todos los contadores
            await cartService.saveCountToSharedPrefs();

            print(
              '✅ CartScreen: ${recoveredItems.length} items recuperados y sincronizados',
            );
            return recoveredItems;
          }
        } catch (e) {
          print('❌ Error al decodificar backup: $e');
        }
      }

      // Verificar contador en SharedPreferences
      final storedCount = prefs.getInt('nav_bar_badge_count') ?? 0;

      // Si hay un contador pero no hay items, hay discrepancia
      if (storedCount > 0) {
        print(
          '⚠️ CartScreen: Contador en SharedPreferences: $storedCount pero no hay items recuperables',
        );
      }

      return [];
    } catch (e) {
      print('❌ Error al recuperar items desde SharedPreferences: $e');
      return [];
    }
  }

  Future<int> _getCartCountFromBadge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('nav_bar_badge_count') ?? 0;
  }

  /// Método para forzar la carga del carrito desde todas las claves de storage posibles
  Future<void> _forceLoadFromAllStorageKeys() async {
    try {
      print('🔧 CartScreen: _forceLoadFromAllStorageKeys INICIANDO');
      final prefs = await SharedPreferences.getInstance();

      // Obtener userId actual
      final currentUserId = prefs.getString('current_user_id');
      final numericUserId = prefs.getInt('user_id');

      print('🔍 Verificando con userIds: $currentUserId, $numericUserId');

      // Lista de posibles claves de carrito a verificar
      final possibleKeys = [
        'cart_items_${numericUserId ?? 'unknown'}',
        'cart_items_$currentUserId',
        'cart_backup_${numericUserId ?? 'unknown'}',
        'cart_backup_$currentUserId',
        'cart_items_guest',
        'cart_backup_guest',
      ];

      String? foundData;
      String? foundKey;

      // Buscar datos en cualquiera de las claves
      for (final key in possibleKeys) {
        final data = prefs.getString(key);
        if (data != null && data.isNotEmpty && data != '[]') {
          foundData = data;
          foundKey = key;
          print('✅ CartScreen: Datos encontrados en clave: $key');
          break;
        }
      }

      if (foundData != null && foundKey != null) {
        print('🔧 CartScreen: Restaurando desde $foundKey...');

        try {
          final List<dynamic> decodedData = jsonDecode(foundData);
          print('📦 CartScreen: Decodificados ${decodedData.length} items');

          if (decodedData.isNotEmpty) {
            // Forzar actualización del CartService con estos datos
            _cartService.setNotificationsEnabled(false);
            await _cartService.clear();

            // Reconstituir y añadir cada item
            for (final itemData in decodedData) {
              await _cartService.addItem(
                id:
                    itemData['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: itemData['name'] ?? 'Item',
                price: (itemData['price'] ?? 0.0).toDouble(),
                imageUrl: itemData['imageUrl'] ?? '',
                quantity: itemData['quantity'] ?? 1,
                notes: itemData['notes'],
                originalData: itemData['originalData'] ?? {},
              );
            }

            _cartService.setNotificationsEnabled(true);
            await _cartService.saveCart();

            // Actualizar UI inmediatamente
            setState(() {
              _cartItems = List<CartItem>.from(_cartService.items);
            });

            print(
              '✅ CartScreen: ${decodedData.length} items restaurados exitosamente',
            );
          }
        } catch (e) {
          print('❌ Error al decodificar datos del carrito: $e');
        }
      } else {
        print(
          '❌ CartScreen: No se encontraron datos de carrito en ninguna clave',
        );
      }
    } catch (e) {
      print('❌ Error en _forceLoadFromAllStorageKeys: $e');
    }
  }

  /// Verifica si el usuario llegó a esta pantalla desde ChatScreen
  Future<void> _checkIfCameFromChat() async {
    try {
      print('📱 CartScreen: Verificando si se navegó desde ChatScreen');
      final prefs = await SharedPreferences.getInstance();

      // Comprobar si tenemos la marca específica de navegación desde chat
      final cameFromChat =
          prefs.getBool('navigated_from_chat_to_cart') ?? false;
      final chatToCartTimestamp = prefs.getString('chat_to_cart_timestamp');

      if (cameFromChat && chatToCartTimestamp != null) {
        // Calcular cuántos segundos han pasado desde la navegación
        final now = DateTime.now();
        final navigationTime = DateTime.parse(chatToCartTimestamp);
        final secondsSinceNavigation = now.difference(navigationTime).inSeconds;

        // Solo procesar si la navegación fue reciente (últimos 10 segundos)
        if (secondsSinceNavigation <= 10) {
          print(
            '🔀 CartScreen: Detectada navegación reciente desde ChatScreen',
          );

          // Forzar actualización del carrito
          await _refreshCart();

          // Si acabamos de navegar desde chat, mostrar un mensaje de bienvenida
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Carrito actualizado con tus productos'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Limpiar la bandera después de procesarla
          await prefs.setBool('navigated_from_chat_to_cart', false);
        }
      }
    } catch (e) {
      print('❌ Error al verificar navegación desde chat: $e');
    }
  }
}
