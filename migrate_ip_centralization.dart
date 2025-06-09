// Script de migración para centralizar configuración IP
// Ejecutar con: dart migrate_ip_centralization.dart

import 'dart:io';

void main() async {
  print('🚀 Iniciando migración de IP centralizada...');

  // Lista de archivos a migrar
  final filesToMigrate = [
    'lib/Api_services/cart_service.dart',
    'lib/Api_services/gemini_api_client.dart',
    'lib/Api_services/mcp_service.dart',
    'lib/Api_services/global_config_service.dart',
    'lib/Api_services/menu/menu_service.dart',
    'lib/Api_services/menu/get_drinks_service.dart',
    'lib/Api_services/menu/get_dishes_service.dart',
    'lib/Api_services/menu/add_dish_service.dart',
    'lib/Api_services/user_service.dart',
    'lib/Api_services/usuarios/register_service.dart',
    'lib/Api_services/soft_delete_service.dart',
    'lib/Api_services/password_reset_service.dart',
    'lib/Api_services/pedidos/recommendations_service.dart',
    'lib/Api_services/pedidos/popular_dishes_service.dart',
    'lib/Api_services/pedidos/orders_service.dart',
    'lib/Api_services/pedidos/create_order_service.dart',
    'lib/UI_Screens/Auth_Screens/auth_modals.dart',
    'lib/UI_Screens/Shared/shared_profile_screen.dart',
    'lib/UI_Screens/Widgets/logout_button.dart',
    'lib/UI_Screens/Widgets/custom_bottom_navigation_bar.dart',
    'lib/UI_Screens/Shared/shared_order_history_screen.dart',
    'lib/UI_Screens/Shared/shared_home_screen.dart',
    'lib/UI_Screens/Shared/shared_chat_screen.dart',
    'lib/UI_Screens/Admin_Screens/Users/AdminUsersScreen.dart',
    'lib/UI_Screens/Admin_Screens/AdminHomeScreen.dart',
  ];

  // Patrones de reemplazo
  final replacements = {
    // URLs completas hardcodeadas
    r"'http://192\.168\.1\.121:3000'": r"NetworkConfigService().baseUrl",
    r'"http://192\.168\.1\.121:3000"': r'NetworkConfigService().baseUrl',
    r'http://192\.168\.1\.121:3000': r'${NetworkConfigService().baseUrl}',

    // IPs solas
    r"'192\.168\.1\.121'": r"NetworkConfigService().serverIp",
    r'"192\.168\.1\.121"': r'NetworkConfigService().serverIp',

    // Construcciones Uri.parse específicas
    r"Uri\.parse\('http://192\.168\.1\.121:3000([^']*)'?\)":
        r'Uri.parse("${NetworkConfigService().baseUrl}$1")',
    r'Uri\.parse\("http://192\.168\.1\.121:3000([^"]*)"?\)':
        r'Uri.parse("${NetworkConfigService().baseUrl}$1")',

    // Strings interpolados
    r'\$\{[^}]*192\.168\.1\.121[^}]*\}': r'${NetworkConfigService().baseUrl}',
  };

  int totalChanges = 0;

  for (final filePath in filesToMigrate) {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ Archivo no encontrado: $filePath');
        continue;
      }

      String content = await file.readAsString();
      String originalContent = content;
      int fileChanges = 0;

      // Aplicar reemplazos
      for (final pattern in replacements.keys) {
        final regex = RegExp(pattern);
        final replacement = replacements[pattern]!;

        final matches = regex.allMatches(content);
        if (matches.isNotEmpty) {
          content = content.replaceAll(regex, replacement);
          fileChanges += matches.length;
          print('  ✅ Reemplazados ${matches.length} patrones en $filePath');
        }
      }

      // Agregar import si se hicieron cambios
      if (fileChanges > 0 &&
          !content.contains("import 'network_config_service.dart'")) {
        // Buscar la línea de imports para agregar el nuevo import
        final lines = content.split('\n');
        int importIndex = -1;

        for (int i = 0; i < lines.length; i++) {
          if (lines[i].startsWith("import 'package:") ||
              lines[i].startsWith('import "package:') ||
              lines[i].startsWith("import '../") ||
              lines[i].startsWith('import "../')) {
            importIndex = i;
          }
        }

        if (importIndex != -1) {
          // Determinar el path relativo correcto
          String importPath = 'network_config_service.dart';
          if (filePath.contains('UI_Screens/')) {
            importPath = '../../Api_services/network_config_service.dart';
          } else if (filePath.contains('Api_services/')) {
            importPath = 'network_config_service.dart';
          }

          lines.insert(importIndex + 1, "import '$importPath';");
          content = lines.join('\n');
          fileChanges++;
          print('  📦 Agregado import en $filePath');
        }
      }

      // Escribir archivo si hubo cambios
      if (content != originalContent) {
        await file.writeAsString(content);
        totalChanges += fileChanges;
        print('📝 Actualizado $filePath ($fileChanges cambios)');
      }
    } catch (e) {
      print('❌ Error procesando $filePath: $e');
    }
  }

  print('\n🎉 Migración completada!');
  print('📊 Total de cambios realizados: $totalChanges');
  print('\n📋 Próximos pasos:');
  print('1. Verificar que no haya errores de compilación');
  print('2. Probar la aplicación con diferentes IPs');
  print('3. Actualizar servidor.js con la nueva IP');
  print('4. Eliminar este script cuando todo funcione correctamente');
}
