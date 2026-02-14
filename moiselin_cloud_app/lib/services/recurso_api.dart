import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/recursos.dart';
import '../models/metadatos.dart';
import '../services/api_service.dart';

class RecursoApiService {
  final String baseUrl = ApiService.baseUrl;
  final _storage = const FlutterSecureStorage();

  // Helper para obtener cabeceras con token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==========================================
  //  OBTENCIÓN DE DATOS
  // ==========================================

  // Endpoint 1: Obtener mis recursos
  Future<List<Recurso>> obtenerMisRecursos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/recurso/mis_recursos'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recurso.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar recursos: ${response.body}');
    }
  }

  // Endpoint 2: Obtener metadatos de un recurso
  Future<MetadatosFoto?> obtenerMetadatos(int idRecurso) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recurso/metadatos/$idRecurso'),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Si devuelve un objeto vacío {}, retornamos null
        if (data is Map && data.isEmpty) return null;
        return MetadatosFoto.fromJson(data);
      }
      return null;
    } catch (e) {
      print("Error obteniendo metadatos: $e");
      return null;
    }
  }

  // ==========================================
  //  COMPARTIR Y SOCIAL
  // ==========================================

  // Endpoint 3: Compartir recurso con un amigo
  Future<bool> compartirRecurso(int idRecurso, int idAmigo) async {
    final token = await ApiService.getToken();
    if (token == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recurso/compartir'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id_recurso': idRecurso,
          'id_amigo_receptor': idAmigo,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Error compartir interno: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error sharing internal: $e");
      return false;
    }
  }

  // Endpoint 4: Ver recursos compartidos conmigo
  Future<List<Recurso>> verCompartidosConmigo() async {
    final response = await http.get(
      Uri.parse('$baseUrl/recurso/compartidos-conmigo'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      try {
        return data.map((json) => Recurso.fromJson(json)).toList();
      } catch (e) {
        print("Error parseando recursos compartidos: $e");
        return [];
      }
    } else {
      throw Exception('Error al cargar compartidos: ${response.body}');
    }
  }

  // Endpoint 5: Ver peticiones de recursos pendientes (Alguien quiere compartir conmigo y no somos amigos)
  Future<List<dynamic>> verPeticionesRecepcion() async {
    final response = await http.get(
      Uri.parse('$baseUrl/recurso/peticiones-recepcion'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error obteniendo peticiones: ${response.body}');
    }
  }

  // Endpoint 6: Responder a petición de recepción
  Future<Map<String, dynamic>> responderPeticionRecurso(int idEmisor, int idRecurso, bool aceptar) async {
    final uri = Uri.parse('$baseUrl/recurso/peticiones-recepcion/responder');
    try {
      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'id_emisor': idEmisor,
          'id_recurso': idRecurso,
          'aceptar': aceptar
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al responder'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // Endpoint (Enlaces): Crear enlace público
  Future<String?> crearEnlacePublico(List<int> recursosIds, List<int> albumesIds, String? password, int? diasExpiracion) async {
    final uri = Uri.parse('$baseUrl/share/crear');
    try {
      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'ids_recursos': recursosIds,
          'ids_albumes': albumesIds,
          'password': password,
          'dias_expiracion': diasExpiracion
        })
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Construimos la URL completa para mostrarla
        String pathUrl = data['url']; // Ej: /s/TOKEN
        String host = baseUrl.replaceAll("/api", ""); // Ajuste simple para quitar sufijos si existen
        // Si tu baseUrl es http://ip:8000, host será igual.
        if (host.endsWith("/")) host = host.substring(0, host.length - 1);
        
        return "$host$pathUrl";
      }
      return null;
    } catch (e) {
      print("Error creando enlace: $e");
      return null;
    }
  }

  Future<bool> dejarRecursoCompartido(int idRecurso) async {
    final uri = Uri.parse('$baseUrl/recurso/compartidos/salir/$idRecurso');
    try {
      final response = await http.delete(uri, headers: await _getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      print("Error al salir del recurso: $e");
      return false;
    }
  }

  // ==========================================
  //  EDICIÓN DE METADATOS
  // ==========================================

  // Endpoint 7: Editar nombre
  Future<int> editarNombre(int idRecurso, String nuevoNombre, {bool reemplazar = false}) async {
    final uri = Uri.parse('$baseUrl/recurso/editar/nombre/$idRecurso');
    try {
      final response = await http.put(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          "nombre": nuevoNombre,
          "reemplazar": reemplazar
        }),
      );
      if (response.statusCode == 200) return 200;
      if (response.statusCode == 409) return 409; // Conflicto de nombre
      return response.statusCode;
    } catch (e) {
      return 500;
    }
  }

  // Endpoint 8: Editar fecha
  Future<bool> editarFecha(int idRecurso, DateTime nuevaFecha) async {
    final uri = Uri.parse('$baseUrl/recurso/editar/fecha/$idRecurso');
    try {
      final response = await http.put(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({"fecha": nuevaFecha.toIso8601String()}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Endpoint 9: Marcar favorito
  Future<bool> toggleFavorito(int idRecurso, bool estado) async {
    final uri = Uri.parse('$baseUrl/recurso/favorito');
    try {
      final response = await http.put(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({
          'id_recurso': idRecurso,
          'es_favorito': estado,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  //  GESTIÓN DE ARCHIVOS (PAPELERA Y MOVER)
  // ==========================================

  // Endpoint 10: Enviar a papelera
  Future<bool> borrarRecurso(int idRecurso) async {
    final uri = Uri.parse('$baseUrl/recurso/borrar/$idRecurso');
    final response = await http.delete(uri, headers: await _getHeaders());
    return response.statusCode == 200;
  }

  // Endpoint 11: Ver papelera
  Future<List<Recurso>> obtenerPapelera() async {
    final uri = Uri.parse('$baseUrl/recurso/papelera');
    final response = await http.get(uri, headers: await _getHeaders());
    
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recurso.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar la papelera');
    }
  }

  // Endpoint 12: Restaurar de papelera
  Future<bool> restaurarRecurso(int idRecurso) async {
    final uri = Uri.parse('$baseUrl/recurso/restaurar/$idRecurso');
    final response = await http.put(uri, headers: await _getHeaders());
    return response.statusCode == 200;
  }

  // Endpoint 13: Borrar lote (Papelera)
  Future<Map<String, dynamic>> borrarLote(List<int> ids) async {
    final uri = Uri.parse('$baseUrl/recurso/lote/papelera');
    
    try {
      final response = await http.put(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode({'ids': ids})
      );

      // Decodificamos la respuesta (sea éxito o error)
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'exito': true, 
          'mensaje': data['mensaje'] ?? 'Elementos movidos a la papelera'
        };
      } else {
        // Aquí capturamos el 'detail' que manda Python (ej: "No tienes permisos...")
        return {
          'exito': false, 
          'mensaje': data['detail'] ?? 'Error desconocido al borrar'
        };
      }
    } catch (e) {
      return {
        'exito': false, 
        'mensaje': 'Error de conexión: $e'
      };
    }
  }

  // Endpoint 14: Mover lote a álbum
  Future<bool> moverLote(List<int> ids, int? idAlbumDestino) async {
    final uri = Uri.parse('$baseUrl/recurso/lote/mover');
    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({
        'ids': ids,
        'id_album_destino': idAlbumDestino
      })
    );
    return response.statusCode == 200;
  }

  // Endpoint 18: Eliminar definitivamente
  Future<bool> eliminarDefinitivo(int idRecurso) async {
    final uri = Uri.parse('$baseUrl/recurso/eliminar-definitivo/$idRecurso');
    final response = await http.delete(uri, headers: await _getHeaders());
    return response.statusCode == 200;
  }

  // ==========================================
  //  SUBIDA DE ARCHIVOS (CHUNKS)
  // ==========================================

  // Endpoints 15, 16, 17: Proceso de subida
  Future<String?> subirPorChunks(
    File archivo, 
    String tipo, 
    {
      int? idAlbum, 
      bool reemplazar = false,
      Function(double)? onProgress,
    }
  ) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return "No hay sesión activa";

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
        try {
            return jsonDecode(respStr)['detail'];
        } catch (_) {
            return "Error al completar subida: ${respComplete.statusCode}";
        }
      }

    } catch (e) {
      return "Excepción: $e";
    }
  }

  Future<int> subirListaDeRecursos(List<File> archivos, int? idAlbumDestino, {Function(int, int)? onProgressGeneral}) async {
    int subidos = 0;
    int simultaneos = 5; // Lote de 3 archivos simultáneos

    // Iteramos de 3 en 3
    for (var i = 0; i < archivos.length; i += simultaneos) {
      // Calcular fin del lote
      var fin = (i + simultaneos < archivos.length) ? i + simultaneos : archivos.length;
      var lote = archivos.sublist(i, fin);
      List<String?> resultados = await Future.wait(
        lote.map((archivo) => subirPorChunks(
          archivo, 
          _determinarTipo(archivo),
          idAlbum: idAlbumDestino,
        ))
      );
      for (var res in resultados) {
        if (res != null && !res.startsWith("Error") && !res.startsWith("Excepción") && !res.startsWith("DUPLICADO")) {
          subidos++;
        }
      }
      if (onProgressGeneral != null) {
        onProgressGeneral(fin, archivos.length);
      }
    }
    return subidos;
  }

  // Helper privado para detectar tipo de archivo por extensión
  String _determinarTipo(File archivo) {
    String extension = path.extension(archivo.path).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(extension)) {
      return 'IMAGEN';
    } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) {
      return 'VIDEO';
    } else if (['.mp3', '.wav', '.m4a'].contains(extension)) {
      return 'AUDIO';
    }
    return 'ARCHIVO';
  }
}