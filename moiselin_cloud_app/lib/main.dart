import 'dart:io'; // <--- 1. IMPORTANTE: Necesario para HttpOverrides
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/galeria_screen.dart';
import 'services/api_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 2. CLASE PARA IGNORAR ERRORES DE CERTIFICADO (Solo para desarrollo)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await ApiService.cargarUrl();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moiselin Cloud',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CheckAuthScreen(), 
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
    final session = await _apiService.obtenerSesion();
    final token = session['token'];
    final email = session['email'];
    final password = session['password'];

    if (token != null && email != null && password != null) {
      try {
        // Probamos si el token sigue vivo
        await _apiService.obtenerMisAlbumes(token);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GaleriaScreen(token: token)),
          );
          return;
        }
      } catch (e) {
        print("Token caducado, re-logueando...");
        // Si falla, intentamos login silencioso
        String? newToken = await _apiService.login(email, password);
        
        if (newToken != null) {
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

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}