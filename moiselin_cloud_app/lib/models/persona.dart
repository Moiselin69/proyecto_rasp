class Persona{
  final String id;
  final String correoElectronico;
  final String nombre;
  final String apellidos;
  final DateTime fechaCreacionPerfil;
  Persona({
    required this.id,
    required this.correoElectronico,
    required this.nombre,
    required this.apellidos,
    required this.fechaCreacionPerfil
  });
}
class Recurso{
  final String id;
  final String? idCreador;
  final String tipo;
  Recurso({
    required this.id,
    this.idCreador,
    required this.tipo,

  });
}