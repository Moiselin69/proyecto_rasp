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

  @override
  void initState() {
    super.initState();
    _cargarPapelera();
  }

  void _cargarPapelera() async {
    setState(() => _cargando = true);
    try {
      final lista = await _apiService.obtenerPapelera(widget.token);
      setState(() {
        _recursosPapelera = lista;
        _cargando = false;
      });
    } catch (e) {
      print("Error cargando papelera: $e");
      setState(() => _cargando = false);
    }
  }

  void _accionRestaurar(Recurso r) async {
    bool ok = await _apiService.restaurarRecurso(widget.token, r.id);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restaurado: ${r.nombre}")));
      _cargarPapelera();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al restaurar")));
    }
  }

  void _accionEliminarDefinitivo(Recurso r) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("¿Eliminar para siempre?"),
        content: Text("Esta acción NO se puede deshacer. El archivo desaparecerá del servidor."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      bool ok = await _apiService.eliminarDefinitivo(widget.token, r.id);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Eliminado definitivamente")));
        _cargarPapelera();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar")));
      }
    }
  }

  // Diálogo para gestionar un ítem individual al pulsarlo
  void _mostrarOpcionesItem(Recurso r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.nombre, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Divider(),
              ListTile(
                leading: Icon(Icons.restore, color: Colors.green),
                title: Text("Restaurar"),
                onTap: () {
                  Navigator.pop(ctx);
                  _accionRestaurar(r);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text("Eliminar definitivamente"),
                onTap: () {
                  Navigator.pop(ctx);
                  _accionEliminarDefinitivo(r);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getIconoArchivo(Recurso recurso) {
    IconData icono;
    if (recurso.esVideo) icono = Icons.play_circle_fill;
    else if (recurso.tipo == "AUDIO") icono = Icons.audiotrack;
    else icono = Icons.insert_drive_file;
    
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(icono, size: 40, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Papelera de Reciclaje")),
      body: _cargando
          ? Center(child: CircularProgressIndicator())
          : _recursosPapelera.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 80, color: Colors.grey),
                      Text("La papelera está vacía", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(10),
                  itemCount: _recursosPapelera.length,
                  itemBuilder: (ctx, i) {
                    final r = _recursosPapelera[i];
                    final urlThumb = "${ApiService.baseUrl}${r.urlThumbnail}";

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: Container(
                          width: 50, height: 50,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: (r.esImagen || r.esVideo)
                                ? CachedNetworkImage(
                                    imageUrl: urlThumb,
                                    httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) => Icon(Icons.error),
                                  )
                                : _getIconoArchivo(r),
                          ),
                        ),
                        title: Text(r.nombre, overflow: TextOverflow.ellipsis),
                        subtitle: Text("Eliminado: ${r.id}"), // Podrías mostrar fecha de eliminación si la trajeras en el modelo
                        trailing: IconButton(
                          icon: Icon(Icons.more_vert),
                          onPressed: () => _mostrarOpcionesItem(r),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}