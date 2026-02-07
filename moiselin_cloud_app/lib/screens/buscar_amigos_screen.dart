import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BuscarAmigosScreen extends StatefulWidget {
  const BuscarAmigosScreen({super.key});

  @override
  State<BuscarAmigosScreen> createState() => _BuscarAmigosScreenState();
}

class _BuscarAmigosScreenState extends State<BuscarAmigosScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _resultados = [];
  bool _isLoading = false;
  String _mensaje = '';

  Future<void> _realizarBusqueda() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _mensaje = '';
      _resultados = [];
    });

    try {
      final resultados = await ApiService.buscarPersonas(_searchController.text);
      setState(() {
        _resultados = resultados;
        if (_resultados.isEmpty) {
          _mensaje = 'No se encontraron usuarios.';
        }
      });
    } catch (e) {
      setState(() {
        _mensaje = 'Error al buscar: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enviarSolicitud(int id, String nombre) async {
    try {
      await ApiService.solicitarAmistad(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solicitud enviada a $nombre')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Amigos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de búsqueda
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre, Apellido o Correo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _realizarBusqueda(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _realizarBusqueda,
                  child: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Indicador de carga o mensaje
            if (_isLoading) const CircularProgressIndicator(),
            if (_mensaje.isNotEmpty && !_isLoading) Text(_mensaje),

            // Lista de resultados
            Expanded(
              child: ListView.builder(
                itemCount: _resultados.length,
                itemBuilder: (context, index) {
                  final usuario = _resultados[index];
                  final nombreCompleto = '${usuario['nombre']} ${usuario['apellidos'] ?? ''}';
                  final correo = usuario['correo_electronico'];
                  final id = usuario['id'];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(usuario['nombre'][0].toUpperCase()),
                      ),
                      title: Text(nombreCompleto),
                      subtitle: Text(correo),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.blue),
                        onPressed: () => _enviarSolicitud(id, nombreCompleto),
                        tooltip: 'Enviar solicitud de amistad',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}