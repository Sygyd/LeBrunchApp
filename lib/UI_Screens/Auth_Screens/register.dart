import 'package:flutter/material.dart';
import '/UI_Screens/Auth_Screens/login.dart';
import '/UI_Screens/Widgets/custom_scaffold.dart';
import '/Api_services/usuarios/register_service.dart';
import '/models/user.dart';
import '/theme/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formSignupKey = GlobalKey<FormState>();
  bool agreePersonalData = true;

  // Controladores para los campos de entrada
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoController = TextEditingController();
  final TextEditingController cedulaController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contrasenaController = TextEditingController();

  // Función para registrar usuario
  void registerUser() async {
    if (_formSignupKey.currentState!.validate() && agreePersonalData) {
      User user = User(
        nombre: nombreController.text,
        apellido: apellidoController.text,
        cedula: cedulaController.text,
        email: emailController.text,
        contrasena: contrasenaController.text, // Aquí se envía la contraseña
      );

      bool success = await ApiService.registerUser(user);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Registro exitoso")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error al registrar")));
      }
    } else if (!agreePersonalData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor aprueba enviar tu información'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Column(
        children: [
          const Expanded(flex: 1, child: SizedBox(height: 10)),
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
                  key: _formSignupKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Crea tu cuenta',
                        style: TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w900,
                          color: lightColorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 40.0),

                      // Campo Nombre
                      TextFormField(
                        controller: nombreController,
                        validator:
                            (value) =>
                                value!.isEmpty ? 'Ingresa tu nombre' : null,
                        decoration: InputDecoration(
                          label: const Text('Nombre'),
                          hintText: 'Ingresa tu nombre',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // Campo Apellido
                      TextFormField(
                        controller: apellidoController,
                        validator:
                            (value) =>
                                value!.isEmpty ? 'Ingresa tu apellido' : null,
                        decoration: InputDecoration(
                          label: const Text('Apellido'),
                          hintText: 'Ingresa tu apellido',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // Campo Cédula
                      TextFormField(
                        controller: cedulaController,
                        validator:
                            (value) =>
                                value!.isEmpty ? 'Ingresa tu cédula' : null,
                        decoration: InputDecoration(
                          label: const Text('Cédula'),
                          hintText: 'Número de cédula',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // Campo Correo
                      TextFormField(
                        controller: emailController,
                        validator:
                            (value) =>
                                value!.isEmpty ? 'Ingresa tu correo' : null,
                        decoration: InputDecoration(
                          label: const Text('Correo'),
                          hintText: 'Correo electrónico',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // Campo Contraseña
                      TextFormField(
                        controller: contrasenaController,
                        obscureText: true,
                        obscuringCharacter: '*',
                        validator:
                            (value) =>
                                value!.isEmpty ? 'Ingresa tu contraseña' : null,
                        decoration: InputDecoration(
                          label: const Text('Contraseña'),
                          hintText: 'Contraseña',
                          hintStyle: const TextStyle(color: Colors.black26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25.0),

                      // Checkbox de aprobación de datos
                      Row(
                        children: [
                          Checkbox(
                            value: agreePersonalData,
                            onChanged: (bool? value) {
                              setState(() {
                                agreePersonalData = value!;
                              });
                            },
                            activeColor: lightColorScheme.primary,
                          ),
                          const Text(
                            'Yo apruebo enviar mi ',
                            style: TextStyle(color: Colors.black45),
                          ),
                          Text(
                            'información personal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: lightColorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25.0),

                      // Botón de registro
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: registerUser,
                          child: const Text('Registrarse'),
                        ),
                      ),
                      const SizedBox(height: 30.0),

                      // ¿Ya tienes una cuenta?
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿Ya tienes una cuenta?',
                            style: TextStyle(color: Colors.black45),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (e) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              ' Inicia sesión!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: lightColorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),
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
