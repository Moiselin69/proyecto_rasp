class Recurso {
  final int id;
  final int idCreador;
  final String tipo;
  final String nombre;
  final DateTime? fechaReal;
  final DateTime fechaSubida;
  final String urlVisualizacion;
  final String urlThumbnail;
  final int? idAlbum;
  final String? nombreEmisor;
  final String? apellidosEmisor;
  final DateTime? fechaCompartido;

  Recurso({
    required this.id,
    required this.idCreador,
    required this.tipo,
    required this.nombre,
    this.fechaReal,
    required this.fechaSubida,
    required this.urlVisualizacion,
    required this.urlThumbnail,
    this.idAlbum,
    this.nombreEmisor,
    this.apellidosEmisor,
    this.fechaCompartido,
  });

  factory Recurso.fromJson(Map<String, dynamic> json) {
    String rawUrl = json['url_visualizacion'] ?? json['enlace'] ?? '';
    String urlLimpia = rawUrl.replaceAll('\\', '/');
    if (urlLimpia.isEmpty && json['id'] != null) {
      urlLimpia = "/recurso/obtener/${json['id']}";
    }

    if (urlLimpia.isNotEmpty && !urlLimpia.startsWith('/') && !urlLimpia.startsWith('http')) {
      urlLimpia = '/$urlLimpia';
    }

    String thumb = json['url_thumbnail'] ?? urlLimpia;
    thumb = thumb.replaceAll('\\', '/');
    if (thumb.isNotEmpty && !thumb.startsWith('/') && !thumb.startsWith('http')) {
      thumb = '/$thumb';
    }

    return Recurso(
      id: json['id'],
      idCreador: json['id_creador'] ?? 0, 
      tipo: json['tipo'],
      nombre: json['nombre'] ?? 'Sin nombre',
      fechaReal: json['fecha_real'] != null 
          ? DateTime.tryParse(json['fecha_real'].toString()) 
          : null,
      fechaSubida: json['fecha_subida'] != null 
          ? DateTime.parse(json['fecha_subida'].toString()) 
          : DateTime.now(),
      urlVisualizacion: urlLimpia,
      urlThumbnail: thumb,
      idAlbum: json['id_album'],
      nombreEmisor: json['nombre_emisor'],
      apellidosEmisor: json['apellidos_emisor'],
      fechaCompartido: json['fecha_compartido'] != null
          ? DateTime.tryParse(json['fecha_compartido'].toString())
          : null,
    );
  }

  bool get esImagen => tipo == 'IMAGEN';
  bool get esVideo => tipo == 'VIDEO';
  
  String getUrlCompleta(String baseUrl, {bool usarThumbnail = false}) {
    final ruta = usarThumbnail ? urlThumbnail : urlVisualizacion;
    if (ruta.startsWith("http")) return ruta;
    return "$baseUrl$ruta";
  }
}