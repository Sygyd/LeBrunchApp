import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/models/user.dart';
import '/Api_services/usuarios/register_service.dart';
import '/UI_Screens/Widgets/custom_modal.dart';
import 'dart:convert';

// Constantes para la configuración
const String apiBaseUrl = 'http://192.168.1.121:3000';
const Duration animationDuration = Duration(milliseconds: 300);

class AuthModals {
  static void showLoginModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LoginModalContent(),
      transitionAnimationController: AnimationController(
        duration: animationDuration,
        vsync: Navigator.of(context),
      ),
    );
  }

  static void showRegisterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RegisterModalContent(),
      transitionAnimationController: AnimationController(
        duration: animationDuration,
        vsync: Navigator.of(context),
      ),
    );
  }

  static void showForgotPasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ForgotPasswordModalContent(),
      transitionAnimationController: AnimationController(
        duration: animationDuration,
        vsync: Navigator.of(context),
      ),
    );
  }
}

// LOGIN MODAL (versión simplificada)
class _LoginModalContent extends StatefulWidget {
  @override
  State<_LoginModalContent> createState() => _LoginModalContentState();
}

class _LoginModalContentState extends State<_LoginModalContent> {
  final _formSignInKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formSignInKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "contrasena": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data);

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        if (!mounted) return;

        String errorMessage =
            response.statusCode == 401
                ? "Credenciales incorrectas"
                : "Error en el servidor (${response.statusCode})";

        await CustomModal.showError(context: context, message: errorMessage);
      }
    } catch (e) {
      if (!mounted) return;

      await CustomModal.showError(
        context: context,
        message: "Error de conexión: ${e.toString()}",
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token']);
    await prefs.setInt('user_rol', int.parse(data['rol'].toString()));
    await prefs.setString('user_name', data['nombre'] ?? 'Usuario');
    await prefs.setString('user_cedula', data['cedula'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formSignInKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Título
              Text(
                'Ingresa a tu cuenta',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              // Campo Email (validación simplificada)
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocus);
                },
                keyboardType: TextInputType.emailAddress,
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Ingresa tu email' : null,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Campo Contraseña (validación simplificada)
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                obscureText: _obscurePassword,
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Ingresa tu contraseña' : null,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Olvidé contraseña
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    AuthModals.showForgotPasswordModal(context);
                  },
                  child: Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              const SizedBox(height: 20),
              // Botón
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                          : Text('Ingresar'),
                ),
              ),
              const SizedBox(height: 20),
              // Enlace a registro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿No tienes cuenta?'),
                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              Navigator.pop(context);
                              AuthModals.showRegisterModal(context);
                            },
                    child: Text('Regístrate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// FORGOT PASSWORD MODAL (actualizado para altura adaptativa)
class _ForgotPasswordModalContent extends StatefulWidget {
  @override
  State<_ForgotPasswordModalContent> createState() =>
      _ForgotPasswordModalContentState();
}

class _ForgotPasswordModalContentState
    extends State<_ForgotPasswordModalContent> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _cedulaFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _cedulaController.dispose();
    _emailFocus.dispose();
    _cedulaFocus.dispose();
    super.dispose();
  }

  /// Validador de email
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Por favor ingresa un correo electrónico válido';
    }
    return null;
  }

  /// Validador de cédula
  String? _validateCedula(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu número de cédula';
    }
    if (value.length < 5 || value.length > 10) {
      return 'La cédula debe tener entre 5 y 10 dígitos';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'La cédula debe contener solo números';
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/verify-reset-password'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "cedula": _cedulaController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _successMessage =
              data['message'] ??
              'Te hemos enviado un correo con instrucciones para restablecer tu contraseña.';
        });
      } else {
        setState(() {
          _errorMessage =
              data['message'] ??
              'No encontramos una cuenta con esos datos. Por favor verifica la información.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Título
              Text(
                'Recuperar Contraseña',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Ingresa tu correo electrónico y número de cédula para verificar tu identidad',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Mensaje de error
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Mensaje de éxito
              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Campo de Email
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_cedulaFocus);
                },
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Campo de Cédula
              TextFormField(
                controller: _cedulaController,
                focusNode: _cedulaFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitForm(),
                keyboardType: TextInputType.number,
                validator: _validateCedula,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Número de cédula',
                  hintText: 'Ej: 12345678',
                  prefixIcon: Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botón de Recuperar contraseña
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                          : Text('Recuperar contraseña'),
                ),
              ),

              const SizedBox(height: 16),

              // Link para volver a login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Recordaste tu contraseña?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      AuthModals.showLoginModal(context);
                    },
                    child: Text('Iniciar sesión'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// REGISTER MODAL (actualizado para altura adaptativa)
class _RegisterModalContent extends StatefulWidget {
  @override
  State<_RegisterModalContent> createState() => _RegisterModalContentState();
}

class _RegisterModalContentState extends State<_RegisterModalContent> {
  final _formSignupKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _confirmContrasenaController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final FocusNode _nombreFocus = FocusNode();
  final FocusNode _apellidoFocus = FocusNode();
  final FocusNode _cedulaFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _contrasenaFocus = FocusNode();
  final FocusNode _confirmContrasenaFocus = FocusNode();

  @override
  void dispose() {
    _nombreFocus.dispose();
    _apellidoFocus.dispose();
    _cedulaFocus.dispose();
    _emailFocus.dispose();
    _contrasenaFocus.dispose();
    _confirmContrasenaFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formSignupKey.currentState!.validate()) return;
    if (_contrasenaController.text != _confirmContrasenaController.text) {
      await CustomModal.showError(
        context: context,
        message: "Las contraseñas no coinciden",
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = User(
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      cedula: _cedulaController.text.trim(),
      email: _emailController.text.trim(),
      contrasena: _contrasenaController.text,
    );

    try {
      final success = await ApiService.registerUser(user);
      if (success && mounted) {
        await CustomModal.showSuccess(
          context: context,
          message: "Registro exitoso! Por favor inicia sesión",
          onPressed: () {
            Navigator.pop(context);
            AuthModals.showLoginModal(context);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        await CustomModal.showError(
          context: context,
          message: "Error en el registro: ${e.toString()}",
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formSignupKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Título
              Text(
                'Crea tu cuenta',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              // Campo Nombre
              TextFormField(
                controller: _nombreController,
                focusNode: _nombreFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_apellidoFocus);
                },
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Ingresa tu nombre';
                  if (value.length < 2) return 'Nombre muy corto';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              // Campo Apellido
              TextFormField(
                controller: _apellidoController,
                focusNode: _apellidoFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_cedulaFocus);
                },
                decoration: InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Ingresa tu apellido';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              // Campo Cédula
              TextFormField(
                controller: _cedulaController,
                focusNode: _cedulaFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_emailFocus);
                },
                decoration: InputDecoration(
                  labelText: 'Cédula',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Ingresa tu cédula';
                  if (value.length < 6) return 'Cédula inválida';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              // Campo Email
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_contrasenaFocus);
                },
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa tu email';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Email inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              // Campo Contraseña
              TextFormField(
                controller: _contrasenaController,
                focusNode: _contrasenaFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_confirmContrasenaFocus);
                },
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Ingresa tu contraseña';
                  if (value.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              // Campo Confirmar Contraseña
              TextFormField(
                controller: _confirmContrasenaController,
                focusNode: _confirmContrasenaFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed:
                        () => setState(
                          () =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                        ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Confirma tu contraseña';
                  return null;
                },
              ),
              const SizedBox(height: 25),
              // Botón
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                          : Text('Registrarse'),
                ),
              ),
              const SizedBox(height: 20),
              // Enlace a login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Ya tienes cuenta?'),
                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              Navigator.pop(context);
                              AuthModals.showLoginModal(context);
                            },
                    child: Text('Inicia sesión'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
