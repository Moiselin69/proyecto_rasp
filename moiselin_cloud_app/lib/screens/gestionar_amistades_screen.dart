import 'package:flutter/material.dart';
import '../services/persona_api.dart'; // <--- Usamos el nuevo servicio

class GestionarAmistadesScreen extends StatelessWidget {
  const GestionarAmistadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestionar Amistades'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.search), text: "Buscar"),
              Tab(icon: Icon(Icons.notifications_active), text: "Solicitudes"),
              Tab(icon: Icon(Icons.people), text: "Mis Amigos"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BusquedaTab(),
            _SolicitudesTab(),
            _MisAmigosTab(),
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
  final PersonaApiService _personaApi = PersonaApiService(); // Instancia del servicio
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _resultados = [];
  bool _isLoading = false;
  String _mensaje = '';

  Future<void> _realizarBusqueda() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _mensaje = '';
      _resultados = [];
    });

    try {
      // Usamos buscarPersonas de PersonaApiService
      final resultados = await _personaApi.buscarPersonas(_searchController.text.trim());
      
      setState(() {
        _resultados = resultados;
        if (_resultados.isEmpty) _mensaje = 'No se encontraron usuarios.';
      });
    } catch (e) {
      setState(() => _mensaje = 'Error al buscar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enviarSolicitud(int id, String nombre) async {
    try {
      // Usamos solicitarAmistad que devuelve un Map con estado
      final res = await _personaApi.solicitarAmistad(id);
      
      if (mounted) {
        if (res['exito']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Solicitud enviada a $nombre'), backgroundColor: Colors.green)
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['mensaje'] ?? 'Error al enviar'), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red)
        );
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
              labelText: 'Buscar por nickname, nombre o correo',
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
                    leading: CircleAvatar(
                      child: Text(u['nombre'].isNotEmpty ? u['nombre'][0].toUpperCase() : '?'),
                    ),
                    title: Text('${u['nombre']} ${u['apellidos'] ?? ''}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("@${u['nickname'] ?? 'sin_nick'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(u['correo_electronico'] ?? ''),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.blue),
                      onPressed: () => _enviarSolicitud(u['id'], u['nombre']),
                      tooltip: "Enviar solicitud",
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
  final PersonaApiService _personaApi = PersonaApiService();
  List<dynamic> _peticiones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPeticiones();
  }

  Future<void> _cargarPeticiones() async {
    try {
      // obtenerAmistades devuelve TODO mezclado. Filtramos por 'SOLICITUD_RECIBIDA'.
      final listaCompleta = await _personaApi.obtenerAmistades();
      
      final pendientes = listaCompleta.where((e) => e['estado'] == 'SOLICITUD_RECIBIDA').toList();

      if (mounted) {
        setState(() {
          _peticiones = pendientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando peticiones: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _responder(int id, bool aceptar) async {
    try {
      // Usamos responderAmistad con la acción correspondiente
      final accion = aceptar ? 'ACEPTAR' : 'RECHAZAR';
      final res = await _personaApi.responderAmistad(id, accion);

      if (mounted) {
        if (res['exito']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(aceptar ? '¡Amistad aceptada!' : 'Solicitud rechazada'),
              backgroundColor: aceptar ? Colors.green : Colors.orange,
            )
          );
          _cargarPeticiones(); // Recargamos la lista
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['mensaje']), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
      }
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
          // El endpoint devuelve 'id' directamente como el ID del otro usuario
          final idUsuario = p['id']; 
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.person_pin, size: 40, color: Colors.orange),
              title: Text('${p['nombre']} ${p['apellidos'] ?? ''}'),
              subtitle: Text("@${p['nickname']}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _responder(idUsuario, true),
                    tooltip: "Aceptar",
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _responder(idUsuario, false),
                    tooltip: "Rechazar",
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

// --- PESTAÑA 3: MIS AMIGOS ---
class _MisAmigosTab extends StatefulWidget {
  const _MisAmigosTab();

  @override
  State<_MisAmigosTab> createState() => _MisAmigosTabState();
}

class _MisAmigosTabState extends State<_MisAmigosTab> {
  final PersonaApiService _personaApi = PersonaApiService();
  List<dynamic> _amigos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarAmigos();
  }

  Future<void> _cargarAmigos() async {
    try {
      // Filtramos por estado 'AMIGO'
      final listaCompleta = await _personaApi.obtenerAmistades();
      final amigosConfirmados = listaCompleta.where((e) => e['estado'] == 'AMIGO').toList();

      if (mounted) {
        setState(() {
          _amigos = amigosConfirmados;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando amigos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarAmigo(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Amigo'),
        content: Text('¿Seguro que quieres eliminar a $nombre de tus amigos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Usamos responderAmistad con acción 'ELIMINAR'
      final res = await _personaApi.responderAmistad(id, 'ELIMINAR');
      
      if (mounted) {
        if (res['exito']) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amigo eliminado')));
          _cargarAmigos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['mensaje']), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
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
                child: Text(amigo['nombre'].isNotEmpty ? amigo['nombre'][0].toUpperCase() : '?'),
              ),
              title: Text('${amigo['nombre']} ${amigo['apellidos'] ?? ''}'),
              subtitle: Text("@${amigo['nickname']}"),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.grey),
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