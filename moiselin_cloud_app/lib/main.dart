import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- PANTALLAS ---
import 'screens/login_screen.dart';
import 'screens/galeria_screen.dart';

// --- SERVICIOS ---
import 'services/api_service.dart';     // Configuración y Almacenamiento
import 'services/persona_api.dart';     // Login
import 'services/album_api.dart';       // Verificación de token (cargar datos)

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
      navigatorObservers: [routeObserver],
      home: CheckAuthScreen(), 
    );
  }
}

class CheckAuthScreen extends StatefulWidget {
  @override
  _CheckAuthScreenState createState() => _CheckAuthScreenState();
}

class _CheckAuthScreenState extends State<CheckAuthScreen> {
  // Instanciamos los servicios necesarios
  final ApiService _apiService = ApiService();       // Para leer credenciales del disco
  final PersonaApiService _personaApi = PersonaApiService(); // Para hacer login
  final AlbumApiService _albumApi = AlbumApiService();       // Para probar si el token sirve

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() async {
    // 1. Recuperar credenciales guardadas
    final session = await _apiService.obtenerSesion();
    final token = session['token'];
    final email = session['email'];
    final password = session['password'];

    if (token != null && email != null && password != null) {
      try {
        // 2. Probar si el token sigue vivo intentando cargar datos (ej: álbumes)
        // Nota: Pasamos el token explícitamente porque AlbumApi lo requería en tu código anterior
        await _albumApi.obtenerMisAlbumes(token);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GaleriaScreen(token: token)),
          );
          return;
        }
      } catch (e) {
        print("Token caducado o error de conexión, intentando re-loguear...");
        
        // 3. Si falla (401), intentamos login silencioso con PersonaApiService
        try {
          String? newToken = await _personaApi.login(email, password);
          
          if (newToken != null) {
            // Guardamos el nuevo token
            await _apiService.guardarSesion(email, password, newToken);
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => GaleriaScreen(token: newToken)),
              );
              return;
            }
          }
        } catch (loginError) {
          print("Fallo el re-login: $loginError");
        }
      }
    }

    // 4. Si no hay sesión o falló todo, vamos al Login
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}