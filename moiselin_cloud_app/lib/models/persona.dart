class Persona {
  final int id;
  final String nombre;
  final String apellidos;
  final String correo;

  Persona({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.correo,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      apellidos: json['apellidos'] ?? '', 
      correo: json['correo_electronico'] ?? '',
    );
  }

  String get nombreCompleto => "$nombre $apellidos".trim();

  String get iniciales {
    if (nombre.isEmpty) return "";
    final String inicialNombre = nombre[0];
    final String inicialApellido = apellidos.isNotEmpty ? apellidos[0] : "";
    return "$inicialNombre$inicialApellido".toUpperCase();
  }
}