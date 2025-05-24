import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar las preferencias de platos del usuario
class UserPreferencesService {
  // Clave para almacenar las preferencias en SharedPreferences
  static const String _prefsKey = 'user_dish_preferences';

  // Instancia singleton
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();

  // Factory para obtener la instancia
  factory UserPreferencesService() => _instance;

  // Constructor privado
  UserPreferencesService._internal();

  /// Obtiene las preferencias del usuario
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsStr = prefs.getString(_prefsKey);

      if (prefsStr == null || prefsStr.isEmpty) {
        return {
          'lastOrderedDish': null,
          'dishCounts': {},
          'favoriteDishes': [],
        };
      }

      return jsonDecode(prefsStr) as Map<String, dynamic>;
    } catch (e) {
      print('Error al obtener preferencias del usuario: $e');
      return {'lastOrderedDish': null, 'dishCounts': {}, 'favoriteDishes': []};
    }
  }

  /// Actualiza las preferencias cuando el usuario pide un plato
  Future<void> updateOrderedDish(String dishName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> userPrefs = await getUserPreferences();

      // Actualizar último plato pedido
      userPrefs['lastOrderedDish'] = dishName;

      // Actualizar contador de platos
      Map<String, dynamic> dishCounts = userPrefs['dishCounts'] ?? {};

      // Manejo seguro del conteo - puede ser int o String desde SharedPreferences
      final currentCount = dishCounts[dishName];
      int countValue = 0;

      if (currentCount is int) {
        countValue = currentCount;
      } else if (currentCount is String) {
        countValue = int.tryParse(currentCount) ?? 0;
      } else if (currentCount is double) {
        countValue = currentCount.toInt();
      }

      dishCounts[dishName] = countValue + 1;
      userPrefs['dishCounts'] = dishCounts;

      // Guardar preferencias actualizadas
      await prefs.setString(_prefsKey, jsonEncode(userPrefs));
    } catch (e) {
      print('Error al actualizar preferencias del usuario: $e');
    }
  }

  /// Marca un plato como favorito
  Future<void> toggleFavoriteDish(String dishName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> userPrefs = await getUserPreferences();

      List<String> favoriteDishes = List<String>.from(
        userPrefs['favoriteDishes'] ?? [],
      );

      if (favoriteDishes.contains(dishName)) {
        favoriteDishes.remove(dishName);
      } else {
        favoriteDishes.add(dishName);
      }

      userPrefs['favoriteDishes'] = favoriteDishes;

      // Guardar preferencias actualizadas
      await prefs.setString(_prefsKey, jsonEncode(userPrefs));
    } catch (e) {
      print('Error al actualizar platos favoritos: $e');
    }
  }

  /// Verifica si un plato es favorito
  Future<bool> isFavoriteDish(String dishName) async {
    try {
      Map<String, dynamic> userPrefs = await getUserPreferences();
      List<String> favoriteDishes = List<String>.from(
        userPrefs['favoriteDishes'] ?? [],
      );
      return favoriteDishes.contains(dishName);
    } catch (e) {
      print('Error al verificar plato favorito: $e');
      return false;
    }
  }

  /// Obtiene los platos más pedidos por el usuario
  Future<List<String>> getMostOrderedDishes({int limit = 5}) async {
    try {
      Map<String, dynamic> userPrefs = await getUserPreferences();
      Map<String, dynamic> dishCounts = userPrefs['dishCounts'] ?? {};

      List<MapEntry<String, dynamic>> sortedDishes =
          dishCounts.entries.toList()..sort((a, b) {
            // Manejo seguro para comparar valores que pueden ser int, String o double
            int valueA = 0;
            int valueB = 0;

            if (a.value is int) {
              valueA = a.value;
            } else if (a.value is String) {
              valueA = int.tryParse(a.value) ?? 0;
            } else if (a.value is double) {
              valueA = (a.value as double).toInt();
            }

            if (b.value is int) {
              valueB = b.value;
            } else if (b.value is String) {
              valueB = int.tryParse(b.value) ?? 0;
            } else if (b.value is double) {
              valueB = (b.value as double).toInt();
            }

            return valueB.compareTo(valueA);
          });

      return sortedDishes.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      print('Error al obtener platos más pedidos: $e');
      return [];
    }
  }

  /// Obtiene todos los platos favoritos
  Future<List<String>> getFavoriteDishes() async {
    try {
      Map<String, dynamic> userPrefs = await getUserPreferences();
      return List<String>.from(userPrefs['favoriteDishes'] ?? []);
    } catch (e) {
      print('Error al obtener platos favoritos: $e');
      return [];
    }
  }

  /// Limpia todas las preferencias del usuario
  Future<void> clearAllPreferences() async {
    try {
      print(
        '🧹 UserPreferencesService: Iniciando limpieza de preferencias de usuario',
      );

      final prefs = await SharedPreferences.getInstance();

      // 1. Eliminar la clave principal de preferencias
      if (prefs.containsKey(_prefsKey)) {
        await prefs.remove(_prefsKey);
        print('✅ Eliminada clave principal de preferencias: $_prefsKey');
      }

      // 2. Buscar y eliminar todas las claves relacionadas con preferencias de usuario
      final allKeys = prefs.getKeys();
      int contadorEliminados = 0;

      // Patrones de claves que pueden contener preferencias de usuario
      final userPrefPatterns = [
        'dish_preferences',
        'user_favorites',
        'last_ordered',
        'user_preferences',
        'favorite_',
        'preference_',
      ];

      for (final key in allKeys) {
        bool isUserPrefKey = false;

        // Verificar si la clave coincide con algún patrón de preferencias
        for (final pattern in userPrefPatterns) {
          if (key.contains(pattern)) {
            isUserPrefKey = true;
            break;
          }
        }

        if (isUserPrefKey) {
          try {
            await prefs.remove(key);
            contadorEliminados++;
            print('🗑️ Eliminada clave de preferencias: $key');
          } catch (e) {
            print('❌ Error al eliminar clave $key: $e');
          }
        }
      }

      print(
        '🧹 UserPreferencesService: Se han eliminado $contadorEliminados claves de preferencias',
      );
    } catch (e) {
      print('❌ Error al limpiar preferencias del usuario: $e');
    }
  }
}
