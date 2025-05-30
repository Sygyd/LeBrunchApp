import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/models/user.dart';
import '/Api_services/usuarios/register_service.dart';
import '/UI_Screens/Widgets/custom_modal.dart';
import '/Api_services/password_reset_service.dart';
import 'dart:convert';
import '/Api_services/cart_service.dart';

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
    );
  }

  static void showRegisterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RegisterModalContent(),
    );
  }

  static void showForgotPasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ForgotPasswordModalContent(),
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

    print(
      '🔑 Token guardado en login: ${data['token'] != null ? "Sí (${data['token'].toString().length > 20 ? data['token'].toString().substring(0, 20) + '...' : data['token'].toString()})" : "No"}',
    );

    // Manejo mejorado del rol para manejar tanto string como int
    int userRol = 1; // Valor predeterminado: cliente

    if (data['rol'] != null) {
      // Intentar parsear como int si es string, o usar directamente si ya es int
      if (data['rol'] is String) {
        // Primero intentar hacer un parse directo si es número
        userRol = int.tryParse(data['rol']) ?? 1;

        // Si no es un número, intentar mapear el string del rol
        if (userRol == 1 && data['rol'].toString().isNotEmpty) {
          final rolStr = data['rol'].toString().toLowerCase();
          if (rolStr == 'admin' || rolStr == 'administrador')
            userRol = 0;
          else if (rolStr == 'cliente' || rolStr == 'client')
            userRol = 1;
          else if (rolStr == 'cocinero' || rolStr == 'cook')
            userRol = 2;
          else if (rolStr == 'barista')
            userRol = 3;
        }
      } else if (data['rol'] is int) {
        userRol = data['rol'];
      }
    }

    print(
      '🔑 Iniciando sesión - Rol recibido: ${data['rol']} (${data['rol'].runtimeType})',
    );
    print('🔑 Rol procesado y guardado: $userRol');

    await prefs.setInt('user_rol', userRol);
    await prefs.setString('user_name', data['nombre'] ?? 'Usuario');
    await prefs.setString('user_cedula', data['cedula'] ?? '');

    // Guardar el ID del usuario para poder identificarlo en la pantalla de administración
    if (data['id'] != null) {
      final userId = int.parse(data['id'].toString());
      await prefs.setInt('user_id', userId);
      print('✅ ID de usuario guardado: ${data['id']}');

      // Primero reiniciar completamente el servicio de carrito para limpiar cualquier caché anterior
      final cartService = CartService();
      await cartService.resetService();

      // Luego asignar el nuevo ID de usuario para cargar su carrito específico
      await cartService.setUserId(userId.toString());
      print(
        '✅ CartService completamente reiniciado e inicializado con ID: $userId',
      );
    } else {
      print('⚠️ No se recibió el ID de usuario en la respuesta');
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

// FORGOT PASSWORD MODAL (con flujo completo de dos pasos)
class _ForgotPasswordModalContent extends StatefulWidget {
  @override
  State<_ForgotPasswordModalContent> createState() =>
      _ForgotPasswordModalContentState();
}

class _ForgotPasswordModalContentState
    extends State<_ForgotPasswordModalContent> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int? _verifiedUserId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep(int userId) {
    setState(() {
      _verifiedUserId = userId;
      _currentStep = 1;
    });
    _pageController.nextPage(
      duration: animationDuration,
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    setState(() {
      _currentStep = 0;
      _verifiedUserId = null;
    });
    _pageController.previousPage(
      duration: animationDuration,
      curve: Curves.easeInOut,
    );
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
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Indicador de pasos
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          _currentStep >= 1
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Contenido de los pasos
            SizedBox(
              height: 500, // Altura fija para evitar cambios de tamaño
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _VerifyCredentialsStep(onNext: _nextStep),
                  _ResetPasswordStep(
                    userId: _verifiedUserId,
                    onBack: _previousStep,
                    onSuccess: () {
                      Navigator.pop(context);
                      AuthModals.showLoginModal(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PASO 1: Verificar credenciales
class _VerifyCredentialsStep extends StatefulWidget {
  final Function(int) onNext;

  const _VerifyCredentialsStep({required this.onNext});

  @override
  State<_VerifyCredentialsStep> createState() => _VerifyCredentialsStepState();
}

class _VerifyCredentialsStepState extends State<_VerifyCredentialsStep> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Por favor ingresa un correo electrónico válido';
    }
    return null;
  }

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

  Future<void> _verifyCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await PasswordResetService.verifyCredentials(
        email: _emailController.text.trim(),
        cedula: _cedulaController.text.trim(),
      );

      if (result['success'] == true) {
        widget.onNext(result['userId']);
      } else {
        setState(() {
          _errorMessage = result['message'];
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            'Verificar Identidad',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtítulo
          Text(
            'Ingresa tu correo electrónico y número de cédula para verificar tu identidad',
            style: Theme.of(context).textTheme.bodyMedium,
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

          // Campo de Email
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_cedulaFocus);
            },
            keyboardType: TextInputType.emailAddress,
            validator:
                (value) =>
                    PasswordResetService.isValidEmail(value ?? '')
                        ? null
                        : 'Por favor ingresa un correo electrónico válido',
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
            onFieldSubmitted: (_) => _verifyCredentials(),
            keyboardType: TextInputType.number,
            validator:
                (value) =>
                    PasswordResetService.isValidCedula(value ?? '')
                        ? null
                        : 'La cédula debe tener entre 5 y 10 dígitos',
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

          // Botón de Verificar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyCredentials,
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
                      : Text('Verificar identidad'),
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
    );
  }
}

// PASO 2: Restablecer contraseña
class _ResetPasswordStep extends StatefulWidget {
  final int? userId;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _ResetPasswordStep({
    required this.userId,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_ResetPasswordStep> createState() => _ResetPasswordStepState();
}

class _ResetPasswordStepState extends State<_ResetPasswordStep> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu nueva contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await PasswordResetService.resetPassword(
        userId: widget.userId!,
        newPassword: _passwordController.text,
      );

      if (result['success'] == true) {
        await CustomModal.showSuccess(
          context: context,
          message: result['message'],
          onPressed: widget.onSuccess,
        );
      } else {
        setState(() {
          _errorMessage = result['message'];
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            'Nueva Contraseña',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtítulo
          Text(
            'Ingresa tu nueva contraseña. Debe tener al menos 6 caracteres.',
            style: Theme.of(context).textTheme.bodyMedium,
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

          // Campo Nueva Contraseña
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_confirmPasswordFocus);
            },
            obscureText: _obscurePassword,
            validator:
                (value) =>
                    PasswordResetService.isValidPassword(value ?? '')
                        ? null
                        : 'La contraseña debe tener al menos 6 caracteres',
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed:
                    () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Campo Confirmar Contraseña
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocus,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            obscureText: _obscureConfirmPassword,
            validator: _validateConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed:
                    () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botones
          Row(
            children: [
              // Botón Atrás
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Atrás'),
                ),
              ),

              const SizedBox(width: 16),

              // Botón Cambiar Contraseña
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
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
                          : Text('Cambiar contraseña'),
                ),
              ),
            ],
          ),
        ],
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

    // Crear un usuario temporal con ID ficticio y rol cliente (1)
    final user = User(
      id: 0, // ID temporal que será asignado por el servidor
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      cedula: _cedulaController.text.trim(),
      email: _emailController.text.trim(),
      rol: 1, // Por defecto es cliente (rol 1)
    );

    try {
      // Utilizar el servicio de API para registrar al usuario, enviando los datos adicionales
      final response = await http.post(
        Uri.parse("$apiBaseUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          ...user.toJson(),
          'contrasena':
              _contrasenaController.text, // Enviamos la contraseña por separado
        }),
      );

      print("Código de respuesta: ${response.statusCode}");
      print("Respuesta del servidor: ${response.body}");

      if (response.statusCode == 201 && mounted) {
        await CustomModal.showSuccess(
          context: context,
          message: "Registro exitoso! Por favor inicia sesión",
          onPressed: () {
            Navigator.pop(context);
            AuthModals.showLoginModal(context);
          },
        );
      } else {
        if (mounted) {
          final responseData = jsonDecode(response.body);
          final errorMessage = responseData['error'] ?? 'Error en el registro';
          await CustomModal.showError(context: context, message: errorMessage);
        }
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
