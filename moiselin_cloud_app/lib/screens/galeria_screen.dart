import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/recursos.dart';
import "../models/album.dart";
import 'login_screen.dart';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'detalle_foto_screen.dart';

class GaleriaScreen extends StatefulWidget {
  final String token;
  final int? parentId;
  final String nombreCarpeta;
  const GaleriaScreen({
    Key? key, 
    required this.token, 
    this.parentId, 
    this.nombreCarpeta = "Mis Fotos"
  }) : super(key: key);

  @override
  _GaleriaScreenState createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  // Variables de Estado
  bool _cargando = true;
  String _filtroSeleccionado = "Todos"; // El filtro activo
  List<Recurso> _todosLosRecursos = []; // La copia original de todo
  List<Recurso> _recursosFiltrados = []; // Lo que se ve en pantalla
  List<Album> _albumesVisibles = [];
  final List<String> _categorias = ["Todos", "Imagen", "Videos", "Musica", "Otros"]; // Opciones de categorías

  @override
  void initState() {super.initState();_cargarDatos();}

  void _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // 1. Cargamos álbumes y recursos
      final albumes = await _apiService.obtenerMisAlbumes(widget.token);
      final recursos = await _apiService.obtenerMisRecursos(widget.token);

      if (mounted) {
        setState(() {
          // 2. Filtramos localmente para mostrar solo los hijos del nivel actual
          _albumesVisibles = albumes.where((a) => a.idAlbumPadre == widget.parentId).toList();
          _todosLosRecursos = recursos; // Opcional: filtrar recursos por álbum si implementas la relación
          _aplicarFiltro(_filtroSeleccionado);
          _cargando = false;
        });
      }
    } catch (e) { /* manejo de errores */ }
  }
  

  String _obtenerTipoArchivo(String pathArchivo) {
    String ext = path.extension(pathArchivo).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) return 'IMAGEN';
    if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) return 'VIDEO';
    if (['.mp3', '.wav', '.aac', '.flac'].contains(ext)) return 'AUDIO';
    return 'ARCHIVO';
  }

  Future<void> _subirArchivoUniversal() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String tipo = _obtenerTipoArchivo(file.path);

      setState(() => _cargando = true);
      
      // Llamamos al nuevo método del servicio
      bool exito = await _apiService.subirRecurso(widget.token, file, tipo);

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Archivo subido")));
        _cargarDatos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir")));
        setState(() => _cargando = false);
      }
    }
  }

  void _mostrarCrearAlbumDialog() {
    final nombreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Nueva Carpeta"),
        content: TextField(
          controller: nombreCtrl,
          decoration: InputDecoration(hintText: "Nombre de la carpeta"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _cargando = true);
              // Pasamos el parentId actual para crear la carpeta DENTRO de la actual
              bool ok = await _apiService.crearAlbum(widget.token, nombreCtrl.text, "", widget.parentId);
              if (ok) _cargarDatos();
              else setState(() => _cargando = false);
            },
            child: Text("Crear"),
          )
        ],
      ),
    );
  }

  Future<void> _seleccionarYSubir() async {
    try {
      // 1. Abrir galería
      final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);
      
      if (imagen == null) return; // El usuario canceló

      // Mostrar carga mientras sube
      setState(() => _cargando = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Subiendo imagen... por favor espera"))
      );

      // 2. Llamar al backend
      bool exito = await _apiService.subirImagen(
        widget.token, 
        File(imagen.path)
      );

      // 3. Resultado
      if (exito) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Imagen subida con éxito!"), backgroundColor: Colors.green)
        );
        _cargarDatos(); // Recargamos la galería para ver la foto nueva
      } else {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al subir la imagen"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      setState(() => _cargando = false);
      print(e);
    }
  }

  // Lógica para filtrar la lista localmente
  void _aplicarFiltro(String categoria) {
    List<Recurso> temp;
    
    switch (categoria) {
      case "Imagen":
        temp = _todosLosRecursos.where((r) => r.tipo == "IMAGEN").toList();
        break;
      case "Videos":
        temp = _todosLosRecursos.where((r) => r.tipo == "VIDEO").toList();
        break;
      case "Musica":
        temp = _todosLosRecursos.where((r) => r.tipo == "AUDIO").toList();
        break;
      case "Otros":
        // Todo lo que NO sea imagen, video o audio
        temp = _todosLosRecursos.where((r) => 
          !["IMAGEN", "VIDEO", "AUDIO"].contains(r.tipo)).toList();
        break;
      case "Todos":
      default:
        temp = List.from(_todosLosRecursos);
        break;
    }

    setState(() {
      _filtroSeleccionado = categoria;
      _recursosFiltrados = temp;
    });
  }

  void _cerrarSesion() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => LoginScreen())
      );
    }
  }

  Widget _buildCarpeta(Album album) {
    return GestureDetector(
      onTap: () {
        // Navegación recursiva: entramos a otra instancia de GaleriaScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GaleriaScreen(
              token: widget.token,
              parentId: album.id,
              nombreCarpeta: album.nombre,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Icon(Icons.folder, size: 60, color: Colors.amber),
          Text(album.nombre, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _getIconoArchivo(Recurso recurso) {
    IconData icono;
    Color color;

    if (recurso.tipo == "VIDEO") {
      icono = Icons.play_circle_fill;
      color = Colors.redAccent;
    } else if (recurso.tipo == "AUDIO") {
      icono = Icons.audiotrack;
      color = Colors.purpleAccent;
    } else {
      icono = Icons.insert_drive_file;
      color = Colors.blueGrey;
    }

    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 40, color: color),
          SizedBox(height: 4),
          Text(
            recurso.tipo,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.nombreCarpeta), // <--- CAMBIO 1: Título dinámico
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SECCIÓN DE FILTROS (Se mantiene igual)
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 10),
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final isSelected = _filtroSeleccionado == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) _aplicarFiltro(cat);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.blue[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: Colors.blue[900],
                    shape: StadiumBorder(side: BorderSide(color: Colors.transparent)),
                  ),
                );
              },
            ),
          ),

          // 2. GRID DE CONTENIDO
          Expanded(
            child: _cargando 
              ? Center(child: CircularProgressIndicator())
              : (_albumesVisibles.isEmpty && _recursosFiltrados.isEmpty) // Checkeamos ambas listas
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("Carpeta vacía"),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.8, // Ajustado para que quepa el texto de la carpeta
                      ),
                      // CAMBIO 2: La cuenta es la suma de carpetas + archivos
                      itemCount: _albumesVisibles.length + _recursosFiltrados.length,
                      itemBuilder: (context, index) {
                        
                        // CAMBIO 3: Lógica para decidir si pintamos carpeta o archivo
                        if (index < _albumesVisibles.length) {
                          // Es una carpeta
                          return _buildCarpeta(_albumesVisibles[index]);
                        } else {
                          // Es un recurso (ajustamos el índice restando las carpetas)
                          final recurso = _recursosFiltrados[index - _albumesVisibles.length];
                          final urlImagen = "${ApiService.baseUrl}${recurso.urlThumbnail}";
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetalleFotoScreen(
                                    recurso: recurso,
                                    token: widget.token,
                                  ),
                                ),
                              ).then((_) => _cargarDatos()); // Recargar al volver
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  recurso.esImagen
                                    ? CachedNetworkImage(
                                        imageUrl: urlImagen,
                                        httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                                        errorWidget: (context, url, error) => Icon(Icons.error),
                                      )
                                    : _getIconoArchivo(recurso),
                                  
                                  if (recurso.tipo == "VIDEO")
                                    Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btnFolder",
            backgroundColor: Colors.amber,
            onPressed: _cargando ? null : _mostrarCrearAlbumDialog,
            child: Icon(Icons.create_new_folder),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btnFile",
            onPressed: _cargando ? null : _subirArchivoUniversal,
            child: _cargando 
              ? CircularProgressIndicator(color: Colors.white)
              : Icon(Icons.file_upload),
          ),
        ],
      ),
    );
  }
}
