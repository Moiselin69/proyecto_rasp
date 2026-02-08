import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import "../models/recursos.dart";
import 'dart:io';
import "../models/album.dart";
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;

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

  Future<bool> subirRecurso(String token, File archivo, String tipo, {int? idAlbum, bool reemplazar = false}) async {
    var uri = Uri.parse('$baseUrl/recurso/subir');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['tipo'] = tipo; 
    request.fields['reemplazar'] = reemplazar.toString(); // <--- NUEVO CAMPO
    if (idAlbum != null) {
      request.fields['id_album'] = idAlbum.toString();
    }
    var fileStream = await http.MultipartFile.fromPath('file', archivo.path);
    request.files.add(fileStream);
    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 409) {
        print("Conflicto: El archivo ya existe y no se ordenó reemplazar");
        return false;
      } else {
        final respStr = await response.stream.bytesToString();
        print("Error subida (${response.statusCode}): $respStr");
        return false;
      }
    } catch (e) {
      print("Error subiendo archivo: $e");
      return false;
    }
  }

  // Función para editar nombre
  Future<int> editarNombre(String token, int idRecurso, String nuevoNombre, {bool reemplazar = false}) async {
    final url = Uri.parse('$baseUrl/recurso/editar/nombre/$idRecurso');
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "nombre": nuevoNombre,
          "reemplazar": reemplazar
        }),
      );
      if (response.statusCode == 200) return 200; // Éxito
      if (response.statusCode == 409) return 409; // Duplicado
      return response.statusCode; // Otro error
    } catch (e) {
      print("Error conexión editar nombre: $e");
      return 500;
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

  Future<bool> verificarDuplicado(String token, String nombreArchivo, int? idAlbum) async {
    String query = "?nombre=$nombreArchivo";
    if (idAlbum != null) {
      query += "&id_album=$idAlbum";
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl/recurso/verificar-duplicado$query'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['existe'] == true;
    }
    return false; // Si falla, asumimos false para intentar subir y que el backend decida
  }

  Future<bool> soyAdmin(String token) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/admin/soy-admin'), headers: {'Authorization': 'Bearer $token'});
      return r.statusCode == 200 && jsonDecode(r.body)['es_admin'] == true;
    } catch (e) { return false; }
  }

  Future<Map<String, dynamic>> getUsuariosAdmin(String token) async {
    final r = await http.get(Uri.parse('$baseUrl/admin/usuarios'), headers: {'Authorization': 'Bearer $token'});
    if (r.statusCode == 200) {
      return jsonDecode(r.body);
    }
    throw Exception(r.body);
  }

  Future<String?> cambiarCuota(String token, int idUsuario, int? bytes) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/cambiar-cuota'),
        headers: {
          'Authorization': 'Bearer $token', 
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'id_usuario': idUsuario, 'nueva_cuota_bytes': bytes})
      );

      if (response.statusCode == 200) {
        return null; // NULL significa ÉXITO (Sin error)
      } else {
        try {
          final body = jsonDecode(response.body);
          return body['detail'] ?? "Error desconocido al cambiar la cuota";
        } catch (_) {
          return "Error ${response.statusCode}: ${response.body}";
        }
      }
    } catch (e) {
      return "Error de conexión: $e";
    }
  }

  Future<String?> subirPorChunks(
    String token, 
    File archivo, 
    String tipo, 
    {
      int? idAlbum, 
      bool reemplazar = false,
      Function(double)? onProgress, // <--- NUEVO PARÁMETRO
    }
  ) async {
    try {
      int totalSize = await archivo.length();
      String fileName = path.basename(archivo.path);
      
      // 1. INIT
      final respInit = await http.post(
        Uri.parse('$baseUrl/upload/init'),
        headers: {'Authorization': 'Bearer $token'}
      );
      if (respInit.statusCode != 200) return "Error iniciando subida";
      String uploadId = jsonDecode(respInit.body)['upload_id'];

      // 2. CHUNKS
      int chunkSize = 1 * 1024 * 1024; // 1MB
      int totalChunks = (totalSize / chunkSize).ceil();
      
      var accessFile = await archivo.open();
      
      for (int i = 0; i < totalChunks; i++) {
        int start = i * chunkSize;
        int end = start + chunkSize;
        if (end > totalSize) end = totalSize;
        
        int length = end - start;
        List<int> buffer = List<int>.filled(length, 0);
        await accessFile.setPosition(start);
        await accessFile.readInto(buffer);

        var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/chunk'));
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['upload_id'] = uploadId;
        request.fields['chunk_index'] = i.toString();
        
        request.files.add(http.MultipartFile.fromBytes('file', buffer, filename: 'chunk_$i'));

        var respChunk = await request.send();
        if (respChunk.statusCode != 200) {
          await accessFile.close();
          return "Error subiendo parte ${i+1}";
        }
        
        // --- NOTIFICAR PROGRESO ---
        if (onProgress != null) {
          double porcentaje = (i + 1) / totalChunks;
          onProgress(porcentaje);
        }
        // --------------------------
      }
      
      await accessFile.close();

      // 3. COMPLETE
      var reqComplete = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/complete'));
      reqComplete.headers['Authorization'] = 'Bearer $token';
      reqComplete.fields['upload_id'] = uploadId;
      reqComplete.fields['nombre_archivo'] = fileName;
      reqComplete.fields['total_chunks'] = totalChunks.toString();
      reqComplete.fields['tipo'] = tipo;
      reqComplete.fields['reemplazar'] = reemplazar.toString();
      if (idAlbum != null) reqComplete.fields['id_album'] = idAlbum.toString();

      var respComplete = await reqComplete.send();
      final respStr = await respComplete.stream.bytesToString();

      if (respComplete.statusCode == 200) {
        return jsonDecode(respStr)['mensaje']; // Éxito
      } else if (respComplete.statusCode == 409) {
        return "DUPLICADO"; 
      } else {
        // Intentar leer error del backend
        try {
            return jsonDecode(respStr)['detail'];
        } catch (_) {
            return "Error al completar subida";
        }
      }

    } catch (e) {
      return "Excepción: $e";
    }
  }

}