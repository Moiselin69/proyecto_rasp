class Persona {
  final int id;
  final String nombre;
  final String? apellidos; // Cámbialo a String? si puede venir vacío
  final String? nickname;  // AÑADIDO: Necesario para que funcione tu pantalla
  final String correo;

  Persona({
    required this.id,
    required this.nombre,
    this.apellidos,
    this.nickname,
    required this.correo,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      apellidos: json['apellidos'], // Puede ser null
      nickname: json['nickname'],   // Puede ser null
      correo: json['correo_electronico'] ?? '',
    );
  }

  // Getter para compatibilidad si antes usabas .email
  String get email => correo;

  String get nombreCompleto => "$nombre ${apellidos ?? ''}".trim();

  String get iniciales {
    if (nombre.isEmpty) return "";
    final String inicialNombre = nombre[0];
    final String inicialApellido = (apellidos != null && apellidos!.isNotEmpty) ? apellidos![0] : "";
    return "$inicialNombre$inicialApellido".toUpperCase();
  }
}