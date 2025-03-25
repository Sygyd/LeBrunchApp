import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/get_dishes_service.dart';
import '/UI_Screens/Widgets/search_bar.dart' as custom;
import '/UI_Screens/Widgets/category_carousel.dart';
import '/UI_Screens/Widgets/dish_card.dart';

class ClientMenuScreen extends StatelessWidget {
  const ClientMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Pantalla de Menú del Cliente'));
  }
}
