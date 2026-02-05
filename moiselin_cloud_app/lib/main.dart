import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/galeria_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moiselin Cloud',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CheckAuthScreen(), // <--- Arrancamos aquí en vez de LoginScreen
    );
  }
}

class CheckAuthScreen extends StatefulWidget {
  @override
  _CheckAuthScreenState createState() => _CheckAuthScreenState();
}

class _CheckAuthScreenState extends State<CheckAuthScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() async {
    // 1. Intentamos leer los datos guardados
    final session = await _apiService.obtenerSesion();
    final token = session['token'];
    final email = session['email'];
    final password = session['password'];

    if (token != null && email != null && password != null) {
      try {
        final albumes = await _apiService.obtenerMisAlbumes(token);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GaleriaScreen(token: token)),
          );
          return;
        }
      } catch (e) {
        print("Token caducado o error, intentando re-login automático...");
        String? newToken = await _apiService.login(email, password);
        
        if (newToken != null) {
          // Actualizamos el token guardado
          await _apiService.guardarSesion(email, password, newToken);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => GaleriaScreen(token: newToken)),
            );
            return;
          }
        }
      }
    }

    // 4. Si todo falla o no hay datos, vamos al Login normal
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla de carga mientras comprobamos
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}