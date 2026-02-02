class Album {
  final int id;
  final String nombre;
  final String descripcion;
  final DateTime fechaCreacion;
  final String rol; // "CREADOR", "ADMINISTRADOR", "COLABORADOR"

  Album({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaCreacion,
    required this.rol,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      nombre: json['nombre'] ?? 'Sin nombre',
      descripcion: json['descripcion'] ?? '',
      // El backend devuelve fecha_creacion (snake_case)
      fechaCreacion: DateTime.parse(json['fecha_creacion']), 
      rol: json['rol'] ?? 'COLABORADOR',
    );
  }

  bool get soyCreador => rol == 'CREADOR';
  bool get soyAdmin => rol == 'ADMINISTRADOR' || rol == 'CREADOR';
}