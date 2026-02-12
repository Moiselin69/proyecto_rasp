import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // URL por defecto (se sobrescribe al cargar configuración)
  static String baseUrl = "https://192.168.1.6:8000";
  
  // Claves para almacenamiento
  final _storage = const FlutterSecureStorage();
  static const String _keyBorrarAlSubir = 'borrar_recurso_al_subir';
  static const String _keyApiUrl = 'api_base_url';
  static const String _keyAuthToken = 'auth_token'; // Para compatibilidad con SharedPreferences si fuera necesario

  // ==========================================
  //  CONFIGURACIÓN DE CONEXIÓN (URL)
  // ==========================================

  static Future<void> cargarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final urlGuardada = prefs.getString(_keyApiUrl);
    if (urlGuardada != null && urlGuardada.isNotEmpty) {
      baseUrl = urlGuardada;
      print("URL Base cargada: $baseUrl");
    }
  }

  static Future<void> guardarUrl(String nuevaUrl) async {
    // Limpieza de URL (quitar espacios y barra final)
    String urlFinal = nuevaUrl.trim();
    if (urlFinal.endsWith("/")) {
      urlFinal = urlFinal.substring(0, urlFinal.length - 1);
    }
    
    // Guardar en memoria estática
    baseUrl = urlFinal;
    
    // Persistir en disco
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiUrl, urlFinal);
    print("Nueva URL guardada: $baseUrl");
  }

  // ==========================================
  //  GESTIÓN DE SESIÓN (Token y Credenciales)
  // ==========================================

  Future<void> guardarSesion(String email, String password, String token) async {
    // Guardamos en SecureStorage (más seguro para credenciales)
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

  // Método estático para obtener el token rápidamente (usado en headers de imágenes, etc.)
  static Future<String?> getToken() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');
    
    // Fallback a SharedPreferences si no está en SecureStorage (por compatibilidad antigua)
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_keyAuthToken);
    }
    return token;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Limpiamos todo
    await prefs.remove(_keyAuthToken);
    await _storage.deleteAll();
  }

  // ==========================================
  //  PREFERENCIAS DE USUARIO
  // ==========================================

  static Future<bool> getBorrarAlSubir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBorrarAlSubir) ?? false;
  }

  static Future<void> setBorrarAlSubir(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBorrarAlSubir, value);
  }
}