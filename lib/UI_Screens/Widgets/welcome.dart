import 'package:flutter/material.dart';
import 'package:le_brunch_app/UI_Screens/Widgets/text_with_border.dart';
import '/UI_Screens/Widgets/custom_scaffold.dart';
import '/UI_Screens/Widgets/welcome_button.dart';
import '/UI_Screens/Auth_Screens/auth_modals.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return CustomScaffold(
      showAppBar: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              SizedBox(
                height: screenHeight * 0.15,
              ), // Espacio superior reducido
              // Imagen con tamaño fijo más pequeño
              Image.asset(
                'assets/images/logowelcome.png',
                height: screenHeight * 0.20, // Reducido de 0.3 a 0.25
                fit: BoxFit.contain,
              ),
              SizedBox(height: screenHeight * 0.1), // Espacio reducido
              // Título "Bienvenido"
              TextWithBorder(
                text: 'Bienvenido',
                fontSize: 45,
                fontWeight: FontWeight.w600,
                borderWidth: 3.0,
              ),
              const SizedBox(height: 12), // Espacio reducido
              // Subtítulo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextWithBorder(
                  text: 'Horneamos, Cocinamos y Disfrutamos',
                  fontSize: 22,
                  fontWeight: FontWeight.normal,
                  borderWidth: 2.0,
                ),
              ),
            ],
          ),
          // Botones (se mantienen igual)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: WelcomeButton(
                    buttonText: 'Ingresa',
                    onTap: () => AuthModals.showLoginModal(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: WelcomeButton(
                    buttonText: 'Regístrate',
                    onTap: () => AuthModals.showRegisterModal(context),
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
