import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import "../models/recursos.dart";

class ApiService {
  static const String baseUrl = "http://192.168.1.6:8000"; 

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
    final url = Uri.parse('$baseUrl/recurso/mis_recursos');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // ¡Pasamos el token!
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Recurso.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar recursos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}