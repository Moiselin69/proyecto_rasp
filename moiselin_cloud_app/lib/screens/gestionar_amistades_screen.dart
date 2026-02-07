import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GestionarAmistadesScreen extends StatelessWidget {
  const GestionarAmistadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // AHORA SON 3 PESTAÑAS
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestionar Amistades'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.search), text: "Buscar"),
              Tab(icon: Icon(Icons.notifications_active), text: "Solicitudes"),
              Tab(icon: Icon(Icons.people), text: "Mis Amigos"), // NUEVA PESTAÑA
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BusquedaTab(),    
            _SolicitudesTab(), 
            _MisAmigosTab(),   // NUEVA VISTA
          ],
        ),
      ),
    );
  }
}

// --- PESTAÑA 1: BUSCAR AMIGOS ---
class _BusquedaTab extends StatefulWidget {
  const _BusquedaTab();

  @override
  State<_BusquedaTab> createState() => _BusquedaTabState();
}

class _BusquedaTabState extends State<_BusquedaTab> {
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
        if (_resultados.isEmpty) _mensaje = 'No se encontraron usuarios.';
      });
    } catch (e) {
      setState(() => _mensaje = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enviarSolicitud(int id, String nombre) async {
    try {
      await ApiService.solicitarAmistad(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitud enviada a $nombre')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar por nombre o correo',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _realizarBusqueda,
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _realizarBusqueda(),
          ),
          const SizedBox(height: 10),
          if (_isLoading) const LinearProgressIndicator(),
          if (_mensaje.isNotEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(_mensaje)),
          Expanded(
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final u = _resultados[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(u['nombre'][0].toUpperCase())),
                    title: Text('${u['nombre']} ${u['apellidos'] ?? ''}'),
                    subtitle: Text(u['correo_electronico']),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.blue),
                      onPressed: () => _enviarSolicitud(u['id'], u['nombre']),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- PESTAÑA 2: SOLICITUDES PENDIENTES ---
class _SolicitudesTab extends StatefulWidget {
  const _SolicitudesTab();

  @override
  State<_SolicitudesTab> createState() => _SolicitudesTabState();
}

class _SolicitudesTabState extends State<_SolicitudesTab> {
  List<dynamic> _peticiones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPeticiones();
  }

  Future<void> _cargarPeticiones() async {
    try {
      final lista = await ApiService.verPeticionesPendientes();
      if (mounted) {
        setState(() {
          _peticiones = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _responder(int id, bool aceptar) async {
    try {
      if (aceptar) {
        await ApiService.aceptarAmistad(id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Amistad aceptada!')));
      } else {
        await ApiService.rechazarAmistad(id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
      }
      _cargarPeticiones(); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_peticiones.isEmpty) {
      return const Center(child: Text('No tienes solicitudes pendientes'));
    }

    return RefreshIndicator(
      onRefresh: _cargarPeticiones,
      child: ListView.builder(
        itemCount: _peticiones.length,
        itemBuilder: (context, index) {
          final p = _peticiones[index];
          final id = p['id_solicitante'] ?? p['id'];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.person_pin, size: 40, color: Colors.orange),
              title: Text('${p['nombre']} ${p['apellidos'] ?? ''}'),
              subtitle: Text(p['correo_electronico']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _responder(id, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _responder(id, false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- PESTAÑA 3: MIS AMIGOS (NUEVA) ---
class _MisAmigosTab extends StatefulWidget {
  const _MisAmigosTab();

  @override
  State<_MisAmigosTab> createState() => _MisAmigosTabState();
}

class _MisAmigosTabState extends State<_MisAmigosTab> {
  List<dynamic> _amigos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarAmigos();
  }

  Future<void> _cargarAmigos() async {
    try {
      final lista = await ApiService.verAmigos();
      if (mounted) {
        setState(() {
          _amigos = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarAmigo(int id, String nombre) async {
    // Confirmación antes de borrar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Amigo'),
        content: Text('¿Seguro que quieres eliminar a $nombre?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ApiService.eliminarAmigo(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amigo eliminado')));
        _cargarAmigos(); // Recargar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_amigos.isEmpty) {
      return const Center(child: Text('Aún no tienes amigos agregados.'));
    }

    return RefreshIndicator(
      onRefresh: _cargarAmigos,
      child: ListView.builder(
        itemCount: _amigos.length,
        itemBuilder: (context, index) {
          final amigo = _amigos[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Text(amigo['nombre'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text('${amigo['nombre']} ${amigo['apellidos'] ?? ''}'),
              subtitle: Text(amigo['correo_electronico']),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () => _eliminarAmigo(amigo['id'], amigo['nombre']),
                tooltip: "Eliminar amigo",
              ),
            ),
          );
        },
      ),
    );
  }
}