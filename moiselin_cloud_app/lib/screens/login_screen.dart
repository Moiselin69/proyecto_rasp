import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoCtrl = TextEditingController();
  final _contraCtrl = TextEditingController();
  final _apiService = ApiService();
  bool _cargando = false;

  void _hacerLogin() async {
    setState(() => _cargando = true);
    
    // Llamamos a tu backend
    final error = await _apiService.login(
      _correoCtrl.text.trim(), 
      _contraCtrl.text.trim()
    );

    setState(() => _cargando = false);

    if (error == null) {
      // Éxito
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Login correcto! Token guardado.')),
        );
        // Aquí navegaríamos a la pantalla Home
      }
    } else {
      // Error
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moiselin Cloud')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _correoCtrl,
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contraCtrl,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _cargando 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _hacerLogin,
                  child: const Text('Entrar'),
                ),
          ],
        ),
      ),
    );
  }
}