import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import "package:flutter_localizations/flutter_localizations.dart";

// 1. Clase para permitir certificados HTTPS autofirmados (Solo desarrollo)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// 2. FUNCIÓN MAIN (La que te faltaba)
void main() {
  // Activamos el override de seguridad
  HttpOverrides.global = MyHttpOverrides();
  
  // Arrancamos la App
  runApp(const MyApp());
}

// 3. Widget Raíz de la Aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés (fallback)
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      home: LoginScreen(),
    );
  }
}