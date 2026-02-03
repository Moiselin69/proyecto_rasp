import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/recursos.dart';
import 'login_screen.dart';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart'; 
import 'detalle_foto_screen.dart';

class GaleriaScreen extends StatefulWidget {
  final String token;

  const GaleriaScreen({Key? key, required this.token}) : super(key: key);

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

  
  // Opciones de categorías
  final List<String> _categorias = ["Todos", "Imagen", "Videos", "Musica", "Otros"];

  @override
  void initState() {
    super.initState();
    _cargarRecursos();
  }

  // Carga los datos una sola vez del servidor
  void _cargarRecursos() async {
    setState(() => _cargando = true);
    try {
      final recursos = await _apiService.obtenerMisRecursos(widget.token);
      if (mounted) {
        setState(() {
          _todosLosRecursos = recursos;
          _aplicarFiltro(_filtroSeleccionado); // Aplicamos el filtro inicial
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cargando galería: $e")),
        );
      }
    }
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
        _cargarRecursos(); // Recargamos la galería para ver la foto nueva
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
        title: Text("Moiselin Cloud"),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarRecursos,
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SECCIÓN DE FILTROS (Horizontal Scroll)
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
              : _recursosFiltrados.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("No hay elementos en '${_filtroSeleccionado}'"),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _recursosFiltrados.length,
                      itemBuilder: (context, index) {
                        final recurso = _recursosFiltrados[index];
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
                          );
                          if (mounted) {_cargarRecursos();}
                        },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // FONDO (Imagen o Icono)
                                recurso.esImagen
                                  ? CachedNetworkImage(
                                      imageUrl: urlImagen,
                                      httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                                      errorWidget: (context, url, error) => Icon(Icons.error),
                                    )
                                  : _getIconoArchivo(recurso),
                                
                                // REPRODUCIR (Overlay para videos)
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
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cargando ? null : _seleccionarYSubir, // <--- Conectamos la función
        backgroundColor: Colors.blue,
        child: _cargando 
          ? CircularProgressIndicator(color: Colors.white)
          : Icon(Icons.add_a_photo),
      ),
    );
  }
}
