import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/album.dart'; 
import '../models/recursos.dart'; 
import 'api_service.dart';

class AlbumApiService {
  final String baseUrl = ApiService.baseUrl;
  // Llamada al endpoint 1 de Album 
  Future<Map<String, dynamic>> crearAlbum(String token, String nombre, String descripcion, int? idAlbumPadre) async {
    final uri = Uri.parse('$baseUrl/album/crear');
    Map<String, dynamic> body = {
      "nombre": nombre,
      "descripcion": descripcion,
      "id_album_padre": idAlbumPadre
    };
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'id_album': data['id_album']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error desconocido'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }
  // LLamada al endpoint 2 de Album
  Future<List<Album>> obtenerMisAlbumes(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/album/mis_albumes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Album.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar álbumes: ${response.body}');
    }
  }
  // LLamada al endpoint 3 de Album
  Future<List<Recurso>> verContenidoAlbum(String token, int idAlbum) async {
    final response = await http.get(
      Uri.parse('$baseUrl/album/contenido/$idAlbum'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recurso.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar contenido: ${response.body}');
    }
  }
  // LLamada al endpoint 4 de Album
  Future<Map<String, dynamic>> invitarAAlbum(String token, int idAlbum, int idPersonaInvitada, String rol) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/album/invitar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "id_album": idAlbum,
          "id_persona_invitada": idPersonaInvitada,
          "rol": rol
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al invitar'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }
  // Llamada al endpoint 5 de Album
  Future<bool> anadirRecursoAAlbum(String token, int idRecurso, int idAlbum) async {
    final response = await http.post(
      Uri.parse('$baseUrl/album/anadir-recurso'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "id_album": idAlbum,
        "id_recurso": idRecurso
      }),
    );
    return response.statusCode == 200;
  }
  // Llamada al endpoint 6 de Album
  Future<bool> borrarRecursoDeAlbum(String token, int idAlbum, int idRecurso) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/album/borrar-recurso/$idAlbum/$idRecurso'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }
  // Llamada al endpoint 7 de Album
  Future<bool> salirDeAlbum(String token, int idAlbum) async {
    final response = await http.post(
      Uri.parse('$baseUrl/album/salir/$idAlbum'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }
  // Llamada al endpoint 8 de Album
  Future<List<dynamic>> verInvitacionesAlbum(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/album/invitaciones'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }
  // Llamada al endpoint 9 y 10 de Album
  Future<bool> responderInvitacionAlbum(String token, int idAlbum, int idInvitador, bool aceptar) async {
    final endpoint = aceptar ? "aceptar" : "rechazar";
    final uri = Uri.parse('$baseUrl/album/invitacion/$endpoint');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "id_album": idAlbum,
        "id_persona_invitadora": idInvitador
      }),
    );
    return response.statusCode == 200;
  }
  // Llamada al endpoint 11 de Album
  Future<Map<String, dynamic>> moverAlbum(String token, int idAlbum, int? idNuevoPadre) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/album/mover'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "id_album": idAlbum,
          "id_nuevo_padre": idNuevoPadre
        }),
      );
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': 'Álbum movido correctamente'};
      } else {
        final data = jsonDecode(response.body);
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al mover'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // Llamada al endpoint 12 de Album
  Future<Map<String, dynamic>> moverRecursoAlbum(String token, int idRecurso, int idOrigen, int idDestino) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/album/mover-recurso'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "id_recurso": idRecurso,
          "id_album_origen": idOrigen,
          "id_album_destino": idDestino,
        }),
      );
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': 'Movido correctamente'};
      } else {
        final data = jsonDecode(response.body);
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al mover'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // Llamada al endpoint 13 de Album
  Future<Map<String, dynamic>> borrarAlbum(String token, int idAlbum) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/album/borrar/$idAlbum'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al borrar'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // Llamada al endpoint 14 de Album
  Future<List<dynamic>> verMiembrosAlbum(String token, int idAlbum) async {
    final response = await http.get(
      Uri.parse('$baseUrl/album/miembros/$idAlbum'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al ver miembros');
    }
  }

  // Llamada al endpoint 15 de Album
  Future<bool> cambiarRolMiembro(String token, int idAlbum, int idPersonaObjetivo, String nuevoRol) async {
    final response = await http.put(
      Uri.parse('$baseUrl/album/miembros/rol'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "id_album": idAlbum,
        "id_persona_objetivo": idPersonaObjetivo,
        "nuevo_rol": nuevoRol
      }),
    );
    return response.statusCode == 200;
  }

}