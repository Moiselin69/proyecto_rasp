class MetadatosFoto {
  final String? dispositivo;
  final int? iso;
  final String? apertura;
  final String? velocidad;
  final double? latitud;
  final double? longitud;
  final int? ancho;
  final int? alto;

  MetadatosFoto({this.dispositivo, this.iso, this.apertura, this.velocidad, this.latitud, this.longitud, this.ancho, this.alto});

  factory MetadatosFoto.fromJson(Map<String, dynamic> json) {
    return MetadatosFoto(
      dispositivo: json['dispositivo'],
      iso: json['iso'],
      apertura: json['apertura'],
      velocidad: json['velocidad'],
      latitud: json['latitud'] != null ? double.parse(json['latitud'].toString()) : null,
      longitud: json['longitud'] != null ? double.parse(json['longitud'].toString()) : null,
      ancho: json['ancho'],
      alto: json['alto'],
    );
  }
}