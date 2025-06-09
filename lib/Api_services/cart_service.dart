import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import 'dart:async';
import '../services/cart_event_bus.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'network_config_service.dart';
import 'network_config_service.dart';

class CartService extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isInitialized = false;
  String? _userId;
  // Almacena en memoria los carritos por usuario para evitar problemas de sincronización
  final Map<String, List<CartItem>> _userCarts = {};
  // Timestamp de última actualización desde storage
  DateTime _lastStorageSync = DateTime.now();
  // Flag para habilitar o deshabilitar notificaciones
  bool _notificationsEnabled = true;
  // EventBus para comunicación entre pantallas
  final CartEventBus _eventBus = CartEventBus();

  // Variables para gestionar observadores especializados
  final List<Function()> _priorityListeners = [];

  // Servicio de configuración de red
  final NetworkConfigService _networkConfig = NetworkConfigService();

  // Instancia singleton
  static final CartService _instance = CartService._internal();

  // Factory para obtener la instancia
  factory CartService() => _instance;

  // Timer principal para sincronización periódica
  Timer? _periodicSyncTimer;

  // Constructor privado
  CartService._internal() {
    _initCart();
    // Configuramos un timer para sincronizar en segundo plano con menor frecuencia
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_notificationsEnabled && !_isSyncing) {
        _synchronizeQuietly();
      }
    });
  }

  // Método para limpiar recursos
  void dispose() {
    _syncTimer?.cancel();
    _periodicSyncTimer?.cancel();
    print('🧹 CartService: Recursos liberados');
  }

  // Inicializar el carrito
  Future<void> _initCart() async {
    if (_isInitialized) return;

    try {
      // Intentar obtener el ID de usuario desde SharedPreferences o generar uno
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('current_user_id');
      if (_userId == null) {
        _userId =
            const Uuid().v4(); // Generar un ID de usuario único si no existe
        await prefs.setString('current_user_id', _userId!);
      }
      print('🛒 CartService: Carrito inicializado para usuario ID: $_userId');

      await _loadCartFromStorage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('❌ Error al inicializar el carrito: $e');
    }
  }

  // Método para buscar datos del menú por nombre
  Future<Map<String, dynamic>?> _findMenuItemByName(String itemName) async {
    try {
      print('🔍 CartService: Buscando en menú: "$itemName"');

      final networkConfig = NetworkConfigService();
      final response = await http.get(
        Uri.parse('${networkConfig.baseUrl}/menu'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> menuItems = json.decode(response.body);
        print('📋 CartService: ${menuItems.length} items en el menú');

        // Buscar por nombre exacto (insensible a mayúsculas)
        for (var item in menuItems) {
          final String menuItemName = item['nombre']?.toString() ?? '';
          if (menuItemName.toLowerCase().trim() ==
              itemName.toLowerCase().trim()) {
            print('✅ CartService: Item encontrado en menú: $item');

            // Convertir precio de string a double correctamente
            double price = 0.0;
            try {
              final priceValue = item['precio'];
              if (priceValue != null) {
                price = double.parse(priceValue.toString());
              }
            } catch (e) {
              print('⚠️ CartService: Error al convertir precio: $e');
              price = 0.0;
            }

            return {
              'id': item['idplato']?.toString() ?? '',
              'name': item['nombre']?.toString() ?? itemName,
              'price': price,
              'image_url': item['imagen_url']?.toString() ?? '',
              'categoria': item['categoria']?.toString() ?? '',
              'disponibilidad': item['disponibilidad'] ?? true,
            };
          }
        }

        // Si no se encuentra exacto, buscar por similitud
        for (var item in menuItems) {
          final String menuItemName = item['nombre']?.toString() ?? '';
          if (menuItemName.toLowerCase().contains(itemName.toLowerCase()) ||
              itemName.toLowerCase().contains(menuItemName.toLowerCase())) {
            print('⚠️ CartService: Item similar encontrado: $item');

            // Convertir precio de string a double correctamente
            double price = 0.0;
            try {
              final priceValue = item['precio'];
              if (priceValue != null) {
                price = double.parse(priceValue.toString());
              }
            } catch (e) {
              print('⚠️ CartService: Error al convertir precio: $e');
              price = 0.0;
            }

            return {
              'id': item['idplato']?.toString() ?? '',
              'name': item['nombre']?.toString() ?? itemName,
              'price': price,
              'image_url': item['imagen_url']?.toString() ?? '',
              'categoria': item['categoria']?.toString() ?? '',
              'disponibilidad': item['disponibilidad'] ?? true,
            };
          }
        }

        print('❌ CartService: Item "$itemName" no encontrado en el menú');
        return null;
      } else {
        print('❌ CartService: Error al consultar menú: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ CartService: Error al buscar en menú: $e');
      return null;
    }
  }

  // Método para añadir múltiples ítems al carrito desde Brunchy
  Future<void> addItemsFromBrunchy(List<Map<String, dynamic>> itemsData) async {
    print('🛒 CartService: Agregando ${itemsData.length} items desde audio');

    // Deshabilitar notificaciones durante el proceso para evitar conflictos
    final originalNotificationsState = _notificationsEnabled;
    _notificationsEnabled = false;

    bool cartChanged = false;

    for (var itemData in itemsData) {
      final String? name = itemData['name'] as String?;
      final int? quantity = itemData['quantity'] as int?;
      final String? notes = itemData['notes'] as String?;

      if (name != null && quantity != null && quantity > 0) {
        // Verificar si el item ya viene procesado desde GeminiService
        final bool isPreProcessed =
            itemData.containsKey('id') &&
            itemData.containsKey('price') &&
            itemData.containsKey('matchScore');

        Map<String, dynamic>? menuData;

        if (isPreProcessed) {
          // Usar datos ya procesados por GeminiService
          final bool notFound = itemData['notFound'] == true;
          final double matchScore = itemData['matchScore'] as double? ?? 0.0;

          if (notFound || matchScore < 0.3) {
            print(
              '❌ CartService: "${name}" no encontrado o score muy bajo (${matchScore.toStringAsFixed(2)}) - omitiendo',
            );
            continue;
          }

          menuData = {
            'id': itemData['id'] as String,
            'name': itemData['name'] as String,
            'price': itemData['price'] as double,
            'image_url': itemData['image_url'] as String? ?? '',
            'categoria': itemData['categoria'] as String? ?? '',
            'disponibilidad': itemData['disponibilidad'] as bool? ?? true,
          };

          print(
            '✅ CartService: Usando datos procesados para "${name}" (score: ${matchScore.toStringAsFixed(2)})',
          );
        } else {
          // Fallback: buscar datos en la base de datos como antes
          print(
            '🔍 CartService: Buscando "${name}" en base de datos (fallback)',
          );
          menuData = await _findMenuItemByName(name);
        }

        if (menuData != null) {
          final String realId = menuData['id'] as String;
          final String realName = menuData['name'] as String;
          final double realPrice = menuData['price'] as double;
          final String realImageUrl = menuData['image_url'] as String;

          // Buscar si el item ya existe en el carrito (por ID real Y notas exactas)
          final existingItemIndex = _items.indexWhere(
            (item) =>
                item.id == realId &&
                (item.notes?.trim() ?? '') == (notes?.trim() ?? ''),
          );

          if (existingItemIndex != -1) {
            // Si el item existe con las mismas notas, actualizamos solo la cantidad
            CartItem existingItem = _items[existingItemIndex];
            _items[existingItemIndex] = existingItem.copyWith(
              quantity: existingItem.quantity + quantity,
            );
            print(
              '➕ CartService: Cantidad actualizada para ${realName} (${existingItem.quantity} + ${quantity} = ${existingItem.quantity + quantity})',
            );
          } else {
            // Si el item no existe, lo añadimos como nuevo con datos reales
            final newCartItem = CartItem(
              id: realId,
              name: realName,
              quantity: quantity,
              price: realPrice,
              imageUrl: realImageUrl,
              notes: notes,
              originalData: {...itemData, ...menuData},
            );
            _items.add(newCartItem);
            print(
              '✅ CartService: ${realName} agregado al carrito (\$${realPrice.toStringAsFixed(2)} x${quantity})',
            );
          }
          cartChanged = true;
        } else {
          print('❌ CartService: "$name" no encontrado en el menú - omitiendo');
        }
      }
    }

    // Restaurar notificaciones antes de notificar
    _notificationsEnabled = originalNotificationsState;

    if (cartChanged) {
      await _saveCartAndUpdateCounters();
      await saveCart();
      await saveCountToSharedPrefs();

      if (_notificationsEnabled) {
        notifyListeners();
        _eventBus.fireCartUpdate(CartEvent(CartEventType.itemAdded));

        // Notificación adicional para asegurar propagación
        Future.delayed(Duration(milliseconds: 500), () {
          if (_notificationsEnabled) {
            notifyListeners();
            _eventBus.fireCartUpdate(CartEvent(CartEventType.forceRefresh));
          }
        });
      }

      print(
        '✅ CartService: ${_items.length} items en carrito - proceso completo',
      );
    } else {
      print('ℹ️ CartService: No se agregaron items al carrito');
    }
  }

  // Método para establecer el ID de usuario (restaurado para compatibilidad)
  Future<void> setUserId(String userId) async {
    print(
      '🔄 CartService: setUserId llamado - Actual: $_userId -> Nuevo: $userId',
    );
    print(
      '📊 CartService: Items actuales antes de setUserId: ${_items.length}',
    );

    // CRÍTICO: Prevenir cambios innecesarios que borren el carrito
    if (_userId == userId) {
      print(
        '⚠️ CartService: Usuario ya establecido ($_userId), evitando cambio innecesario',
      );
      return;
    }

    // CRÍTICO: Si ya hay items en el carrito y el cambio es de guest/UUID a un ID de usuario
    // específico, TRANSFERIR el carrito en lugar de borrarlo
    if (_items.isNotEmpty && _userId != null) {
      print(
        '⚠️ CartService: CARRITO NO VACÍO detectado (${_items.length} items)',
      );
      print('   Usuario actual: $_userId');
      print('   Usuario nuevo: $userId');

      // Si estamos cambiando de guest/UUID a ID numérico, es probablemente el login
      final isLoginTransition =
          (_userId == "guest" || _userId!.contains('-')) &&
          userId.isNotEmpty &&
          userId != "guest";

      if (isLoginTransition) {
        print(
          '🔄 CartService: Detectada transición de login - TRANSFIRIENDO carrito',
        );

        // Guardar el carrito actual bajo el nuevo ID sin borrarlo
        _userCarts[userId] = List.from(_items);

        // Cambiar el userId sin borrar _items
        final oldUserId = _userId;
        _userId = userId;

        // Guardar inmediatamente en storage
        await saveCart();

        print(
          '✅ CartService: Carrito transferido de $oldUserId a $userId (${_items.length} items)',
        );

        // Actualizar SharedPreferences con el nuevo ID
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', userId);

        // Notificar cambio sin borrar items
        if (_notificationsEnabled) {
          notifyListeners();
          _eventBus.fireCartUpdate(
            CartEvent(CartEventType.cartLoaded, data: _items.length),
          );
        }
        return;
      }
    }

    // Si llegamos aquí, es un cambio "real" de usuario
    if (_userId != userId) {
      print('🔄 CartService: Cambio real de usuario: $_userId -> $userId');

      // Verificar si el usuario anterior cerró sesión
      final prefs = await SharedPreferences.getInstance();
      final userLoggedOut = prefs.getBool('user_logged_out') ?? false;

      // Si hay flag de cierre de sesión, limpiar completamente
      if (userLoggedOut) {
        print('🔄 Detectado cierre de sesión - limpiando todos los carritos');
        await clearAllCarts();
        await prefs.remove('user_logged_out'); // Eliminar la flag
      } else {
        // Si hay un usuario anterior, guardar su carrito
        if (_userId != null) {
          _userCarts[_userId!] = List.from(_items);
          await saveCart(); // Guardar el carrito del usuario anterior
          print('💾 Carrito del usuario $_userId guardado antes de cambiar');
        }
      }

      // Limpiar el carrito actual ANTES de cambiar de usuario
      _items = [];

      // Cambiar al nuevo usuario
      _userId = userId;

      // Actualizar SharedPreferences
      await prefs.setString('current_user_id', userId);

      // Cargar el carrito del nuevo usuario
      await _loadCartFromStorage();

      print(
        '✅ CartService: Cambio de usuario completado - Items cargados: ${_items.length}',
      );

      // Notificar a los listeners del cambio (con control de notificaciones)
      if (_notificationsEnabled) {
        print('📊 CartService: Notificando cambio de usuario');
        notifyListeners();
        // Notificar a través del EventBus
        _eventBus.fireCartUpdate(
          CartEvent(CartEventType.cartLoaded, data: _items.length),
        );
      }
    }
  }

  // Habilitar o deshabilitar notificaciones (útil para operaciones por lotes)
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  // Obtener la clave de storage basada en el userId
  String get _storageKey {
    return _userId != null ? 'cart_${_userId!}' : 'cart_guest_fallback';
  }

  // Obtener todos los items del carrito
  List<CartItem> get items => List.unmodifiable(_items);

  // Obtener cantidad total de items
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // Obtener precio total del carrito
  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Verificar si un item ya está en el carrito
  bool isInCart(String itemId) {
    return _items.any((item) => item.id == itemId);
  }

  // Buscar un item por su ID
  CartItem? findById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  // Agregar un item al carrito
  Future<void> addItem({
    required String id,
    required String name,
    required double price,
    required String imageUrl,
    required Map<String, dynamic> originalData,
    String? notes,
    int quantity = 1,
  }) async {
    try {
      print(
        '🛒 CartService: Añadiendo item $name (id: $id, cantidad: $quantity)',
      );

      // Validar parámetros para evitar errores
      if (id.isEmpty || name.isEmpty || price <= 0) {
        print(
          '⚠️ CartService: Datos inválidos para añadir item - id: $id, nombre: $name, precio: $price',
        );
        return;
      }

      // Desactivar notificaciones temporalmente durante la operación
      final previousNotificationsState = _notificationsEnabled;
      _notificationsEnabled = false;

      // Verificar si el ítem ya existe
      final existingItemIndex = _items.indexWhere((item) => item.id == id);

      if (existingItemIndex >= 0) {
        // Si el producto ya existe, actualizar cantidad
        print(
          '🛒 CartService: Item ya existe, actualizando cantidad de ${_items[existingItemIndex].quantity} a ${_items[existingItemIndex].quantity + quantity}',
        );

        _items[existingItemIndex] = _items[existingItemIndex].copyWith(
          quantity: _items[existingItemIndex].quantity + quantity,
          notes: notes ?? _items[existingItemIndex].notes,
        );
      } else {
        // Si es un producto nuevo, agregarlo
        print('🛒 CartService: Nuevo item, agregando al carrito');

        _items.add(
          CartItem(
            id: id,
            name: name,
            price: price,
            imageUrl: imageUrl,
            quantity: quantity,
            notes: notes,
            originalData: originalData,
          ),
        );
      }

      // Actualizar la memoria caché
      if (_userId != null) {
        _userCarts[_userId!] = List.from(_items);
        print(
          '🛒 CartService: Memoria caché actualizada para usuario $_userId',
        );
      }

      // Restaurar estado de notificaciones
      _notificationsEnabled = previousNotificationsState;

      // Guardar en localStorage y actualizar contadores
      await _saveCartAndUpdateCounters();
      print('🛒 CartService: Datos guardados correctamente en almacenamiento');

      // Solo notificar si las notificaciones están habilitadas
      if (_notificationsEnabled) {
        print('🛒 CartService: Notificando adición de item: $name');

        // Notificar a través del EventBus primero (más rápido)
        _eventBus.fireCartUpdate(
          CartEvent(
            CartEventType.itemAdded,
            data: {
              'id': id,
              'name': name,
              'quantity': quantity,
              'totalItems': itemCount,
            },
          ),
        );

        // Luego notificar a los listeners normales
        notifyListeners();

        // Enviar otra notificación después de un breve retraso para asegurar que todos los componentes la reciban
        Future.delayed(Duration(milliseconds: 300), () {
          if (_notificationsEnabled) {
            _eventBus.fireCartUpdate(
              CartEvent(
                CartEventType.forceRefresh,
                data: {'id': id, 'name': name, 'totalItems': itemCount},
              ),
            );
          }
        });
      }

      // Guardar contador en SharedPreferences inmediatamente después de añadir
      await saveCountToSharedPrefs();
    } catch (e) {
      print('❌ CartService: Error al añadir item: $e');
      print('❌ CartService: StackTrace: ${StackTrace.current}');

      // Intentar recuperar y seguir adelante incluso después de un error
      try {
        // Forzar notificación para mantener coherencia
        _notificationsEnabled = true;
        notifyListeners();
        _eventBus.fireCartUpdate(
          CartEvent(
            CartEventType.forceRefresh,
            data: {'error': 'recovery', 'totalItems': itemCount},
          ),
        );
      } catch (_) {
        // Ignorar errores en la recuperación
      }
    }
  }

  // Actualizar la cantidad de un item
  Future<void> updateQuantity(String id, int quantity) async {
    if (quantity <= 0) {
      await removeItem(id);
      return;
    }

    final itemIndex = _items.indexWhere((item) => item.id == id);
    if (itemIndex >= 0) {
      _items[itemIndex] = _items[itemIndex].copyWith(quantity: quantity);

      // Actualizar la memoria caché
      if (_userId != null) {
        _userCarts[_userId!] = List.from(_items);
      }

      // Guardar en localStorage y actualizar contadores
      await _saveCartAndUpdateCounters();

      // Solo notificar si las notificaciones están habilitadas
      if (_notificationsEnabled) {
        print(
          '🛒 CartService: Notificando actualización de cantidad para item: $id',
        );

        // Notificar a través del EventBus primero (más rápido)
        _eventBus.fireCartUpdate(
          CartEvent(
            CartEventType.itemUpdated,
            data: {'id': id, 'quantity': quantity},
          ),
        );

        // Luego notificar a los listeners normales
        notifyListeners();
      }

      // Guardar contador en SharedPreferences inmediatamente después de actualizar
      await saveCountToSharedPrefs();
    }
  }

  // Actualizar las notas de un item
  Future<void> updateNotes(String id, String? notes) async {
    final itemIndex = _items.indexWhere((item) => item.id == id);
    if (itemIndex >= 0) {
      _items[itemIndex] = _items[itemIndex].copyWith(notes: notes);

      // Actualizar la memoria caché
      if (_userId != null) {
        _userCarts[_userId!] = List.from(_items);
      }

      // Guardar explícitamente en el almacenamiento
      await saveCart();

      // Solo notificar si las notificaciones están habilitadas
      if (_notificationsEnabled) {
        notifyListeners();
      }
    }
  }

  // Remover item del carrito
  Future<void> removeItem(String id) async {
    final itemToRemove = findById(id);
    _items.removeWhere((item) => item.id == id);

    // Actualizar la memoria caché
    if (_userId != null) {
      _userCarts[_userId!] = List.from(_items);
    }

    // Guardar en localStorage y actualizar contadores
    await _saveCartAndUpdateCounters();

    // Solo notificar si las notificaciones están habilitadas
    if (_notificationsEnabled) {
      print('🛒 CartService: Notificando eliminación de item: $id');

      // Notificar a través del EventBus primero (más rápido)
      _eventBus.fireCartUpdate(
        CartEvent(
          CartEventType.itemRemoved,
          data: {'id': id, 'name': itemToRemove?.name},
        ),
      );

      // Luego notificar a los listeners normales
      notifyListeners();
    }

    // Guardar contador en SharedPreferences inmediatamente después de eliminar
    await saveCountToSharedPrefs();
  }

  // Limpiar todo el carrito
  Future<void> clear() async {
    _items.clear();

    // Actualizar la memoria caché
    if (_userId != null) {
      _userCarts[_userId!] = [];
    }

    // Guardar en localStorage y actualizar contadores
    await _saveCartAndUpdateCounters();

    // Solo notificar si las notificaciones están habilitadas
    if (_notificationsEnabled) {
      print('🛒 CartService: Notificando limpieza completa del carrito');

      // Notificar a través del EventBus primero (más rápido)
      _eventBus.fireCartUpdate(CartEvent(CartEventType.cartCleared));

      // Luego notificar a los listeners normales
      notifyListeners();
    }

    // Guardar contador en SharedPreferences inmediatamente después de limpiar
    await saveCountToSharedPrefs();
  }

  // Guardar el carrito en localStorage
  Future<void> saveCart() async {
    // Utilizar el método centralizado para mantener consistencia
    await _saveCartAndUpdateCounters();
  }

  // Método para verificar si es necesario recargar desde almacenamiento
  // basado en el tiempo transcurrido desde la última sincronización
  bool shouldReloadFromStorage() {
    final now = DateTime.now();
    final timeSinceLastSync = now.difference(_lastStorageSync).inSeconds;
    // Recargar si han pasado más de 1 segundo desde la última sincronización
    return timeSinceLastSync > 1;
  }

  // Cargar el carrito usando un enfoque de polling
  // Este método verifica si es necesario recargar basado en el tiempo transcurrido
  Future<List<CartItem>> getCartItemsWithSync() async {
    // Siempre recargar desde almacenamiento para asegurar consistencia
    await _loadCartFromStorage();
    return _items;
  }

  // Método más directo para cargar datos desde SharedPreferences sin usar caché
  Future<void> _loadCartFromStorage() async {
    if (_userId == null) {
      print('⚠️ CartService: No se pudo cargar el carrito, userId es nulo.');
      _items = []; // Asegurar que _items esté vacío si no hay userId
      _userCarts[_userId ?? 'guest_fallback'] = [];
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final String? cartJson = prefs.getString('cart_${_userId!}');
    if (cartJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cartJson);
        _items =
            jsonList
                .map((json) => CartItem.fromJson(json as Map<String, dynamic>))
                .toList();
        _userCarts[_userId!] = List.from(_items); // Cargar al mapa en memoria
        print(
          '🛒 CartService: Carrito cargado desde storage para $_userId. ${itemCount} ítems.',
        );
      } catch (e) {
        print(
          '❌ Error decodificando JSON del carrito para $_userId: $e. Se creará un carrito vacío.',
        );
        _items = [];
        _userCarts[_userId!] = [];
      }
    } else {
      _items = [];
      _userCarts[_userId!] = [];
      print('🛒 CartService: No se encontró carrito en storage para $_userId.');
    }
  }

  // Verificar si los datos del item son válidos
  bool _isValidCartItemData(Map<String, dynamic> item) {
    return item['id'] != null && item['name'] != null && item['price'] != null;
  }

  // Guardar en todas las posibles claves para máxima redundancia
  Future<void> _saveToAllStorageKeys(List<CartItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convertir items a formato JSON
      final jsonData = jsonEncode(
        items
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
      );

      // Lista de claves donde guardar
      final storageKeys = [
        _userId != null ? 'cart_items_$_userId' : 'cart_items_guest',
        'cart',
        'cart_items_backup',
      ];

      // Guardar en todas las claves
      for (final key in storageKeys) {
        await prefs.setString(key, jsonData);
      }

      // Actualizar contadores
      final count = items.length;
      await prefs.setInt('cart_item_count', count);
      await prefs.setInt('current_cart_count', count);
      await prefs.setInt('last_nav_cart_count', count);
      await prefs.setInt('nav_bar_badge_count', count);

      print(
        '💾 CartService: Datos guardados en ${storageKeys.length} claves de almacenamiento',
      );
    } catch (e) {
      print('❌ Error al guardar en múltiples claves: $e');
    }
  }

  // Método para intentar recuperar el carrito después de un error
  Future<void> _attemptCartRecovery() async {
    try {
      print('🔄 CartService: Intentando recuperar carrito después de error');

      // Obtener prefs sin importar el error anterior
      final prefs = await SharedPreferences.getInstance();

      // Verificar si hay un backup disponible
      final backupKey = 'cart_backup_${_userId ?? "default"}';
      final backupData = prefs.getString(backupKey);

      if (backupData != null && backupData.isNotEmpty) {
        print('✅ CartService: Backup encontrado, intentando restaurar');
        try {
          final List<dynamic> decodedData = jsonDecode(backupData);

          // Reemplazar items con backup
          _items =
              decodedData
                  .map(
                    (item) => CartItem(
                      id: item['id'],
                      name: item['name'],
                      price: item['price'].toDouble(),
                      imageUrl: item['imageUrl'],
                      quantity: item['quantity'],
                      notes: item['notes'],
                      originalData: item['originalData'],
                    ),
                  )
                  .toList();

          // Actualizar caché
          if (_userId != null) {
            _userCarts[_userId!] = List.from(_items);
          }

          print(
            '✅ CartService: Carrito recuperado desde backup: ${_items.length} items',
          );

          // Guardar carrito recuperado
          await saveCart();

          // Notificar recuperación
          notifyListeners();
          _eventBus.fireCartUpdate(
            CartEvent(CartEventType.cartLoaded, data: _items.length),
          );
        } catch (e) {
          print('❌ Error al recuperar desde backup: $e');
          // Si falla la recuperación, inicializar carrito vacío
          _items = [];
        }
      } else {
        print('⚠️ No se encontró backup, inicializando carrito vacío');
        _items = [];
      }
    } catch (e) {
      print('❌ Error en recuperación de emergencia: $e');
      // Último recurso
      _items = [];
    }
  }

  // Método de carga para compatibilidad con código existente
  // ahora usa carga robusta con fallback
  Future<void> loadCart() async {
    final wasFound = await _loadCartFromStorageRobust();
    if (!wasFound) {
      await _loadCartFromStorage();
    }
  }

  // Debounce para sincronización en segundo plano
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Synchronize silently without notifications (for background sync)
  Future<void> _synchronizeQuietly() async {
    // Cancelar sincronización previa si existe
    _syncTimer?.cancel();

    // Evitar múltiples sincronizaciones simultáneas
    if (_isSyncing) {
      if (kDebugMode) {
        print('🔄 CartService: Sincronización ya en progreso, saltando...');
      }
      return;
    }

    // Debounce: Esperar 1 segundo antes de sincronizar
    _syncTimer = Timer(Duration(seconds: 1), () async {
      await _performQuietSync();
    });
  }

  // Método interno para realizar sincronización
  Future<void> _performQuietSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      if (kDebugMode) {
        print('🔄 CartService: Sincronizando carrito en segundo plano...');
      }

      // Intentar carga robusta primero, luego fallback a método básico
      final wasFound = await _loadCartFromStorageRobust();
      if (!wasFound) {
        // Si la carga robusta no encuentra datos, usar método básico
        await _loadCartFromStorage();
      }

      _lastStorageSync = DateTime.now();
      if (kDebugMode) {
        print('✅ CartService: Sincronización en segundo plano completada.');
      }
    } catch (e) {
      print('❌ Error en sincronización silenciosa del carrito: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Limpiar todos los carritos (método restaurado para compatibilidad)
  Future<void> clearAllCarts() async {
    print(
      '🧹 CartService: Iniciando limpieza completa de todos los carritos...',
    );
    _items = [];
    _userCarts.clear(); // Limpiar el caché en memoria

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      int contadorEliminados = 0;

      final cartKeyPattern = RegExp(
        r'^cart_.*',
      ); // Patrón para claves de carrito (ej: cart_userId, cart_guest_fallback)

      for (final key in allKeys) {
        if (cartKeyPattern.hasMatch(key) || key == 'current_user_id') {
          // Incluir current_user_id
          try {
            await prefs.remove(key);
            contadorEliminados++;
            print('🗑️ Clave eliminada: $key');
          } catch (e) {
            print('❌ Error al eliminar clave $key: $e');
          }
        }
      }
      // Limpiar también contadores
      await prefs.remove('cart_item_count');
      await prefs.remove('current_cart_count');
      await prefs.remove('last_nav_cart_count');
      await prefs.remove('nav_bar_badge_count');
      await prefs.remove('cart_count_timestamp');

      _userId = null; // Resetear el userId actual
      _isInitialized = false; // Marcar para reinicializar si es necesario
      await _initCart(); // Reinicializar para generar nuevo guest ID si es necesario

      _lastStorageSync = DateTime.now();
      print(
        '🧹 CartService: $contadorEliminados claves de carrito eliminadas. El servicio se reinicializará.',
      );

      if (_notificationsEnabled) {
        notifyListeners();
        _eventBus.fireCartUpdate(CartEvent(CartEventType.cartCleared));
      }
    } catch (e) {
      print('❌ Error crítico al limpiar todos los carritos: $e');
    }
  }

  // Restablecer el servicio completo
  Future<void> resetService() async {
    print('🔄 CartService: Iniciando reinicio completo del servicio');
    // Limpiar memoria caché
    _items = [];
    _userCarts.clear();

    try {
      // Obtener ID del usuario actual o establecer como invitado
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId != null) {
        _userId = userId.toString();
        print('🔄 CartService: Reiniciando para usuario ID: $_userId');
      } else {
        _userId = 'guest';
      }

      // Cargar desde almacenamiento usando método robusto
      final wasFound = await _loadCartFromStorageRobust();
      if (!wasFound) {
        // Si no se encuentran datos, usar método básico como fallback
        await _loadCartFromStorage();
      }

      // Actualizar timestamp de sincronización
      _lastStorageSync = DateTime.now();

      print('✅ CartService completamente reiniciado con ID: $_userId');

      // No necesitamos llamar a notifyListeners aquí porque _loadCartFromStorage
      // ya lo hace si es necesario
    } catch (e) {
      print('❌ Error al reiniciar CartService: $e');
    }
  }

  // Método para debug - agregar un Americano de prueba (restaurado para compatibilidad)
  Future<bool> loadAmericanoToCart() async {
    try {
      print('☕ CartService: Añadiendo Americano al carrito de prueba');

      // Datos específicos del Americano
      final americanoData = {
        'idplato': '53',
        'nombre': 'Americano',
        'precio': 1.50,
        'categoria': 'Expresos',
        'imagen_url': '${NetworkConfigService().baseUrl}/uploads/1746239040636.jpg',
        'disponibilidad': true,
        'tipo': 'bebida',
      };

      // Ver si ya hay un Americano en el carrito para incrementar cantidad
      final existingIndex = _items.indexWhere(
        (item) => item.id == americanoData['idplato'].toString(),
      );

      if (existingIndex >= 0) {
        // Si ya existe, incrementar la cantidad
        print('☕ Americano ya existe en el carrito, incrementando cantidad');
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + 2,
        );
      } else {
        // Agregar el Americano directamente
        _items.add(
          CartItem(
            id: americanoData['idplato'].toString(),
            name: americanoData['nombre'].toString(),
            price: double.parse(americanoData['precio'].toString()),
            imageUrl: americanoData['imagen_url'].toString(),
            quantity: 2, // Agregar 2 para que sea más visible
            originalData: americanoData,
          ),
        );
      }

      // Actualizar la memoria caché
      if (_userId != null) {
        _userCarts[_userId!] = List.from(_items);
      }

      // Forzar guardado explícito
      await saveCart();

      // Notificar explícitamente a todos los escuchadores
      if (_notificationsEnabled) {
        notifyListeners();
      }

      print(
        '✅ CartService: Americano(s) agregado(s) exitosamente al carrito - Total de items: ${_items.length}',
      );
      return true;
    } catch (e) {
      print('❌ CartService: Error al agregar Americano: $e');
      return false;
    }
  }

  // Agregar un observador con prioridad alta (para la barra de navegación)
  void addPriorityListener(Function() listener) {
    _priorityListeners.add(listener);
    print(
      '⚡ CartService: Agregado listener prioritario (total: ${_priorityListeners.length})',
    );
  }

  // Remover un observador prioritario
  void removePriorityListener(Function() listener) {
    _priorityListeners.remove(listener);
    print(
      '⚡ CartService: Removido listener prioritario (restantes: ${_priorityListeners.length})',
    );
  }

  // Notificar solo a los observadores prioritarios (más rápido)
  void notifyPriorityListeners() {
    print(
      '⚡ CartService: Notificando a ${_priorityListeners.length} listeners prioritarios',
    );
    for (final listener in _priorityListeners) {
      try {
        listener();
      } catch (e) {
        print('❌ Error al notificar listener prioritario: $e');
      }
    }
  }

  // Sobrescribir el método notifyListeners para notificar primero a los prioritarios
  @override
  void notifyListeners() {
    // Primero notificar a los listeners prioritarios
    notifyPriorityListeners();

    // Luego notificar a los listeners normales
    print(
      '🔔 CartService: Notificando a ${hasListeners ? "todos los" : "ningún"} listeners normales (${_items.length} items, total: $itemCount)',
    );
    super.notifyListeners();
  }

  // Forzar notificación para casos donde cambios deben propagarse inmediatamente
  Future<void> forceNotifyListeners() async {
    try {
      // Asegurar que las notificaciones estén habilitadas momentáneamente
      final previousState = _notificationsEnabled;
      _notificationsEnabled = true;

      // 1. Primero notificar a través del bus de eventos
      _eventBus.fireCartUpdate(
        CartEvent(
          CartEventType.forceRefresh,
          data: {
            'forceUpdate': true,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ),
      );

      // 2. Notificar a través del mecanismo estándar de ChangeNotifier
      notifyListeners();

      // 3. Notificar explícitamente a los oyentes prioritarios
      for (final listener in _priorityListeners) {
        try {
          listener();
        } catch (e) {
          print('❌ Error al notificar oyente prioritario: $e');
        }
      }

      // Restaurar estado anterior
      _notificationsEnabled = previousState;

      print(
        '🔔 CartService: Notificación forzada enviada a todos los componentes',
      );
    } catch (e) {
      print('❌ Error al forzar notificaciones: $e');
    }
  }

  // Método para suscribirse a los eventos del carrito
  Stream<CartEvent> get cartEvents => _eventBus.onCartUpdate;

  // Método nuevo para garantizar sincronización completa con todos los componentes
  Future<void> ensureCartSynchronized() async {
    try {
      print('🔄 CartService: Iniciando sincronización completa...');

      // 1. Intentar carga robusta desde múltiples fuentes
      final wasFound = await _loadCartFromStorageRobust();
      if (wasFound) {
        print(
          '🔄 CartService: Carga robusta completada: ${_items.length} items',
        );
      } else {
        // Si no encontramos datos, usar método básico como fallback
        await _loadCartFromStorage();
        print(
          '🔄 CartService: Carga básica completada: ${_items.length} items',
        );
      }

      // 2. Guardar el estado actual del carrito para asegurar coherencia
      await saveCart();
      print('🔄 CartService: Guardado completado');

      // 3. Obtener el contador preciso
      final count = itemCount;
      print('🔄 CartService: Contador calculado: $count');

      // 4. Actualizar timestamps y contadores con múltiples métodos para garantizar coherencia
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      // Marcar todas las posibles claves de sincronización
      final syncKeys = [
        'cart_force_update',
        'force_cart_update',
        'cart_sync_timestamp',
        'bottom_nav_cart_update',
        'badge_update_timestamp',
      ];

      for (final key in syncKeys) {
        await prefs.setString(key, timestamp);
      }

      print('🔄 CartService: Timestamps actualizados: $timestamp');

      // 5. Actualizar todos los posibles contadores
      final counterKeys = [
        'cart_item_count',
        'current_cart_count',
        'last_nav_cart_count',
        'cart_badge_count',
      ];

      for (final key in counterKeys) {
        await prefs.setInt(key, count);
      }

      print('🔄 CartService: Contadores actualizados a $count');

      // 6. Notificar a través del EventBus con información completa
      _eventBus.fireCartUpdate(
        CartEvent(
          CartEventType.forceRefresh,
          data: {
            'items': _items.length,
            'itemCount': count,
            'total': totalAmount,
            'timestamp': timestamp,
            'source': 'ensureCartSynchronized',
          },
        ),
      );

      print('🔄 CartService: Evento de actualización enviado');

      // 7. Notificar con ambos tipos de listeners
      notifyPriorityListeners();
      print('🔄 CartService: Listeners prioritarios notificados');

      notifyListeners();
      print('🔄 CartService: Listeners normales notificados');

      // 8. Programar notificaciones adicionales para asegurar que todos los componentes reciban la actualización
      for (int i = 1; i <= 2; i++) {
        Future.delayed(Duration(milliseconds: i * 500), () {
          _eventBus.fireCartUpdate(
            CartEvent(
              CartEventType.forceRefresh,
              data: {
                'count': count,
                'attempt': i,
                'timestamp': DateTime.now().toIso8601String(),
              },
            ),
          );
        });
      }

      print('🔄 CartService: Sincronización completa finalizada');
    } catch (e) {
      print('❌ Error durante sincronización completa: $e');
      print('❌ StackTrace: ${StackTrace.current}');

      // Intento de recuperación de emergencia
      try {
        notifyListeners();
        _eventBus.fireCartUpdate(CartEvent(CartEventType.forceRefresh));
      } catch (_) {}
    }
  }

  // Método robusto para buscar carrito en múltiples claves de almacenamiento
  Future<bool> _loadCartFromStorageRobust() async {
    try {
      if (_userId == null) return false;

      final prefs = await SharedPreferences.getInstance();

      // Lista de userId candidatos para buscar
      final candidateUserIds = <String>[_userId!];

      // Agregar candidatos adicionales según el contexto
      final currentUserId = prefs.getString('current_user_id');
      final savedUserId = prefs.getInt('user_id')?.toString();

      if (currentUserId != null && !candidateUserIds.contains(currentUserId)) {
        candidateUserIds.add(currentUserId);
      }
      if (savedUserId != null && !candidateUserIds.contains(savedUserId)) {
        candidateUserIds.add(savedUserId);
      }

      print(
        '🔍 CartService: Buscando carrito en claves para userIds: ${candidateUserIds.join(", ")}',
      );

      // Buscar en todas las claves posibles
      for (final userId in candidateUserIds) {
        final possibleKeys = [
          'cart_items_$userId',
          'cart_backup_$userId',
          'cart_$userId',
        ];

        for (final key in possibleKeys) {
          final cartData = prefs.getString(key);
          if (cartData != null && cartData.isNotEmpty && cartData != '[]') {
            try {
              print('✅ CartService: Datos encontrados en clave: $key');

              // Decodificar los datos
              final List<dynamic> cartItems = jsonDecode(cartData);
              final List<CartItem> loadedItems =
                  cartItems.map((item) {
                    return CartItem(
                      id: item['id']?.toString() ?? '',
                      name: item['name']?.toString() ?? '',
                      price: (item['price'] as num?)?.toDouble() ?? 0.0,
                      imageUrl: item['imageUrl']?.toString() ?? '',
                      quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                      notes: item['notes']?.toString(),
                      originalData:
                          item['originalData'] as Map<String, dynamic>? ?? {},
                    );
                  }).toList();

              // Actualizar el carrito en memoria
              _items = loadedItems;

              // Actualizar caché del usuario
              _userCarts[_userId!] = List.from(_items);

              // Guardar en la clave principal para futuras cargas
              await saveCart();

              print(
                '✅ CartService: ${_items.length} items cargados desde clave robusta: $key',
              );
              return true;
            } catch (e) {
              print('❌ Error al parsear datos de $key: $e');
              continue;
            }
          }
        }
      }

      print('🔍 CartService: No se encontraron datos en búsqueda robusta');
      return false;
    } catch (e) {
      print('❌ Error en carga robusta del carrito: $e');
      return false;
    }
  }

  // Método centralizado para guardar el carrito y actualizar todos los contadores relevantes
  Future<void> _saveCartAndUpdateCounters() async {
    try {
      if (_userId == null) return;

      final prefs = await SharedPreferences.getInstance();

      // 1. Guardar los datos completos del carrito
      final storageKey = 'cart_items_$_userId';
      final cartData =
          _items
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
              .toList();

      // Convertir a JSON
      final jsonData = jsonEncode(cartData);

      // Guardar en almacenamiento
      await prefs.setString(storageKey, jsonData);
      await prefs.setString('cart', jsonData); // Para compatibilidad

      // Guardar también una copia de seguridad
      final backupKey = 'cart_backup_$_userId';
      await prefs.setString(backupKey, jsonData);

      print(
        '💾 CartService: Datos del carrito guardados en $storageKey y respaldados en $backupKey',
      );

      // 2. Actualizar contador principal
      final count = itemCount;
      await prefs.setInt('cart_item_count', count);
      await prefs.setInt('current_cart_count', count);
      await prefs.setInt('last_nav_cart_count', count);

      // 3. Guardar marca de tiempo para sincronización entre pantallas
      final timestamp = DateTime.now().toIso8601String();
      await prefs.setString('force_cart_update', timestamp);
      await prefs.setString('cart_force_update', timestamp);
      await prefs.setString('cart_last_save_timestamp', timestamp);

      print(
        '💾 CartService: Carrito guardado y contadores actualizados: $count items (timestamp: $timestamp)',
      );

      // 4. Notificar a través del EventBus para garantizar coherencia entre pantallas
      _eventBus.fireCartUpdate(
        CartEvent(
          CartEventType.forceRefresh,
          data: {'count': count, 'timestamp': timestamp, 'source': 'saveCart'},
        ),
      );
    } catch (e) {
      print('❌ Error al guardar carrito y actualizar contadores: $e');
      print('❌ StackTrace: ${StackTrace.current}');
    }
  }

  // Método para registrar navegación entre pantallas y ayudar a mantener coherencia
  Future<void> registerScreenNavigation(
    int fromScreenIndex,
    int toScreenIndex,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Registrar la navegación con timestamp
      final timestamp = DateTime.now().toIso8601String();
      await prefs.setString('navigation_timestamp', timestamp);
      await prefs.setInt('navigation_from_screen', fromScreenIndex);
      await prefs.setInt('navigation_to_screen', toScreenIndex);

      // Guardar específicamente cuando se navega desde o hacia la pantalla de chat (índice 2)
      if (fromScreenIndex == 2 || toScreenIndex == 2) {
        await prefs.setString('chat_navigation_timestamp', timestamp);

        // Si estamos saliendo del chat, marcar explícitamente
        if (fromScreenIndex == 2) {
          await prefs.setString('chat_exit_timestamp', timestamp);
        }

        // Si estamos entrando al chat, marcar explícitamente
        if (toScreenIndex == 2) {
          await prefs.setString('chat_enter_timestamp', timestamp);
        }
      }

      // Guardar el estado del carrito en este momento
      await prefs.setInt('cart_items_at_navigation', itemCount);

      print(
        '🔄 CartService: Navegación registrada: $fromScreenIndex → $toScreenIndex (timestamp: $timestamp)',
      );

      // Si vamos de Chat (2) a Cart (3), registrarlo específicamente
      if (fromScreenIndex == 2 && toScreenIndex == 3) {
        await prefs.setBool('navigated_from_chat_to_cart', true);
        await prefs.setString(
          'chat_to_cart_timestamp',
          DateTime.now().toIso8601String(),
        );
      } else {
        // Limpiar la marca si navegamos a otras pantallas
        await prefs.setBool('navigated_from_chat_to_cart', false);
      }
    } catch (e) {
      print('❌ Error al registrar navegación: $e');
    }
  }

  // Método simplificado para obtener el contador actual del carrito de forma confiable
  // Sin causar múltiples actualizaciones o parpadeos en la UI
  Future<int> getReliableCartCount() async {
    try {
      // Usamos el contador interno como fuente principal de verdad
      final currentCount = itemCount;

      // Guardamos este valor en SharedPreferences para acceso desde otras partes
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cart_item_count', currentCount);

      // No notificamos aquí para evitar parpadeos, solo actualizamos el valor
      return currentCount;
    } catch (e) {
      print('❌ Error al obtener contador confiable: $e');
      return itemCount; // Retornamos el contador actual como fallback
    }
  }

  // Método para guardar el contador exacto en SharedPreferences y asegurar
  // que esté siempre sincronizado con la barra de navegación
  Future<void> saveCountToSharedPrefs() async {
    try {
      final count = itemCount;
      final prefs = await SharedPreferences.getInstance();

      // Guardar en múltiples claves para asegurar redundancia
      await prefs.setInt('cart_item_count', count);
      await prefs.setInt('current_cart_count', count);
      await prefs.setInt('last_nav_cart_count', count);
      await prefs.setInt('nav_bar_badge_count', count);

      // También guardar el timestamp para verificar frescura
      final timestamp = DateTime.now().toIso8601String();
      await prefs.setString('cart_count_timestamp', timestamp);

      print(
        '💾 CartService: Contador guardado en SharedPrefs: $count (timestamp: $timestamp)',
      );
    } catch (e) {
      print('❌ Error al guardar contador en SharedPrefs: $e');
    }
  }

  // Notifica a través del EventBus que se ha navegado desde Chat a Cart
  void notifyNavToCartFromChat() {
    try {
      print('📣 CartService: Notificando navegación desde Chat a Cart');
      // Usar el bus de eventos para notificar a todos los oyentes
      _eventBus.fireCartUpdate(CartEvent(CartEventType.navToCartFromChat));
    } catch (e) {
      print('❌ Error al notificar navegación desde Chat a Cart: $e');
    }
  }
}
