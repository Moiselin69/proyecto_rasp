class Album {
  final int id;
  final String nombre;
  final String descripcion;
  final DateTime fechaCreacion;
  final int? idAlbumPadre;
  final String rol; // "CREADOR", "ADMINISTRADOR", "COLABORADOR"

  Album({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaCreacion,
    this.idAlbumPadre,
    required this.rol,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      nombre: json['nombre'] ?? 'Sin nombre',
      descripcion: json['descripcion'] ?? '',
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      idAlbumPadre: json['id_album_padre'], 
      rol: json['rol'] ?? 'COLABORADOR',
    );
  }

  bool get soyCreador => rol == 'CREADOR';
  bool get soyAdmin => rol == 'ADMINISTRADOR' || rol == 'CREADOR';
}