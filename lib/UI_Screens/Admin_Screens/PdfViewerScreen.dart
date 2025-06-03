import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../Widgets/background_scaffold.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String title;
  final int? initialPage;

  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.title,
    this.initialPage,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfController? _controller;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _disposed = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _initializePdfViewer();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Future<void> _initializePdfViewer() async {
    if (_disposed) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final document = PdfDocument.openFile(widget.pdfPath);
      final newController = PdfController(document: document);

      if (_disposed) {
        newController.dispose();
        return;
      }

      // Elimina el controller anterior si existe
      _controller?.dispose();

      // Asigna el nuevo controller
      _controller = newController;

      // Obtener el número total de páginas
      final doc = await document;
      _totalPages = doc.pagesCount;

      print('📖 [PdfViewer] PDF cargado: $_totalPages páginas totales');
      print('📖 [PdfViewer] Página inicial solicitada: ${widget.initialPage}');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Esperar un poco para que el PDF se renderice completamente
        // y luego navegar a la página inicial si se especifica
        if (widget.initialPage != null &&
            widget.initialPage! > 0 &&
            widget.initialPage! <= _totalPages) {
          print(
            '📖 [PdfViewer] Esperando para navegar a página ${widget.initialPage}...',
          );

          // Usar addPostFrameCallback para asegurar que el widget esté completamente construido
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            // Pequeño delay adicional para asegurar que el PDF esté listo
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted && !_disposed) {
              _navigateToPage(widget.initialPage!);
            }
          });
        }
      }
    } catch (e) {
      print('❌ [PdfViewer] Error al cargar PDF: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar PDF: $e';
        });
      }
    }
  }

  Future<void> _navigateToPage(int pageNumber) async {
    if (_controller != null && pageNumber > 0 && pageNumber <= _totalPages) {
      try {
        print(
          '📖 [PdfViewer] Intentando navegar a página $pageNumber de $_totalPages',
        );

        // pdfx usa índice basado en 1 (no 0), así que no necesitamos ajustar
        await _controller!.animateToPage(
          pageNumber,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        print('✅ [PdfViewer] Navegación exitosa a página $pageNumber');

        if (mounted) {
          setState(() {
            _currentPage = pageNumber;
          });
        }
      } catch (e) {
        print('❌ [PdfViewer] Error al navegar a la página $pageNumber: $e');

        // Intentar navegación sin animación como alternativa
        try {
          print('📖 [PdfViewer] Intentando navegación directa...');
          await _controller!.animateToPage(
            pageNumber,
            duration: Duration.zero, // Sin animación
            curve: Curves.linear,
          );

          print(
            '✅ [PdfViewer] Navegación directa exitosa a página $pageNumber',
          );

          if (mounted) {
            setState(() {
              _currentPage = pageNumber;
            });
          }
        } catch (e2) {
          print('❌ [PdfViewer] Navegación directa también falló: $e2');
          // Como último recurso, actualizar solo el estado visual
          if (mounted) {
            setState(() {
              _currentPage = pageNumber;
            });
          }
        }
      }
    } else {
      print('❌ [PdfViewer] Parámetros inválidos para navegación:');
      print('   Controller: ${_controller != null}');
      print('   Página: $pageNumber');
      print('   Total páginas: $_totalPages');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) {
      return const Center(child: Text('PDF cerrado'));
    }

    if (_isLoading) {
      return const BackgroundScaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
              ),
              SizedBox(height: 16),
              Text('Cargando PDF...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return BackgroundScaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
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
                'Error al cargar',
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_errorMessage, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return BackgroundScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
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
              'Visor PDF',
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
        actions:
            _totalPages > 0
                ? [
                  // Botón para ir a página inicial (si se especificó)
                  if (widget.initialPage != null &&
                      widget.initialPage! != _currentPage)
                    IconButton(
                      icon: const Icon(Icons.bookmark),
                      onPressed: () => _navigateToPage(widget.initialPage!),
                      tooltip: 'Ir a página ${widget.initialPage}',
                    ),
                  // Botón de página anterior
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _currentPage > 1
                            ? () => _navigateToPage(_currentPage - 1)
                            : null,
                    tooltip: 'Página anterior',
                  ),
                  // Botón de página siguiente
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        _currentPage < _totalPages
                            ? () => _navigateToPage(_currentPage + 1)
                            : null,
                    tooltip: 'Página siguiente',
                  ),
                ]
                : null,
      ),
      body:
          _controller != null
              ? PdfView(
                controller: _controller!,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
              )
              : const Center(child: Text('Error: Controlador no disponible')),
    );
  }
}
