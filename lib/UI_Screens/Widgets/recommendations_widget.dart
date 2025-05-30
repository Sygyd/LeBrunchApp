import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../Api_services/pedidos/recommendations_service.dart';

class RecommendationsWidget extends StatefulWidget {
  final int clientId;

  const RecommendationsWidget({Key? key, required this.clientId})
    : super(key: key);

  @override
  State<RecommendationsWidget> createState() => _RecommendationsWidgetState();
}

class _RecommendationsWidgetState extends State<RecommendationsWidget> {
  bool _isLoading = false;
  Map<String, dynamic>? _recommendationsData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await RecommendationsService.getMixedRecommendations(
        widget.clientId,
        limit: 4,
      );

      if (result['success']) {
        setState(() {
          _recommendationsData = result['data'];
        });
      } else {
        setState(() {
          _errorMessage = result['error'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar recomendaciones: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRecommendationCard(Map<String, dynamic> dish, ThemeData theme) {
    final precio = double.tryParse(dish['precio'].toString()) ?? 0.0;
    final motivo = dish['motivo'] ?? 'Recomendado para ti';

    // Determinar el tipo de recomendación y colores apropiados
    Color primaryColor;
    Color secondaryColor;
    IconData iconData;
    String cardTitle = '';
    String additionalInfo = '';
    String badge = '';

    if (motivo.contains('Tu plato favorito') || dish['veces_pedido'] != null) {
      // Recomendaciones basadas en el historial del cliente
      primaryColor = Colors.red.shade400;
      secondaryColor = Colors.red.shade50;
      iconData = Icons.favorite;
      cardTitle = 'Tu Favorito';
      badge = '❤️';
      if (dish['veces_pedido'] != null) {
        additionalInfo = 'Pedido ${dish['veces_pedido']} veces';
      }
    } else if (motivo.contains('Te gusta la categoría') ||
        dish['categoria_score'] != null) {
      // Recomendaciones basadas en las categorías que le gustan al cliente
      primaryColor = Colors.purple.shade400;
      secondaryColor = Colors.purple.shade50;
      iconData = Icons.recommend;
      cardTitle = 'Te Podría Gustar';
      badge = '✨';
      if (dish['categoria'] != null) {
        additionalInfo = 'Te gustan los ${dish['categoria']}';
      }
    } else if (motivo.contains('Popular entre otros clientes') ||
        dish['total_vendido'] != null) {
      // Recomendaciones basadas en popularidad general
      primaryColor = Colors.orange.shade400;
      secondaryColor = Colors.orange.shade50;
      iconData = Icons.trending_up;
      cardTitle = 'Trending';
      badge = '🔥';
      if (dish['total_vendido'] != null) {
        additionalInfo = '${dish['total_vendido']} pedidos';
      }
    } else {
      // Recomendación genérica
      primaryColor = theme.colorScheme.primary;
      secondaryColor = theme.colorScheme.primaryContainer;
      iconData = Icons.star;
      cardTitle = 'Recomendado';
      badge = '⭐';
      additionalInfo = 'Chef\'s choice';
    }

    return Container(
      width: 280,
      height: 200,
      margin: const EdgeInsets.only(right: 16),
      child: Stack(
        children: [
          // Tarjeta principal con gradiente
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, secondaryColor.withOpacity(0.3)],
              ),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con badge
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge y título en la misma línea
                      Row(
                        children: [
                          Text(badge, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cardTitle.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'MADE TOMMY',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Nombre del plato
                      Text(
                        dish['nombre'] ?? 'Plato desconocido',
                        style: TextStyle(
                          fontFamily: 'LightHouse',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Categoría con diseño moderno
                      if (dish['categoria'] != null || dish['tipo'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${dish['tipo'] ?? ''} • ${dish['categoria'] ?? ''}',
                            style: TextStyle(
                              fontFamily: 'MADE TOMMY',
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Footer con precio y información adicional
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Información adicional
                        if (additionalInfo.isNotEmpty)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconData, size: 14, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      additionalInfo,
                                      style: TextStyle(
                                        fontFamily: 'MADE TOMMY',
                                        fontSize: 10,
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(width: 12),

                        // Precio con diseño destacado
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            '\$${precio.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'MADE TOMMY',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Efecto de brillo sutil en la esquina superior
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.3), Colors.transparent],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sentiment_dissatisfied,
                size: 32,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No pudimos cargar las recomendaciones',
                style: TextStyle(
                  fontFamily: 'LightHouse',
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadRecommendations,
                child: Text(
                  'Reintentar',
                  style: TextStyle(
                    fontFamily: 'LightHouse',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendationsData == null) {
      return const SizedBox.shrink();
    }

    // Obtener las recomendaciones unificadas
    List<dynamic> recomendaciones = [];

    if (_recommendationsData!['personalizadas'] != null) {
      final personalizadas =
          _recommendationsData!['personalizadas']['recomendaciones_unificadas']
              as List<dynamic>? ??
          [];
      recomendaciones.addAll(personalizadas);
    }

    // Si no hay suficientes recomendaciones personalizadas, agregar populares
    if (recomendaciones.length < 4 &&
        _recommendationsData!['populares'] != null) {
      final populares =
          _recommendationsData!['populares'] as List<dynamic>? ?? [];

      // Tomar los populares que faltan, pero SIN sobrescribir su motivo original
      final popularesToAdd =
          populares.take(4 - recomendaciones.length).toList();

      for (var popular in popularesToAdd) {
        // Solo agregar motivo si no tiene uno ya
        if (popular['motivo'] == null || popular['motivo'].toString().isEmpty) {
          popular['motivo'] = 'Popular entre otros clientes';
        }
        recomendaciones.add(popular);
      }
    }

    if (recomendaciones.isEmpty) {
      return const SizedBox.shrink();
    }

    // Generar mensaje dinámico basado en los tipos de recomendaciones
    String mensaje = 'Te recomendamos:';
    final tiposPresentes = <String>{};

    for (var rec in recomendaciones) {
      final motivo = rec['motivo']?.toString() ?? '';
      if (motivo.contains('favorito')) {
        tiposPresentes.add('favoritos');
      } else if (motivo.contains('Popular')) {
        tiposPresentes.add('populares');
      } else if (motivo.contains('categoría')) {
        tiposPresentes.add('similares');
      }
    }

    if (tiposPresentes.contains('favoritos') &&
        tiposPresentes.contains('populares')) {
      mensaje = 'Tus favoritos y platos populares:';
    } else if (tiposPresentes.contains('favoritos')) {
      mensaje = 'Basado en tus gustos:';
    } else if (tiposPresentes.contains('populares')) {
      mensaje = 'Platos populares para ti:';
    } else if (tiposPresentes.contains('similares')) {
      mensaje = 'Te pueden gustar estos:';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mensaje,
                      style: TextStyle(
                        fontFamily: 'LightHouse',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                    if (tiposPresentes.length > 1)
                      Text(
                        'Combinando tus favoritos con tendencias',
                        style: TextStyle(
                          fontFamily: 'MADE TOMMY',
                          fontSize: 12,
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${recomendaciones.length} sugerencias',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recomendaciones.length,
            itemBuilder: (context, index) {
              return _buildRecommendationCard(recomendaciones[index], theme);
            },
          ),
        ),
      ],
    );
  }
}
