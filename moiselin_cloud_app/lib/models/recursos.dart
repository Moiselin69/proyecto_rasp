class Recurso {
  final int id;
  final String tipo; // "IMAGEN", "VIDEO", "AUDIO", "ARCHIVO"
  final String nombre;
  final DateTime? fechaReal; // Puede ser null
  final DateTime fechaSubida;
  final String urlVisualizacion; // Ruta relativa: /recurso/archivo/5
  final String urlThumbnail;     // Ruta relativa: /recurso/archivo/5?size=small

  Recurso({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.fechaReal,
    required this.fechaSubida,
    required this.urlVisualizacion,
    required this.urlThumbnail,
  });

  factory Recurso.fromJson(Map<String, dynamic> json) {
    return Recurso(
      id: json['id'],
      tipo: json['tipo'],
      nombre: json['nombre'] ?? 'Sin nombre',
      fechaReal: json['fecha_real'] != null ? DateTime.parse(json['fecha_real']) : null,
      fechaSubida: DateTime.parse(json['fecha_subida']),
      urlVisualizacion: json['url_visualizacion'],
      urlThumbnail: json['url_thumbnail'],
    );
  }
  bool get esImagen => tipo == 'IMAGEN';
  bool get esVideo => tipo == 'VIDEO';
  String getUrlCompleta(String baseUrl, {bool usarThumbnail = false}) {
    final ruta = usarThumbnail ? urlThumbnail : urlVisualizacion;
    return "$baseUrl$ruta";
  }
}