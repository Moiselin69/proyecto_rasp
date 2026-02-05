import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import "../models/recursos.dart";
import 'dart:io';
import "../models/album.dart";

class ApiService {
  static const String baseUrl = "https://192.168.1.6:8000"; 

  Future<bool> login(String correo, String contra) async {
    final url = Uri.parse('$baseUrl/persona/login');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "correo": correo,
          "contra": contra,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['access_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        
        return true; 
      } else {
        print("Error login: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error de conexión: $e");
      return false;
    }
  }

  // Función para obtener el token guardado (útil para la Galería)
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Función para cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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
  
}