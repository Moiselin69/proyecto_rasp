import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _borrarAlSubir = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    // 1. Cargamos la URL actual
    _urlController.text = ApiService.baseUrl;
    
    // 2. Cargamos la preferencia de borrar
    final borrar = await ApiService.getBorrarAlSubir();

    setState(() {
      _borrarAlSubir = borrar;
      _isLoading = false;
    });
  }

  Future<void> _guardar() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La URL no puede estar vacía')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Guardamos ambas cosas
    await ApiService.guardarUrl(_urlController.text);
    await ApiService.setBorrarAlSubir(_borrarAlSubir);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada correctamente')),
      );
      Navigator.pop(context); // Volvemos atrás
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Conexión al Servidor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección del Servidor (IP:Puerto)',
                    hintText: 'http://192.168.1.X:8000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 30),
                
                const Text(
                  'Gestión de Archivos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  child: SwitchListTile(
                    title: const Text('Liberar espacio automáticamente'),
                    subtitle: const Text('Borrar el archivo del móvil después de subirlo con éxito a la nube.'),
                    secondary: const Icon(Icons.delete_forever, color: Colors.red),
                    value: _borrarAlSubir,
                    onChanged: (bool value) {
                      setState(() {
                        _borrarAlSubir = value;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('GUARDAR CAMBIOS', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
    );
  }
}