import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recursos.dart';
import '../services/api_service.dart';
import 'detalle_foto_screen.dart'; // Importa tu pantalla de detalle

class CompartidosScreen extends StatelessWidget {
  const CompartidosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compartidos conmigo'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_shared), text: "Archivos"),
              Tab(icon: Icon(Icons.mark_email_unread), text: "Solicitudes"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ArchivosCompartidosTab(),
            _SolicitudesRecursosTab(),
          ],
        ),
      ),
    );
  }
}

// --- PESTAÑA 1: ARCHIVOS YA COMPARTIDOS (GRID) ---
class _ArchivosCompartidosTab extends StatefulWidget {
  const _ArchivosCompartidosTab();

  @override
  State<_ArchivosCompartidosTab> createState() => _ArchivosCompartidosTabState();
}

class _ArchivosCompartidosTabState extends State<_ArchivosCompartidosTab> {
  List<Recurso> _recursos = [];
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final token = await ApiService.getToken(); 
    try {
      final lista = await ApiService.verCompartidosConmigo();
      if (mounted) {
        setState(() {
          _recursos = lista;
          _token = token;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando compartidos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_recursos.isEmpty) return const Center(child: Text("No te han compartido archivos aún."));

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _recursos.length,
      itemBuilder: (context, index) {
        final recurso = _recursos[index];
        final url = "${ApiService.baseUrl}${recurso.urlVisualizacion}";

        return GestureDetector(
          onTap: () {
            // Navegar al detalle para ver/descargar
            if (_token != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleRecursoScreen(recurso: recurso, token: _token!),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(recurso, url),
              // Icono indicando tipo
              Positioned(
                right: 2, top: 2,
                child: Icon(
                  _getIconForType(recurso.tipo),
                  color: Colors.white, size: 16,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(Recurso r, String url) {
    if (r.tipo == "IMAGEN") {
      return CachedNetworkImage(
        imageUrl: url,
        httpHeaders: {"Authorization": "Bearer $_token"},
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
      );
    } else {
      return Container(color: Colors.grey[300], child: Icon(_getIconForType(r.tipo), size: 40, color: Colors.grey[700]));
    }
  }

  IconData _getIconForType(String tipo) {
    switch (tipo) {
      case 'VIDEO': return Icons.videocam;
      case 'AUDIO': return Icons.audiotrack;
      case 'ARCHIVO': return Icons.insert_drive_file;
      default: return Icons.image;
    }
  }
}

// --- PESTAÑA 2: SOLICITUDES DE NO AMIGOS ---
class _SolicitudesRecursosTab extends StatefulWidget {
  const _SolicitudesRecursosTab();

  @override
  State<_SolicitudesRecursosTab> createState() => _SolicitudesRecursosTabState();
}

class _SolicitudesRecursosTabState extends State<_SolicitudesRecursosTab> {
  List<dynamic> _solicitudes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await ApiService.verSolicitudesRecursos();
      if (mounted) setState(() { _solicitudes = lista; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _responder(int index, bool aceptar) async {
    final s = _solicitudes[index];
    try {
      await ApiService.responderSolicitudRecurso(s['id_emisor'], s['id_recurso'], aceptar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aceptar ? "Aceptado" : "Rechazado")));
        _cargar(); // Recargar lista
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_solicitudes.isEmpty) return const Center(child: Text("No tienes solicitudes pendientes."));

    return ListView.builder(
      itemCount: _solicitudes.length,
      itemBuilder: (context, index) {
        final s = _solicitudes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: const Icon(Icons.lock_clock, color: Colors.orange, size: 35),
            title: Text("Quiere compartirte: ${s['nombre_recurso']}"),
            subtitle: Text("De: ${s['nombre_emisor']} ${s['apellidos_emisor'] ?? ''}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _responder(index, true)),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _responder(index, false)),
              ],
            ),
          ),
        );
      },
    );
  }
}