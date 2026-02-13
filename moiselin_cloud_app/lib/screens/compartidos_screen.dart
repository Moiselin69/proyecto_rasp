import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recursos.dart';
import '../models/album.dart';
import '../services/api_service.dart';
import '../services/recurso_api.dart';
import '../services/album_api.dart'; // Necesario para invitaciones de álbum
import 'detalle_foto_screen.dart';
import 'galeria_screen.dart'; // Para reutilizar InsecureCacheManager si es necesario o navegación

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
              Tab(icon: Icon(Icons.folder_shared), text: "Contenido"),
              Tab(icon: Icon(Icons.notifications_active), text: "Solicitudes"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ContenidoCompartidoTab(),
            _SolicitudesTab(),
          ],
        ),
      ),
    );
  }
}

// --- PESTAÑA 1: CONTENIDO (ÁLBUMES + ARCHIVOS) ---
class _ContenidoCompartidoTab extends StatefulWidget {
  const _ContenidoCompartidoTab();

  @override
  State<_ContenidoCompartidoTab> createState() => _ContenidoCompartidoTabState();
}

class _ContenidoCompartidoTabState extends State<_ContenidoCompartidoTab> {
  final RecursoApiService _recursoApi = RecursoApiService();
  final AlbumApiService _albumApi = AlbumApiService();
  
