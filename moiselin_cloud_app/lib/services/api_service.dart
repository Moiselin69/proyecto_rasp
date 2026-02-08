import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import "../models/recursos.dart";
import 'dart:io';
import "../models/album.dart";
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static String baseUrl = "http://192.168.1.6:8000";
  final _storage = const FlutterSecureStorage();
  static const String _keyBorrarAlSubir = 'borrar_recurso_al_subir';

  static Future<void> cargarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final urlGuardada = prefs.getString('api_base_url');
    if (urlGuardada != null && urlGuardada.isNotEmpty) {
      baseUrl = urlGuardada;
      print("URL Base cargada: $baseUrl");
    }
  }

  static Future<void> guardarUrl(String nuevaUrl) async {
    // Pequeña limpieza por si al usuario se le olvida el http o la barra final
    String urlFinal = nuevaUrl.trim();
    if (urlFinal.endsWith("/")) {
      urlFinal = urlFinal.substring(0, urlFinal.length - 1);
    }
    
    // Guardamos en memoria
    baseUrl = urlFinal;
    
    // Persistimos en disco
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', urlFinal);
    print("Nueva URL guardada: $baseUrl");
  }

  Future<void> guardarSesion(String email, String password, String token) async {
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'password', value: password);
    await _storage.write(key: 'token', value: token);
  }

  Future<Map<String, String?>> obtenerSesion() async {
    String? email = await _storage.read(key: 'email');
    String? password = await _storage.read(key: 'password');
    String? token = await _storage.read(key: 'token');
    return {'email': email, 'password': password, 'token': token};
  }


  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/persona/login'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': email,
          'contra': password 
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token']; 
      } else {
        print("Error Login: ${response.body}"); // Para ver qué falla si no entra
        return null;
      }
    } catch (e) {
      print("Error en login: $e");
      return null;
    }
  }

  // Función para obtener el token guardado (útil para la Galería)
  static Future<String?> getToken() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');
    if (token != null) return token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Función para cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await _storage.deleteAll();
  }

 Future<List<Recurso>> obtenerMisRecursos(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/recurso/mis_recursos'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recurso.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar recursos');
    }
  }
  Future<bool> subirRecurso(String token, File archivo, String tipo, {int? idAlbum}) async {
    var uri = Uri.parse('$baseUrl/recurso/subir');
    var request = http.MultipartRequest('POST', uri);
    
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['tipo'] = tipo; 
    
    if (idAlbum != null) {
      request.fields['id_album'] = idAlbum.toString();
    }
    
    var fileStream = await http.MultipartFile.fromPath('file', archivo.path);
    request.files.add(fileStream);

    try {
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print("Error subiendo archivo: $e");
      return false;
    }
  }

  // Función para editar nombre
  Future<bool> editarNombre(String token, int idRecurso, String nuevoNombre) async {
    final url = Uri.parse('$baseUrl/recurso/editar/nombre/$idRecurso');
    
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"nombre": nuevoNombre}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        // Si da 400, imprimimos por qué para verlo en consola
        print("Error del servidor (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error de conexión al editar nombre: $e");
      return false;
    }
  }

  // Función para editar fecha
  Future<bool> editarFecha(String token, int idRecurso, DateTime nuevaFecha) async {
    final url = Uri.parse('$baseUrl/recurso/editar/fecha/$idRecurso');
    
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        // Enviamos formato ISO 8601
        body: jsonEncode({"fecha": nuevaFecha.toIso8601String()}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Error fecha (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error conexión fecha: $e");
      return false;
    }
  }

  Future<List<Album>> obtenerMisAlbumes(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/album/mis_albumes'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Album.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar álbumes');
    }
  }

  Future<bool> crearAlbum(String token, String nombre, String descripcion, int? parentId) async {
    final uri = Uri.parse('$baseUrl/album/crear');
    
    Map<String, dynamic> body = {
      "nombre": nombre,
      "descripcion": descripcion,
    };

    // IMPORTANTE: Si hay un padre, lo añadimos al JSON
    if (parentId != null) {
      body["id_album_padre"] = parentId;
    }

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print("Error creando álbum: $e");
      return false;
    }
  }
  
  Future<bool> borrarRecurso(String token, int idRecurso) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/recurso/borrar/$idRecurso'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  Future<bool> moverRecurso(String token, int idRecurso, int? idAlbumOrigen, int? idAlbumDestino) async {
    final response = await http.put(
      Uri.parse('$baseUrl/album/mover-recurso'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "id_recurso": idRecurso,
        "id_album_origen": idAlbumOrigen,
        "id_album_destino": idAlbumDestino,
      }),
    );
    return response.statusCode == 200;
  }

  Future<bool> borrarAlbum(String token, int idAlbum) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/album/borrar/$idAlbum'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  // Mover Álbum (Necesario si quieres mover carpetas también)
  Future<bool> moverAlbum(String token, int idAlbum, int? idNuevoPadre) async {
    final response = await http.put(
      Uri.parse('$baseUrl/album/mover'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "id_album": idAlbum,
        "id_nuevo_padre": idNuevoPadre ?? 0 // Tu backend puede requerir 0 o manejar null, ajústalo según tu SP
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, String>> _getHeaders() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> buscarPersonas(String termino) async {
    final url = Uri.parse('$baseUrl/persona/buscar?termino=$termino');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      // El backend devuelve una lista de objetos JSON
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al buscar personas: ${response.body}');
    }
  }

  // Enviar solicitud de amistad
  static Future<void> solicitarAmistad(int idPersonaObjetivo) async {
    final url = Uri.parse('$baseUrl/amigos/solicitar');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'id_persona_objetivo': idPersonaObjetivo}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al enviar solicitud: ${response.body}');
    }
  }

  static Future<List<dynamic>> verPeticionesPendientes() async {
    final url = Uri.parse('$baseUrl/amigos/pendientes');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // Si no hay peticiones o error, devolvemos lista vacía para no romper la UI
      return []; 
    }
  }

  static Future<void> aceptarAmistad(int idPersonaQueEnvio) async {
    final url = Uri.parse('$baseUrl/amigos/aceptar');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'id_persona_objetivo': idPersonaQueEnvio}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al aceptar: ${response.body}');
    }
  }

  static Future<void> rechazarAmistad(int idPersonaQueEnvio) async {
    final url = Uri.parse('$baseUrl/amigos/rechazar');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'id_persona_objetivo': idPersonaQueEnvio}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al rechazar: ${response.body}');
    }
  }

  static Future<List<dynamic>> verAmigos() async {
    final url = Uri.parse('$baseUrl/amigos/listar');
    final response = await http.get(url, headers: await _getHeaders());
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar amigos: ${response.body}');
    }
  }

  static Future<void> eliminarAmigo(int idAmigo) async {
    final url = Uri.parse('$baseUrl/amigos/eliminar/$idAmigo');
    final response = await http.delete(url, headers: await _getHeaders());
    
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar amigo: ${response.body}');
    }
  }

  static Future<bool> getBorrarAlSubir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBorrarAlSubir) ?? false;
  }
  static Future<void> setBorrarAlSubir(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBorrarAlSubir, value);
  }

  static Future<String> compartirRecurso(int idRecurso, int idAmigo) async {
    final url = Uri.parse('$baseUrl/recurso/compartir');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'id_recurso': idRecurso,
        'id_amigo_receptor': idAmigo
      }),
    );

    // Decodificamos la respuesta
    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Devolvemos el mensaje de éxito del backend 
      // (Ej: "Recurso compartido exitosamente" o "Solicitud enviada...")
      return body['mensaje']; 
    } else {
      // Manejo de errores mejorado
      String mensajeError = body['detail'] ?? body['message'] ?? 'Error desconocido';
      throw Exception(mensajeError);
    }
  }

  static Future<List<Recurso>> verCompartidosConmigo() async {
    final url = Uri.parse('$baseUrl/recurso/compartidos-conmigo');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      try {
        return data.map((json) => Recurso.fromJson(json)).toList();
      } catch (e) {
        print("Error al convertir JSON a Recurso: $e");
        // Si falla la conversión de uno, falla toda la lista.
        // Verificamos si algún campo viene nulo y el modelo no lo acepta.
        return [];
      }
    } else {
      throw Exception('Error al cargar compartidos: ${response.body}');
    }
  }

  // Ver solicitudes pendientes
  static Future<List<dynamic>> verSolicitudesRecursos() async {
    final url = Uri.parse('$baseUrl/recurso/peticiones-recepcion');
    final response = await http.get(url, headers: await _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  // Responder solicitud
  static Future<void> responderSolicitudRecurso(int idEmisor, int idRecurso, bool aceptar) async {
    final url = Uri.parse('$baseUrl/recurso/peticiones-recepcion/responder');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'id_emisor': idEmisor,
        'id_recurso': idRecurso,
        'aceptar': aceptar
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al responder: ${response.body}');
    }
  }

  Future<List<Recurso>> obtenerPapelera(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/recurso/papelera'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recurso.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar la papelera');
    }
  }

  Future<bool> restaurarRecurso(String token, int idRecurso) async {
    final response = await http.put(
      Uri.parse('$baseUrl/recurso/restaurar/$idRecurso'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  Future<bool> eliminarDefinitivo(String token, int idRecurso) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/recurso/eliminar-definitivo/$idRecurso'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

}