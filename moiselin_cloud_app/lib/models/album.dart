class Album {
  final int id;
  final String nombre;
  final String descripcion;
  final DateTime fechaCreacion;
  final int? idAlbumPadre;
  final String rol; // "CREADOR", "ADMINISTRADOR", "COLABORADOR"
  final DateTime? fechaEliminacion;

  Album({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaCreacion,
    this.idAlbumPadre,
    required this.rol,
    this.fechaEliminacion
    
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      nombre: json['nombre'] ?? 'Sin nombre',
      descripcion: json['descripcion'] ?? '',
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      idAlbumPadre: json['id_album_padre'], 
      rol: json['rol'] ?? 'COLABORADOR',
      fechaEliminacion: json['fecha_eliminacion'] != null 
          ? DateTime.parse(json['fecha_eliminacion']) 
          : null
    );
  }

  bool get soyCreador => rol == 'CREADOR';
  bool get soyAdmin => rol == 'ADMINISTRADOR' || rol == 'CREADOR';
  bool get estaEnPapelera => fechaEliminacion != null;
}