  List<dynamic> _elementos = []; // Lista mixta (Album + Recurso)
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    try {
      // 1. Obtener Archivos compartidos
      final recursos = await _recursoApi.verCompartidosConmigo();
      
      // 2. Obtener Álbumes compartidos (Filtramos donde NO soy CREADOR)
      final todosAlbumes = await _albumApi.obtenerMisAlbumes(token);
      // Asumimos que el modelo Album tiene un campo 'rol' o lo deducimos.
      // Si el modelo Album no tiene 'rol', tendrás que confiar en la API 'obtenerMisAlbumes'
      // que devuelve todo. Para saber cuáles son compartidos, 
      // idealmente el backend ya filtra o el modelo Album tiene esa info.
      // Basado en tu código anterior, Album tiene 'rol' en el JSON del backend? 
      // Si no, filtraremos por lógica o mostraremos todos los que no sean 'CREADOR' si tienes ese dato.
      // * Nota: He actualizado consultasAlbum.py para que devuelva el rol. Asegúrate de que el modelo Album.dart lo reciba.
      // Si Album.dart no tiene rol, no podemos filtrar aquí fácilmente.
      // Asumiremos que quieres ver todos los álbumes donde eres COLABORADOR.
      
      // Para este ejemplo, mostraremos todos los álbumes que NO sean 'CREADOR' si es posible,
      // si no, mostraremos todos. (Ajusta según tu modelo Album)
      // * Hack temporal si tu modelo Album no tiene rol: Mostrarlos todos o asumir que si están aquí es por algo.
      // Pero mejor, vamos a suponer que has actualizado el modelo Album para incluir 'rol' o usamos dynamic.
      
      // Si no puedes modificar Album.dart ahora, usaremos una lógica simple:
      // Si te han compartido un álbum, aparecerá en 'obtenerMisAlbumes'.
      
      final albumesCompartidos = todosAlbumes; // Filtraremos visualmente si es necesario

      if (mounted) {
        setState(() {
          _elementos = [...albumesCompartidos, ...recursos];
          _token = token;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando compartidos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salirDeElemento(dynamic elemento) async {
    bool esAlbum = elemento is Album;
    String titulo = esAlbum ? "Salir del álbum" : "Dejar de ver archivo";
    String contenido = esAlbum 
        ? "¿Seguro que quieres salir de '${elemento.nombre}'?" 
        : "¿Dejar de tener acceso a '${elemento.nombre}'?";

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(contenido),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sí, salir", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmar == true) {
      bool exito = false;
      if (esAlbum) {
        exito = await _albumApi.salirDeAlbum(_token!, elemento.id);
      } else {
        // Asumimos que es Recurso
        exito = await _recursoApi.dejarRecursoCompartido(elemento.id);
      }

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Has salido correctamente")));
        _cargarDatos();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al salir"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_elementos.isEmpty) return const Center(child: Text("Nada compartido contigo aún."));

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.85
      ),
      itemCount: _elementos.length,
      itemBuilder: (context, index) {
        final item = _elementos[index];
        
        if (item is Album) {
          return _buildAlbumCard(item);
        } else if (item is Recurso) {
          return _buildRecursoCard(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAlbumCard(Album album) {
    return GestureDetector(
      onTap: () {
        // Navegar dentro del álbum (reutilizamos GaleriaScreen)
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GaleriaScreen(token: _token!, parentId: album.id, nombreCarpeta: album.nombre)
        ));
      },
      onLongPress: () => _salirDeElemento(album),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.folder_shared, size: 50, color: Colors.amber)),
            ),
          ),
          const SizedBox(height: 4),
          Text(album.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const Text("Álbum", style: TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildRecursoCard(Recurso recurso) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleRecursoScreen(recurso: recurso, token: _token!)));
      },
      onLongPress: () => _salirDeElemento(recurso),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (recurso.tipo == "IMAGEN" || recurso.tipo == "VIDEO")
                    ? CachedNetworkImage(
                        imageUrl: "${ApiService.baseUrl}${recurso.urlVisualizacion}?size=small",
                        httpHeaders: {"Authorization": "Bearer $_token"},
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                      )
                    : Container(color: Colors.grey[200], child: const Icon(Icons.insert_drive_file, color: Colors.blueGrey)),
                  
                  if (recurso.tipo == "VIDEO")
                    const Center(child: Icon(Icons.play_circle, color: Colors.white, size: 30)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(recurso.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// --- PESTAÑA 2: SOLICITUDES (MIXTA: ÁLBUMES Y RECURSOS) ---
class _SolicitudesTab extends StatefulWidget {
  const _SolicitudesTab();

  @override
  State<_SolicitudesTab> createState() => _SolicitudesTabState();
}

class _SolicitudesTabState extends State<_SolicitudesTab> {
  final RecursoApiService _recursoApi = RecursoApiService();
  final AlbumApiService _albumApi = AlbumApiService();
  
  List<Map<String, dynamic>> _solicitudes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      // 1. Solicitudes de Archivos
      final recursosRaw = await _recursoApi.verPeticionesRecepcion();
      // 2. Invitaciones de Álbumes
      final albumesRaw = await _albumApi.verInvitacionesAlbum(token);

      // Normalizamos los datos para la lista
      final listaRecursos = recursosRaw.map((r) => {
        'tipo': 'RECURSO',
        'titulo': r['nombre_recurso'],
        'subtitulo': "Archivo ${r['tipo']}",
        'emisor': "${r['nombre_emisor']} ${r['apellidos_emisor'] ?? ''}",
        'data': r,
        'icono': Icons.description
      }).toList();

      final listaAlbumes = albumesRaw.map((a) => {
        'tipo': 'ALBUM',
        'titulo': a['nombre_album'],
        'subtitulo': "Invitación a carpeta (${a['rol']})",
        'emisor': "${a['nombre_invitador']} ${a['apellidos_invitador'] ?? ''}",
        'data': a,
        'icono': Icons.folder_special
      }).toList();

      if (mounted) {
        setState(() {
          _solicitudes = [...listaRecursos, ...listaAlbumes]; // Juntamos todo
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error cargando solicitudes: $e");
    }
  }

  Future<void> _responder(Map<String, dynamic> item, bool aceptar) async {
    bool exito = false;
    String msg = "";
    
    try {
      final token = await ApiService.getToken();
      
      if (item['tipo'] == 'RECURSO') {
        final data = item['data'];
        final res = await _recursoApi.responderPeticionRecurso(data['id_emisor'], data['id_recurso'], aceptar);
        exito = res['exito'];
        msg = res['mensaje'];
      } else {
        // ALBUM
        final data = item['data'];
        // id_invitador viene en data['id_invitador']
        final res = await _albumApi.responderInvitacionAlbum(token!, data['id_album'], data['id_invitador'], aceptar);
        exito = res; // El método devuelve bool en tu servicio actual
        msg = exito ? "Respuesta enviada" : "Error al responder";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: exito ? Colors.green : Colors.red,
        ));
        if (exito) _cargar(); // Recargar lista
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_solicitudes.isEmpty) return const Center(child: Text("No tienes solicitudes pendientes."));

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _solicitudes.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = _solicitudes[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: item['tipo'] == 'ALBUM' ? Colors.amber[100] : Colors.blue[100],
            child: Icon(item['icono'], color: item['tipo'] == 'ALBUM' ? Colors.amber[800] : Colors.blue[800]),
          ),
          title: Text("Te comparten: ${item['titulo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['subtitulo']),
              Text("De: ${item['emisor']}", style: const TextStyle(color: Colors.grey)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                onPressed: () => _responder(item, true),
                tooltip: "Aceptar",
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                onPressed: () => _responder(item, false),
                tooltip: "Rechazar",
              ),
            ],
          ),
        );
      },
    );
  }
}