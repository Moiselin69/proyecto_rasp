import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/recursos.dart';

class PapeleraScreen extends StatefulWidget {
  final String token;
  const PapeleraScreen({Key? key, required this.token}) : super(key: key);

  @override
  _PapeleraScreenState createState() => _PapeleraScreenState();
}

class _PapeleraScreenState extends State<PapeleraScreen> {
  final ApiService _apiService = ApiService();
  bool _cargando = true;
  List<Recurso> _recursosPapelera = [];
  
  // --- VARIABLES DE SELECCIÓN ---
  final Set<int> _seleccionados = {};
  bool get _modoSeleccion => _seleccionados.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarPapelera();
  }

  void _cargarPapelera() async {
    setState(() => _cargando = true);
    try {
      final lista = await _apiService.obtenerPapelera(widget.token);
      if (mounted) {
        setState(() {
          _recursosPapelera = lista;
          _cargando = false;
          _seleccionados.clear(); // Limpiamos selección al recargar
        });
      }
    } catch (e) {
      print("Error cargando papelera: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- LÓGICA DE SELECCIÓN ---

  void _toggleSeleccion(int id) {
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados.add(id);
      }
    });
  }

  void _limpiarSeleccion() {
    setState(() {
      _seleccionados.clear();
    });
  }

  // --- LÓGICA DE PROCESAMIENTO POR LOTES ---

  Future<void> _procesarLista(List<int> ids, bool esRestaurar) async {
    if (ids.isEmpty) return;

    // Preguntar confirmación si es eliminar definitivo
    if (!esRestaurar) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ids.length == _recursosPapelera.length ? "Vaciar Papelera" : "Eliminar definitivamente"),
          content: Text("¿Estás seguro? Se eliminarán ${ids.length} archivos para siempre. Esta acción no se puede deshacer."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _cargando = true);

    // Procesamos en paralelo para mayor velocidad
    int exitos = 0;
    List<Future> tareas = [];

    for (int id in ids) {
      if (esRestaurar) {
        tareas.add(_apiService.restaurarRecurso(widget.token, id).then((ok) { if(ok) exitos++; }));
      } else {
        tareas.add(_apiService.eliminarDefinitivo(widget.token, id).then((ok) { if(ok) exitos++; }));
      }
    }

    await Future.wait(tareas);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(esRestaurar 
            ? "Se han restaurado $exitos archivos." 
            : "Se han eliminado $exitos archivos."
          ),
          backgroundColor: esRestaurar ? Colors.green : Colors.redAccent,
        )
      );
      _cargarPapelera(); // Recargamos la lista
    }
  }

  // --- WRAPPERS PARA LOS BOTONES ---

  void _restaurarSeleccionados() {
    _procesarLista(_seleccionados.toList(), true);
  }

  void _eliminarSeleccionados() {
    _procesarLista(_seleccionados.toList(), false);
  }

  void _restaurarTodo() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Restaurar todo"),
          content: const Text("¿Quieres recuperar todos los archivos de la papelera?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Restaurar", style: TextStyle(color: Colors.blue))),
          ],
        ),
      );
    
    if (confirm == true) {
      // Cogemos TODOS los IDs de la lista actual
      final todosLosIds = _recursosPapelera.map((r) => r.id).toList();
      _procesarLista(todosLosIds, true);
    }
  }

  void _vaciarPapelera() {
    // Cogemos TODOS los IDs
    final todosLosIds = _recursosPapelera.map((r) => r.id).toList();
    // Llamamos a procesar (la confirmación ya está dentro de _procesarLista cuando esRestaurar=false)
    _procesarLista(todosLosIds, false);
  }

  // --- UI AUXILIARES ---

  Widget _getIconoArchivo(Recurso recurso) {
    IconData icono;
    Color color;
    if (recurso.esVideo) { icono = Icons.play_circle_fill; color = Colors.redAccent; }
    else if (recurso.tipo == "AUDIO") { icono = Icons.audiotrack; color = Colors.purpleAccent; }
    else { icono = Icons.insert_drive_file; color = Colors.blueGrey; }
    
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(icono, size: 30, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _modoSeleccion 
            ? Text("${_seleccionados.length} seleccionados")
            : const Text("Papelera"),
        backgroundColor: _modoSeleccion ? Colors.blue[50] : null,
        leading: _modoSeleccion 
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black), 
                onPressed: _limpiarSeleccion
              )
            : const BackButton(),
        actions: _modoSeleccion
            ? [
                // ACCIONES PARA SELECCIÓN
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.green),
                  tooltip: "Restaurar seleccionados",
                  onPressed: _restaurarSeleccionados,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: "Eliminar definitivamente",
                  onPressed: _eliminarSeleccionados,
                ),
              ]
            : [
                // ACCIONES GLOBALES (Cuando no hay selección)
                if (_recursosPapelera.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: _restaurarTodo,
                    icon: const Icon(Icons.restore_from_trash, size: 20),
                    label: const Text("Restaurar todo"),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    tooltip: "Vaciar Papelera",
                    onPressed: _vaciarPapelera,
                  ),
                ]
              ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _recursosPapelera.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("La papelera está vacía", style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _recursosPapelera.length,
                  itemBuilder: (ctx, i) {
                    final r = _recursosPapelera[i];
                    final urlThumb = "${ApiService.baseUrl}${r.urlThumbnail}";
                    final isSelected = _seleccionados.contains(r.id);

                    return GestureDetector(
                      onLongPress: () => _toggleSeleccion(r.id),
                      onTap: () {
                        if (_modoSeleccion) {
                          _toggleSeleccion(r.id);
                        } else {
                          // Si no hay modo selección, un tap simple podría mostrar detalles básicos
                          // o preguntar qué hacer con ese archivo individual
                          _toggleSeleccion(r.id); // Por defecto iniciamos selección
                        }
                      },
                      child: Card(
                        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        shape: isSelected 
                            ? RoundedRectangleBorder(side: const BorderSide(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(4))
                            : null,
                        child: ListTile(
                          leading: Stack(
                            children: [
                              SizedBox(
                                width: 50, height: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: (r.esImagen || r.esVideo)
                                      ? CachedNetworkImage(
                                          imageUrl: urlThumb,
                                          httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                                          fit: BoxFit.cover,
                                          errorWidget: (c, u, e) => _getIconoArchivo(r),
                                        )
                                      : _getIconoArchivo(r),
                                ),
                              ),
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.white54,
                                    child: const Icon(Icons.check_circle, color: Colors.blue),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(r.nombre, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.tipo),
                          trailing: _modoSeleccion 
                              ? Checkbox(
                                  value: isSelected, 
                                  onChanged: (v) => _toggleSeleccion(r.id)
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}