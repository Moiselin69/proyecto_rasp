import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // CAMBIA ESTO POR TU IP LOCAL (Si usas emulador Android usa '10.0.2.2')
  // IMPORTANTE: No uses 'localhost' ni '127.0.0.1'
  static const String baseUrl = 'http://192.168.1.6:8000'; 
  
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final _storage = const FlutterSecureStorage();

  // Método para Login
  Future<String?> login(String correo, String contra) async {
    try {
      final response = await _dio.post('/persona/login', data: {
        'correo': correo,
        'contra': contra,
      });

      if (response.statusCode == 200) {
        // Tu API devuelve { "access_token": "...", "token_type": "bearer" }
        final token = response.data['access_token'];
        
        // Guardamos el token en el móvil de forma segura
        await _storage.write(key: 'jwt_token', value: token);
        return null; // Null significa "Sin errores"
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return e.response?.data['detail'] ?? 'Error desconocido';
      }
      return 'Error de conexión. Revisa tu IP.';
    } catch (e) {
      return e.toString();
    }
    return 'Error desconocido';
  }
}