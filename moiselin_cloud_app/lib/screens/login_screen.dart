import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/persona_api.dart'; // <--- Nuevo servicio para login
import 'galeria_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Instanciamos los servicios
  final ApiService _apiService = ApiService(); 
  final PersonaApiService _personaApi = PersonaApiService(); // <--- Instancia para auth

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1. Llamamos al login usando PersonaApiService
      String? token = await _personaApi.login(email, password);

      if (token != null) {
        // 2. Si el login es correcto, guardamos sesión en ApiService
        await _apiService.guardarSesion(email, password, token);

        if (mounted) {
          // Navegamos a la galería pasando el token
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GaleriaScreen(token: token)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Credenciales incorrectas"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error de conexión: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarConfiguracionIP() {
    // Controlador con la URL actual
    final ipController = TextEditingController(text: ApiService.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Configurar Servidor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Introduce la IP o Dominio de tu servidor (con puerto):"),
            const SizedBox(height: 10),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: "URL Base",
                hintText: "http://192.168.1.X:8000",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ipController.text.isNotEmpty) {
                // Guardamos la URL usando ApiService (método estático)
                await ApiService.guardarUrl(ipController.text);
                Navigator.pop(ctx);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Dirección actualizada a: ${ApiService.baseUrl}")),
                );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moiselin Cloud"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _mostrarConfiguracionIP,
            tooltip: "Configurar IP",
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono / Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, size: 64, color: Colors.blue),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    "Bienvenido",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const Text(
                    "Inicia sesión para ver tus fotos",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Correo Electrónico",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'El correo es obligatorio';
                      if (!value.contains('@')) return 'Introduce un correo válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón Login
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _iniciarSesion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Iniciar Sesión", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}