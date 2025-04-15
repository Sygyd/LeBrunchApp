class User {
  final int id;
  final String nombre;
  final String apellido;
  final String cedula;
  final String email;
  final int rol;

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.cedula,
    required this.email,
    required this.rol,
  });

  // Constructor para crear un usuario desde un mapa (JSON)
  factory User.fromJson(Map<String, dynamic> json) {
    // Convertir el rol a entero si viene como string
    int rolValue;
    final rolOriginal = json['rol'];
    print('🔄 Convirtiendo rol: $rolOriginal (${rolOriginal.runtimeType})');

    if (json['rol'] is String) {
      try {
        rolValue = int.parse(json['rol']);
        print('  ✓ Convertido de string a int: $rolValue');
      } catch (e) {
        // Si no se puede convertir, asignar un valor predeterminado según el string
        rolValue = _getRolFromString(json['rol']);
        print('  ✓ Mapeado de string a int: $rolValue');
      }
    } else {
      rolValue = json['rol'] ?? 1;
      print('  ✓ Usando valor existente: $rolValue');
    }

    final user = User(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      cedula: json['cedula'] ?? '',
      email: json['email'] ?? '',
      rol: rolValue,
    );

    print(
      '👤 Usuario creado: ${user.nombreCompleto}, rol: ${user.rol} (${user.rolNombre})',
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
    };
  }

  // Obtener el nombre completo del usuario
  String get nombreCompleto => '$nombre $apellido';

  // Obtener el nombre del rol del usuario
  String get rolNombre {
    switch (rol) {
      case 0:
        return 'Administrador';
      case 1:
        return 'Cliente';
      case 2:
        return 'Cocinero';
      case 3:
        return 'Barista';
      default:
        return 'Desconocido';
    }
  }

  // Obtener el color asociado al rol (para mostrar en la UI)
  int get rolColor {
    switch (rol) {
      case 0:
        return 0xFF9C27B0; // Morado para administradores
      case 1:
        return 0xFF2196F3; // Azul para clientes
      case 2:
        return 0xFFE57373; // Rojo para cocineros
      case 3:
        return 0xFF4DD0E1; // Turquesa para baristas
      default:
        return 0xFF9E9E9E; // Gris para rol desconocido
    }
  }

  // Obtener el icono asociado al rol (para mostrar en la UI)
  String get rolIcono {
    switch (rol) {
      case 0:
        return 'admin_panel_settings'; // Admin - Consistente con FAB
      case 1:
        return 'person'; // Cliente
      case 2:
        return 'restaurant'; // Cocinero - Consistente con FAB
      case 3:
        return 'coffee'; // Barista - Consistente con FAB
      default:
        return 'help';
    }
  }
}
