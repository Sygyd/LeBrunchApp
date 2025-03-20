import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/UI_Screens/Auth_Screens/register.dart';
import '/UI_Screens/Widgets/custom_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formSignInKey = GlobalKey<FormState>();
  bool rememberPassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    if (_formSignInKey.currentState!.validate()) {
      final response = await http.post(
        Uri.parse('http://192.168.1.121:3000/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text,
          "contrasena": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token']; // Token de autenticación
        final rol = int.parse(
          data['rol'].toString(),
        ); // Asegurarse de que el rol sea un int

        // Guardar el token y el rol en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setInt('user_rol', rol);

        // Redirigir al usuario según su rol
        if (rol == 0) {
          // Rol 0: Administrador
          Navigator.pushReplacementNamed(context, '/menu');
        } else if (rol == 1) {
          // Rol 1: Cliente
          Navigator.pushReplacementNamed(context, '/client');
        } else {
          // Rol desconocido
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rol de usuario no válido")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Credenciales incorrectas")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Column(
        children: [
          Expanded(
            flex: 7,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25.0, 50.0, 25.0, 20.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formSignInKey,
                  child: Column(
                    children: [
                      const Text(
                        'Gracias por venir',
                        style: TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 40.0),
                      TextFormField(
                        controller: _emailController,
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Ingresa tu email'
                                    : null,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Ingresa tu contraseña'
                                    : null,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          hintText: 'Contraseña',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: const Text('Ingresar'),
                        ),
                      ),
                      const SizedBox(height: 25.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿No tienes cuenta? '),
                          GestureDetector(
                            onTap:
                                () => Navigator.pushNamed(context, '/register'),
                            child: const Text(
                              'Regístrate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
