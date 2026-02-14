import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import "../services/api_service.dart";
import '../models/persona.dart';

class PersonaApiService {
  String get baseUrl => ApiService.baseUrl;
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
  //  REGISTRO Y LOGIN
  // ==========================================

  // Endpoint 2: Registro de usuario
  Future<Map<String, dynamic>> registrarUsuario(
      String nombre, 
      String apellidos, 
      String nickname, 
      String correo, 
      String contra, 
      String fechaNacimiento // Formato esperado: YYYY-MM-DD o string compatible
  ) async {
    final uri = Uri.parse('$baseUrl/persona/registro');
    
    final body = {
      "nombre": nombre,
      "apellidos": apellidos,
      "nickname": nickname,
      "correo": correo,
      "contra": contra,
      "fecha_nacimiento": fechaNacimiento
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {'exito': true, 'id': data['id'], 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error en el registro'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }

  // Endpoint 3: Login (Ya lo tenías, mantenemos lógica)
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/persona/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': email,
          'contra': password 
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Guardar token en storage seguro automáticamente si lo deseas, 
        // o dejar que el controlador lo haga (como en ApiService)
        return data['access_token']; 
      } else {
        print("Error Login: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error en login: $e");
      return null;
    }
  }

  // ==========================================
  //  AMISTADES Y BÚSQUEDA
  // ==========================================

  // Endpoint 4: Búsqueda de personas
  Future<List<dynamic>> buscarPersonas(String termino) async {
    final url = Uri.parse('$baseUrl/persona/buscar?termino=$termino');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al buscar personas: ${response.body}');
    }
  }

  // Endpoint 5: Ver amistades y solicitudes pendientes
  Future<List<dynamic>> obtenerAmistades() async {
    final url = Uri.parse('$baseUrl/persona/amistades');
    final response = await http.get(
      url,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      // Devuelve una lista mezclada de amigos (estado='AMIGO') y solicitudes (estado='SOLICITUD_RECIBIDA')
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar amistades: ${response.body}');
    }
  }

  // Endpoint 6: Solicitar amistad
  Future<Map<String, dynamic>> solicitarAmistad(int idPersonaObjetivo) async {
    final url = Uri.parse('$baseUrl/persona/amistad/solicitar');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({"id_persona_objetivo": idPersonaObjetivo}),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al solicitar amistad'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // Endpoint 7: Responder amistad (ACEPTAR, RECHAZAR, ELIMINAR)
  Future<Map<String, dynamic>> responderAmistad(int idOtroUsuario, String accion) async {
    // accion debe ser: 'ACEPTAR', 'RECHAZAR' o 'ELIMINAR'
    final url = Uri.parse('$baseUrl/persona/amistad/responder');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "id_otro_usuario": idOtroUsuario,
          "accion": accion
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al responder solicitud'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // ==========================================
  //  ALMACENAMIENTO (USUARIO)
  // ==========================================

  // Endpoint 11: Ver almacenamiento del usuario actual
  Future<Map<String, dynamic>> obtenerMiAlmacenamiento() async {
    final url = Uri.parse('$baseUrl/persona/almacenamiento');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      // Devuelve JSON: { "maximo": int/null, "usado": float }
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener datos de almacenamiento: ${response.body}');
    }
  }

  // ==========================================
  //  ADMINISTRACIÓN
  // ==========================================

  // Endpoint 8 / 1: Verificar si soy admin
  Future<bool> soyAdmin() async {
    try {
      final url = Uri.parse('$baseUrl/admin/soy-admin');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['es_admin'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Endpoint 9: Listar usuarios y su uso de disco (Solo Admin)
  Future<Map<String, dynamic>> obtenerUsuariosAdmin() async {
    final url = Uri.parse('$baseUrl/admin/usuarios');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      // Retorna: { "usuarios": [...], "disco": { "total":..., "usado":..., "libre":... } }
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener lista de usuarios: ${response.body}');
    }
  }

  // Endpoint 10: Cambiar cuota de usuario (Solo Admin)
  Future<Map<String, dynamic>> cambiarCuotaUsuario(int idUsuario, int nuevaCuotaBytes) async {
    final url = Uri.parse('$baseUrl/admin/cambiar-cuota');
    try {
      final response = await http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "id_usuario": idUsuario,
          "nueva_cuota_bytes": nuevaCuotaBytes
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      } else {
        return {'exito': false, 'mensaje': data['detail'] ?? 'Error al cambiar cuota'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  // Endpoint específico para el Selector de Amigos
  Future<List<Persona>> obtenerAmigosConfirmados(String token) async {
    final url = Uri.parse('$baseUrl/persona/amistades');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        
        // 1. Filtramos solo los amigos confirmados (quitamos solicitudes)
        var amigosJson = data.where((item) => item['estado'] == 'AMIGO');

        // 2. Convertimos a lista de objetos Persona
        // Asegúrate de que tu modelo Persona tenga el factory .fromJson
        return amigosJson.map((json) => Persona.fromJson(json)).toList();
      } else {
        print("Error obteniendo amigos: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Excepción buscando amigos: $e");
      return [];
    }
  }
}