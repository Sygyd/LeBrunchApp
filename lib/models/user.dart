class User {
  final int id;
  final String nombre;
  final String apellido;
  final String cedula;
  final String email;
  final String rol; // Cambio a String para manejar "00" y "0"
  final bool? isSuperAdmin; // Nueva propiedad para identificar super admin

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.cedula,
    required this.email,
    required this.rol,
    this.isSuperAdmin,
  });

  // Constructor para crear un usuario desde un mapa (JSON)
  factory User.fromJson(Map<String, dynamic> json) {
    // Convertir el rol a string para manejar "00" y "0"
    String rolValue;
    final rolOriginal = json['rol'];
    print('🔄 Convirtiendo rol: $rolOriginal (${rolOriginal.runtimeType})');

    if (json['rol'] is String) {
      rolValue = json['rol'].toString();
      print('  ✓ Usando rol como string: "$rolValue"');
    } else if (json['rol'] is int) {
      rolValue = json['rol'].toString();
      print('  ✓ Convertido de int a string: "$rolValue"');
    } else {
      rolValue = '1'; // Valor predeterminado
      print('  ✓ Usando valor predeterminado: "$rolValue"');
    }

    // Verificar si es super admin (rol "00" o flag del backend)
    final bool isSuperAdminUser =
        json['isSuperAdmin'] == true || rolValue == '00' || json['id'] == 10;

    final user = User(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      cedula: json['cedula'] ?? '',
      email: json['email'] ?? '',
      rol: rolValue,
      isSuperAdmin: isSuperAdminUser,
    );

    print(
      '👤 Usuario creado: ${user.nombreCompleto}, rol: "${user.rol}" (${user.rolNombre})${isSuperAdminUser ? ' - SUPER ADMIN' : ''}',
    );
    return user;
  }

  // Convertir string de rol a entero según convención
  static int _getRolFromString(String rolStr) {
    final normalizedRol = rolStr.toString().toLowerCase().trim();
    print('  🔍 Normalizando rol: "$normalizedRol"');

    switch (normalizedRol) {
      case 'admin':
      case 'administrador':
      case '0':
        return 0;
      case 'cliente':
      case 'customer':
      case 'client':
      case '1':
        return 1;
      case 'cocinero':
      case 'cook':
      case '2':
        return 2;
      case 'barista':
      case '3':
        return 3;
      default:
        print(
          '  ⚠️ Rol no reconocido: "$normalizedRol", usando cliente (1) por defecto',
        );
        return 1; // Por defecto cliente
    }
  }

  // Convertir el usuario a un mapa (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'cedula': cedula,
      'email': email,
      'rol': rol,
      'isSuperAdmin': isSuperAdmin,
    };
  }

  // Obtener el nombre completo del usuario
  String get nombreCompleto => '$nombre $apellido';

  // Métodos de conveniencia para verificar roles
  bool get isAdmin => rol == '0' || isSuperAdminValue;
  bool get isClient => rol == '1';
  bool get isCook => rol == '2';
  bool get isBarista => rol == '3';

  // Verificar si es super admin (usar tanto la propiedad como el rol)
  bool get isSuperAdminValue => isSuperAdmin == true || rol == '00';

  // Obtener nombre del rol
  String get rolNombre {
    if (isSuperAdminValue) {
      return 'Super Administrador';
    }
    switch (rol) {
      case '0':
        return 'Administrador';
      case '1':
        return 'Cliente';
      case '2':
        return 'Cocinero';
      case '3':
        return 'Barista';
      default:
        return 'Usuario';
    }
  }

  // Obtener color del rol
  int get rolColor {
    if (isSuperAdminValue) {
      return 0xFFD50000; // Rojo intenso para Super Admin
    }
    switch (rol) {
      case '0':
        return 0xFF9C27B0; // Morado para Admin
      case '1':
        return 0xFF2196F3; // Azul para Cliente
      case '2':
        return 0xFFE57373; // Rojo claro para Cocinero
      case '3':
        return 0xFF4DD0E1; // Cyan para Barista
      default:
        return 0xFF757575; // Gris por defecto
    }
  }

  // Obtener icono del rol
  String get rolIcon {
    if (isSuperAdminValue) {
      return 'shield'; // Escudo para Super Admin
    }
    switch (rol) {
      case '0':
        return 'admin_panel_settings';
      case '1':
        return 'person';
      case '2':
        return 'restaurant';
      case '3':
        return 'coffee';
      default:
        return 'help';
    }
  }

  // Métodos de conveniencia para verificar permisos
  bool get canDeleteUsers => isSuperAdminValue || rol == '0';
  bool get canDeleteAdmins => isSuperAdminValue;
  bool get canModifyRoles => isSuperAdminValue;
  bool get isProtectedFromDeletion => isSuperAdminValue;
}
