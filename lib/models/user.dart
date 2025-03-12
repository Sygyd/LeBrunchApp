class User {
  final String nombre;
  final String apellido;
  final String cedula;
  final String email;
  final String contrasena; // Nuevo campo para la contraseña

  User({
    required this.nombre,
    required this.apellido,
    required this.cedula,
    required this.email,
    required this.contrasena, // Asegúrate de que el constructor acepte la contraseña
  });

  // Convierte el objeto a un mapa de datos para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'apellido': apellido,
      'cedula': cedula,
      'email': email,
      'contrasena': contrasena, // Agrega la contraseña al JSON
    };
  }
}
