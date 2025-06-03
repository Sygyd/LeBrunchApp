import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';
import '/UI_Screens/Widgets/custom_modal.dart';
import '/services/notification_service.dart';

class UserManualScreen extends StatefulWidget {
  const UserManualScreen({super.key});

  @override
  State<UserManualScreen> createState() => _UserManualScreenState();
}

class _UserManualScreenState extends State<UserManualScreen> {
  String? _localPdfPath;
  bool _isLoading = true;
  String _errorMessage = '';
  List<ManualModule> _modules = [];

  @override
  void initState() {
    super.initState();
    _initializeModules();
    _loadPdfFromAssets();
  }

  @override
  void dispose() {
    // Limpiar archivo temporal si existe
    if (_localPdfPath != null) {
      final file = File(_localPdfPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    super.dispose();
  }

  void _initializeModules() {
    _modules = _getManualModules();
  }

  List<ManualModule> _getManualModules() {
    // PÁGINAS SEGÚN EL ÍNDICE REAL DEL MANUAL
    // Estas corresponden a las páginas físicas del PDF (tal como aparecen en el índice)
    return [
      ManualModule(
        id: 1,
        title: 'Módulo I: Primer Acceso a la Aplicación',
        description:
            'Introducción al sistema, proceso de login, navegación básica',
        startPage: 3, // Página 3 según índice
        endPage: 7, // Estimado hasta antes del módulo II
        color: const Color(0xFF4ECDC4),
        icon: Icons.login,
        content: [
          'Introducción al sistema Le Brunch',
          'Registro e inicio de sesión',
          'Navegación básica por la interfaz',
          'Configuración inicial de usuario',
          'Primeros pasos recomendados',
        ],
      ),
      ManualModule(
        id: 2,
        title: 'Módulo II: Manual para Clientes',
        description:
            'Exploración del menú, realización de pedidos, carrito de compras',
        startPage: 8, // Página 8 según índice
        endPage: 16, // Estimado hasta antes del módulo III
        color: const Color(0xFF45B7D1),
        icon: Icons.restaurant_menu,
        content: [
          'Exploración del menú digital',
          'Filtrado y búsqueda de platos',
          'Gestión del carrito de compras',
          'Proceso de realización de pedidos',
          'Chat Brunchy - Asistente virtual',
          'Historial de pedidos y favoritos',
        ],
      ),
      ManualModule(
        id: 3,
        title: 'Módulo III: Manual para Administradores',
        description:
            'Gestión de usuarios, administración del menú, reportes y análisis',
        startPage: 17, // Página 17 según índice
        endPage: 31, // Estimado hasta antes del módulo IV
        color: const Color(0xFF96CEB4),
        icon: Icons.admin_panel_settings,
        content: [
          'Panel de administración general',
          'Gestión de usuarios y roles',
          'Administración del menú',
          'Gestión de pedidos activos',
          'Reportes y análisis de ventas',
          'Configuración del sistema',
        ],
      ),
      ManualModule(
        id: 4,
        title: 'Módulo IV: Manual para Personal',
        description: 'Gestión de pedidos activos, tiempos de preparación',
        startPage: 32, // Página 32 según índice
        endPage: 35, // Estimado hasta antes del módulo V
        color: const Color(0xFFFCEAE6),
        icon: Icons.group,
        content: [
          'Acceso al sistema como personal',
          'Visualización de pedidos activos',
          'Gestión de tiempos de preparación',
          'Actualización de estados de pedidos',
          'Comunicación interna del equipo',
        ],
      ),
      ManualModule(
        id: 5,
        title: 'Módulo V: Recomendaciones',
        description: 'Mejores prácticas, solución de problemas comunes',
        startPage: 36, // Página 36 según índice
        endPage: 38, // Estimado final del documento
        color: const Color(0xFFFFADAD),
        icon: Icons.tips_and_updates,
        content: [
          'Mejores prácticas de uso',
          'Consejos para optimizar la experiencia',
          'Solución de problemas comunes',
          'Preguntas frecuentes (FAQ)',
          'Contacto y soporte técnico',
        ],
      ),
    ];
  }

  Future<void> _loadPdfFromAssets() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('🔍 Intentando cargar PDF desde assets...');

      const assetPath = 'docs/Manual_de_usuario_sistemaLB.pdf';
      print('🔍 Ruta del asset: $assetPath');

      final ByteData data = await rootBundle.load(assetPath);
      print('✅ PDF cargado desde assets: ${data.lengthInBytes} bytes');

      final Directory tempDir = await getTemporaryDirectory();
      print('🔍 Directorio temporal: ${tempDir.path}');

      final File tempFile = File('${tempDir.path}/manual_usuario.pdf');
      await tempFile.writeAsBytes(data.buffer.asUint8List());

      setState(() {
        _localPdfPath = tempFile.path;
        _isLoading = false;
      });

      print('✅ PDF guardado temporalmente en: ${tempFile.path}');
      _showSnackBar('Manual cargado exitosamente');
    } catch (e) {
      print('❌ Error detallado al cargar PDF: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Error al cargar el manual: $e\\n\\nPor favor, intenta cargar el archivo manualmente.';
      });
    }
  }

  Future<void> _loadPdfFromDevice() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _localPdfPath = result.files.single.path!;
          _isLoading = false;
          _errorMessage = '';
        });

        _showSnackBar('PDF cargado exitosamente desde el dispositivo');
      }
    } catch (e) {
      _showSnackBar('Error al cargar PDF desde dispositivo: $e');
    }
  }

  Future<void> _openPdfViewer({int? targetPage}) async {
    if (_localPdfPath != null && _localPdfPath!.isNotEmpty) {
      try {
        print(
          '📖 [UserManual] Abriendo PDF completo, página objetivo: ${targetPage ?? 1}',
        );

        await Navigator.pushNamed(
          context,
          '/pdf-viewer',
          arguments: {
            'pdfPath': _localPdfPath!,
            'title':
                targetPage != null
                    ? 'Manual de Usuario - Página $targetPage'
                    : 'Manual de Usuario - Completo',
          },
        );
      } catch (e) {
        print('❌ [UserManual] Error al abrir PDF: $e');
        _showSnackBar('Error al abrir el PDF: $e');
      }
    } else {
      _showSnackBar('No hay PDF cargado. Por favor, carga el manual primero.');
    }
  }

  // Nueva función específica para abrir módulos con páginas específicas
  Future<void> _openModulePdf(ManualModule module) async {
    if (_localPdfPath != null && _localPdfPath!.isNotEmpty) {
      try {
        print('📖 [UserManual] Abriendo módulo: ${module.title}');
        print(
          '📖 [UserManual] Página de inicio del módulo: ${module.startPage}',
        );
        print('📖 [UserManual] Página de fin del módulo: ${module.endPage}');
        print('📖 [UserManual] Archivo PDF: $_localPdfPath');

        final arguments = {
          'pdfPath': _localPdfPath!,
          'title': module.title,
          'initialPage': module.startPage, // Pasar la página inicial del módulo
        };

        print('📖 [UserManual] Argumentos enviados: $arguments');

        await Navigator.pushNamed(context, '/pdf-viewer', arguments: arguments);
      } catch (e) {
        print('❌ [UserManual] Error al abrir módulo: $e');
        _showSnackBar('Error al abrir el PDF: $e');
      }
    } else {
      print('⚠️ [UserManual] PDF no cargado, solicitando carga manual');
      _loadPdfFromDevice();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Función para solicitar permisos de almacenamiento
  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // Para Android 11+ (API 30+), el permiso de almacenamiento es diferente
        if (await Permission.manageExternalStorage.isGranted) {
          return true;
        }

        // Solicitar permisos de almacenamiento
        final status = await Permission.storage.request();
        if (status.isGranted) {
          return true;
        }

        // Como alternativa, probar con manageExternalStorage
        final manageStatus = await Permission.manageExternalStorage.request();
        return manageStatus.isGranted;
      }
      return true; // Para otras plataformas, asumir que está permitido
    } catch (e) {
      print('❌ Error al solicitar permisos: $e');
      return false;
    }
  }

  // Función para descargar el manual PDF
  Future<void> _downloadManualPDF() async {
    const int progressNotificationId = 54321;

    try {
      // Verificar permisos
      bool hasPermission = await _requestStoragePermission();

      if (!hasPermission) {
        if (!mounted) return;
        await CustomModal.showError(
          context: context,
          title: 'Permiso denegado',
          message:
              'No se puede descargar el manual sin los permisos necesarios.',
        );
        return;
      }

      // Mostrar notificación de progreso inicial
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Descargando Manual de Usuario',
        message: 'Preparando descarga...',
        progress: 0,
        maxProgress: 100,
      );

      // Mostrar modal de progreso
      if (!mounted) return;
      bool showingProgress = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF4ECDC4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Descargando Manual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Por favor espera mientras descargamos el manual...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Actualizar progreso: cargando archivo
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Descargando Manual de Usuario',
        message: 'Cargando archivo...',
        progress: 20,
        maxProgress: 100,
      );

      // Cargar el PDF desde assets
      const assetPath = 'docs/Manual_de_usuario_sistemaLB.pdf';
      final ByteData data = await rootBundle.load(assetPath);

      // Actualizar progreso: preparando para guardar
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Descargando Manual de Usuario',
        message: 'Preparando archivo...',
        progress: 50,
        maxProgress: 100,
      );

      // Obtener el directorio de descargas
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception('No se pudo acceder al directorio de almacenamiento');
      }

      // Actualizar progreso: guardando archivo
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Descargando Manual de Usuario',
        message: 'Guardando archivo...',
        progress: 80,
        maxProgress: 100,
      );

      // Generar nombre de archivo único
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Manual_Usuario_LeBrunch_$timestamp.pdf';
      final file = File('${dir.path}/$fileName');

      // Guardar el archivo
      await file.writeAsBytes(data.buffer.asUint8List());

      // Completar progreso
      await NotificationService.showDownloadProgressNotification(
        id: progressNotificationId,
        title: 'Descargando Manual de Usuario',
        message: 'Completado!',
        progress: 100,
        maxProgress: 100,
      );

      // Esperar un momento antes de cancelar la notificación de progreso
      await Future.delayed(const Duration(milliseconds: 500));
      await NotificationService.cancelNotification(progressNotificationId);

      // Mostrar notificación de descarga completa
      await NotificationService.showManualDownloadedNotification(
        fileName: fileName,
        filePath: file.path,
      );

      if (!mounted) return;
      // Cerrar el modal de progreso si está abierto
      if (showingProgress && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Mostrar modal de éxito con información sobre la notificación
      await CustomModal.showSuccess(
        context: context,
        title: '¡Manual descargado!',
        message:
            'El Manual de Usuario se ha guardado exitosamente.\n\nPuedes encontrarlo en tus notificaciones o en:\n${file.path}',
        buttonText: 'Entendido',
      );
    } catch (e) {
      // Cancelar notificación de progreso en caso de error
      await NotificationService.cancelNotification(progressNotificationId);

      if (!mounted) return;
      // Cerrar el modal de progreso si está abierto
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Mostrar modal de error
      await CustomModal.showError(
        context: context,
        title: 'Error',
        message: 'Ocurrió un error al descargar el manual: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual de Usuario',
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
              'Sistema Le Brunch',
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
          if (_localPdfPath != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadManualPDF,
              tooltip: 'Descargar Manual PDF',
            )
          else if (_errorMessage.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _loadPdfFromDevice,
              tooltip: 'Cargar PDF desde dispositivo',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return _isLoading
        ? _buildLoadingState()
        : _errorMessage.isNotEmpty
        ? _buildErrorState()
        : _buildModulesContent();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando manual...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Error al cargar el manual',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadPdfFromDevice,
            icon: const Icon(Icons.folder_open),
            label: const Text('Cargar PDF manualmente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadPdfFromAssets,
            child: const Text('Reintentar carga automática'),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildModulesList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4ECDC4).withOpacity(0.1),
            const Color(0xFF45B7D1).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual de Usuario',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      'Sistema Le Brunch - Guía completa',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_localPdfPath != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadManualPDF,
                icon: const Icon(Icons.download),
                label: const Text(
                  'Descargar Manual PDF',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openPdfViewer(),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text(
                  'Ver Manual en la App',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4ECDC4),
                  side: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadPdfFromDevice,
                icon: const Icon(Icons.folder_open),
                label: const Text(
                  'Cargar Manual (PDF)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModulesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Módulos del Manual',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _modules.length,
          itemBuilder: (context, index) {
            return _buildModuleCard(_modules[index]);
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard(ManualModule module) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: module.color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(module.icon, color: Colors.white),
        ),
        title: Text(
          module.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          module.description,
          style: TextStyle(color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: module.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: module.color.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Páginas ${module.startPage} - ${module.endPage}',
                    style: TextStyle(
                      color: module.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Contenido:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...module.content.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: module.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _localPdfPath != null
                            ? () => _openModulePdf(module)
                            : _loadPdfFromDevice,
                    icon: Icon(
                      _localPdfPath != null
                          ? Icons.picture_as_pdf
                          : Icons.folder_open,
                      size: 18,
                    ),
                    label: Text(
                      _localPdfPath != null
                          ? 'Ir a página ${module.startPage} del PDF'
                          : 'Cargar PDF para ver páginas ${module.startPage}-${module.endPage}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _localPdfPath != null ? module.color : Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManualModule {
  final int id;
  final String title;
  final String description;
  final int startPage;
  final int endPage;
  final Color color;
  final IconData icon;
  final List<String> content;

  ManualModule({
    required this.id,
    required this.title,
    required this.description,
    required this.startPage,
    required this.endPage,
    required this.color,
    required this.icon,
    required this.content,
  });
}
