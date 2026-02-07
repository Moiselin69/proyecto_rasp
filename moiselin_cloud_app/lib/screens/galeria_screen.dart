import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/recursos.dart';
import "../models/album.dart";
import 'login_screen.dart';
import 'dart:io'; 
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'detalle_foto_screen.dart';
import "../services/download_service.dart";
import 'gestionar_amistades_screen.dart';
import 'configuracion_screen.dart';

class GaleriaScreen extends StatefulWidget {
  final String token;
  final int? parentId;
  final String nombreCarpeta;
  const GaleriaScreen({
    Key? key, 
    required this.token, 
    this.parentId, 
    this.nombreCarpeta = "Moiselin Cloud"
  }) : super(key: key);

  @override
  _GaleriaScreenState createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  final ApiService _apiService = ApiService();
  final DownloadService _downloadService = DownloadService();
  bool _cargando = true;
  String _filtroSeleccionado = "Todos"; 
  List<Recurso> _todosLosRecursos = []; 
  List<Recurso> _recursosFiltrados = []; 
  List<Album> _albumesVisibles = [];
  List<Album> _albumesFiltrados = [];
  bool _buscando = false;
  final TextEditingController _searchController = TextEditingController();
  String _filtroOrden = "subida_desc";
  
  // --- NUEVA LÓGICA DE SELECCIÓN MIXTA ---
  bool _modoSeleccion = false;
  bool _mostrarMenuAdmin = false;
  Set<int> _recursosSeleccionados = {};
  Set<int> _albumesSeleccionados = {}; // Nuevo set para carpetas

  final List<String> _categorias = ["Todos", "Imagen", "Videos", "Musica", "Otros"];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final albumes = await _apiService.obtenerMisAlbumes(widget.token);
      final recursos = await _apiService.obtenerMisRecursos(widget.token);

      if (mounted) {
        setState(() {
          _albumesVisibles = albumes.where((a) => a.idAlbumPadre == widget.parentId).toList();
          _todosLosRecursos = recursos.where((r) => r.idAlbum == widget.parentId).toList();
          _aplicarFiltros();
          _cargando = false;
        });
      }
    } catch (e) {
      print("Error cargando datos: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    // 1. Empezamos con la lista completa (copia)
    List<Recurso> listaRecursos = List.from(_todosLosRecursos); // Asegúrate de tener _todosLosRecursos llena con los datos de la API
    List<Album> listaAlbumes = List.from(_albumesVisibles);
    // 2. Filtro de Texto (Buscador)
    String texto = _searchController.text.toLowerCase();
    if (texto.isNotEmpty) {
      listaRecursos = listaRecursos.where((r) => 
        r.nombre.toLowerCase().contains(texto)
      ).toList();
      listaAlbumes = listaAlbumes.where((a) => 
        a.nombre.toLowerCase().contains(texto)
      ).toList();
    }
    int compararAlbumes(Album a, Album b, bool asc) {
       return asc 
         ? a.fechaCreacion.compareTo(b.fechaCreacion)
         : b.fechaCreacion.compareTo(a.fechaCreacion);
    }
    // 3. Ordenación
    switch (_filtroOrden) {
      case 'subida_desc': // Reciente primero
        listaRecursos.sort((a, b) => b.fechaSubida.compareTo(a.fechaSubida));
        listaAlbumes.sort((a, b) => compararAlbumes(a, b, false)); 
        break;
        
      case 'subida_asc': // Antiguo primero
        listaRecursos.sort((a, b) => a.fechaSubida.compareTo(b.fechaSubida));
        listaAlbumes.sort((a, b) => compararAlbumes(a, b, true));
        break;
      
      case 'real_desc': 
        // En carpetas "fecha real" lo tratamos como "creación"
        listaRecursos.sort((a, b) => (b.fechaReal ?? DateTime(1900)).compareTo(a.fechaReal ?? DateTime(1900)));
        listaAlbumes.sort((a, b) => compararAlbumes(a, b, false));
        break;
      
      case 'real_asc':
        listaRecursos.sort((a, b) => (a.fechaReal ?? DateTime(2100)).compareTo(b.fechaReal ?? DateTime(2100)));
        listaAlbumes.sort((a, b) => compararAlbumes(a, b, true));
        break;

      case 'nombre_asc':
        listaRecursos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        listaAlbumes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        break;
    }

    // 4. Actualizamos la vista
    setState(() {
      _recursosFiltrados = listaRecursos;
      _albumesFiltrados = listaAlbumes;
    });
  }

  void _mostrarMenuOrden() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Ordenar por", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Divider(),
              _buildOpcionOrden("📅 Fecha de Subida (Reciente)", "subida_desc"),
              _buildOpcionOrden("📅 Fecha de Subida (Antiguo)", "subida_asc"),
              _buildOpcionOrden("📷 Fecha Captura (Reciente)", "real_desc"),
              _buildOpcionOrden("🔤 Nombre (A-Z)", "nombre_asc"),
            ],
          ),
        );
      }
    );
  }

  Widget _buildOpcionOrden(String texto, String valor) {
    bool seleccionado = _filtroOrden == valor;
    return ListTile(
      title: Text(texto, style: TextStyle(fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal, color: seleccionado ? Colors.blue : Colors.black)),
      trailing: seleccionado ? Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() => _filtroOrden = valor);
        _aplicarFiltros(); // Aplicamos el nuevo orden
        Navigator.pop(context); // Cerramos menú
      },
    );
  }

  void _accionDescargarSeleccion() async {
    if (_recursosSeleccionados.isEmpty) return;
    String? directorioDestino = await FilePicker.platform.getDirectoryPath();
    if (directorioDestino == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Guardando en: $directorioDestino..."))
    );
    int exitoCount = 0;
    for (int id in _recursosSeleccionados) {
      try {
        final recurso = _todosLosRecursos.firstWhere((r) => r.id == id);
        String urlCompleta = "${ApiService.baseUrl}${recurso.urlVisualizacion}";
        String nombreFinal = recurso.nombre;
        String extension = "";
        if (path.extension(nombreFinal).isEmpty) {
           switch (recurso.tipo) {
             case "VIDEO": nombreFinal += ".mp4"; break;
             case "IMAGEN": nombreFinal += ".jpg"; break;
             case "AUDIO": nombreFinal += ".mp3"; break;
             case "ARCHIVO": nombreFinal += ".pdf"; break;
           }
        }
        if (!nombreFinal.toLowerCase().endsWith(extension)) nombreFinal += extension;
        String? res = await _downloadService.descargarYGuardar(
          urlCompleta, 
          nombreFinal, 
          recurso.tipo, 
          widget.token,
          rutaPersonalizada: directorioDestino
        );
        if (res != null) exitoCount++;
      } catch (e) {
        print("Error item $id: $e");
      }
    }
    if (mounted) {
      _limpiarSeleccion();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Se han guardado $exitoCount archivos en la carpeta elegida."),
          backgroundColor: Colors.green,
        )
      );
    }
  }

  // Toggle para ARCHIVOS
  void _toggleSeleccionRecurso(int id) {
    setState(() {
      if (_recursosSeleccionados.contains(id)) {
        _recursosSeleccionados.remove(id);
      } else {
        _recursosSeleccionados.add(id);
      }
      _actualizarModoSeleccion();
    });
  }

  // Toggle para CARPETAS
  void _toggleSeleccionAlbum(int id) {
    setState(() {
      if (_albumesSeleccionados.contains(id)) {
        _albumesSeleccionados.remove(id);
      } else {
        _albumesSeleccionados.add(id);
      }
      _actualizarModoSeleccion();
    });
  }

  void _actualizarModoSeleccion() {
    _modoSeleccion = _recursosSeleccionados.isNotEmpty || _albumesSeleccionados.isNotEmpty;
  }

  void _limpiarSeleccion() {
    setState(() {
      _recursosSeleccionados.clear();
      _albumesSeleccionados.clear();
      _modoSeleccion = false;
    });
  }

  void _accionBorrar() async {
    int total = _recursosSeleccionados.length + _albumesSeleccionados.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Eliminar $total elementos"),
        content: Text("Se eliminarán las carpetas y archivos seleccionados. Las carpetas perderán su contenido."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cargando = true);
      // Borrar Recursos
      for (var id in _recursosSeleccionados) {
        await _apiService.borrarRecurso(widget.token, id);
      }
      // Borrar Álbumes
      for (var id in _albumesSeleccionados) {
        await _apiService.borrarAlbum(widget.token, id);
      }
      _limpiarSeleccion();
      _cargarDatos();
    }
  }

  void _accionMover() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          height: 300,
          child: Column(
            children: [
              Text("Mover a...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<Album>>(
                  future: _apiService.obtenerMisAlbumes(widget.token),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                    final carpetas = snapshot.data!;
                    
                    return ListView.builder(
                      itemCount: carpetas.length + 1,
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: Icon(Icons.home, color: Colors.blue),
                            title: Text("Inicio"),
                            onTap: () => Navigator.pop(ctx, null),
                          );
                        }
                        final album = carpetas[index - 1];
                        // Evitar mover una carpeta dentro de sí misma
                        if (_albumesSeleccionados.contains(album.id)) return SizedBox.shrink();
                        if (album.id == widget.parentId) return SizedBox.shrink(); 
                        
                        return ListTile(
                          leading: Icon(Icons.folder, color: Colors.amber),
                          title: Text(album.nombre),
                          onTap: () => Navigator.pop(ctx, album.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((destinoId) async {
        setState(() => _cargando = true);
        
        // Mover Recursos
        for (var id in _recursosSeleccionados) {
          await _apiService.moverRecurso(widget.token, id, widget.parentId, destinoId); 
        }
        // Mover Carpetas (Opcional, si lo implementaste en backend)
        for (var id in _albumesSeleccionados) {
           await _apiService.moverAlbum(widget.token, id, destinoId);
        }

        _limpiarSeleccion();
        _cargarDatos();
    });
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
      bool exito = await _apiService.subirRecurso(widget.token, file, tipo, idAlbum: widget.parentId);
      if (exito) {
        bool borrar = await ApiService.getBorrarAlSubir();
        String mensaje = "Archivo subido correctamente";
        if (borrar) {
          try {
            if (await file.exists()) {
              await file.delete(); // Borramos el archivo local
              mensaje = "Subido y borrado del dispositivo para ahorrar espacio";
            }
          } catch (e) {
            print("No se pudo borrar el archivo local: $e");
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
        }
        _cargarDatos(); // Recargar la galería
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al subir")));
        }
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

  void _aplicarFiltro(String categoria) {
    List<Recurso> temp;
    switch (categoria) {
      case "Imagen": temp = _todosLosRecursos.where((r) => r.tipo == "IMAGEN").toList(); break;
      case "Videos": temp = _todosLosRecursos.where((r) => r.tipo == "VIDEO").toList(); break;
      case "Musica": temp = _todosLosRecursos.where((r) => r.tipo == "AUDIO").toList(); break;
      case "Otros": temp = _todosLosRecursos.where((r) => !["IMAGEN", "VIDEO", "AUDIO"].contains(r.tipo)).toList(); break;
      case "Todos": default: temp = List.from(_todosLosRecursos); break;
    }
    setState(() {
      _filtroSeleccionado = categoria;
      _recursosFiltrados = temp;
    });
  }

  void _cerrarSesion() async {
    await _apiService.logout();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  // --- WIDGET CARPETA ACTUALIZADO CON SELECCIÓN ---
  Widget _buildCarpeta(Album album) {
    final isSelected = _albumesSeleccionados.contains(album.id);

    return GestureDetector(
      onLongPress: () => _toggleSeleccionAlbum(album.id),
      onTap: () {
        if (_modoSeleccion) {
          _toggleSeleccionAlbum(album.id);
        } else {
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
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Contenido Carpeta
          Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder, size: 60, color: Colors.amber),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    album.nombre, 
                    style: TextStyle(fontWeight: FontWeight.bold), 
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Overlay de selección
          if (_modoSeleccion)
            Positioned(
              top: 4,
              right: 4,
              child: isSelected
                  ? Icon(Icons.check_circle, color: Colors.blue, size: 24)
                  : Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 24),
            ),
        ],
      ),
    );
  }

  Widget _getIconoArchivo(Recurso recurso) {
    IconData icono;
    Color color;
    if (recurso.tipo == "VIDEO") { icono = Icons.play_circle_fill; color = Colors.redAccent; }
    else if (recurso.tipo == "AUDIO") { icono = Icons.audiotrack; color = Colors.purpleAccent; }
    else { icono = Icons.insert_drive_file; color = Colors.blueGrey; }

    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 40, color: color),
          SizedBox(height: 4),
          Text(recurso.tipo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalSeleccionados = _recursosSeleccionados.length + _albumesSeleccionados.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1, // Un poco de sombra queda bien
        iconTheme: const IconThemeData(color: Colors.black), // Iconos negros por defecto

        // --- TÍTULO CON MENÚ DESPLEGABLE ---
        title: _buscando 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                hintText: "Buscar archivo...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: (val) => _aplicarFiltros(),
            )
          : (_modoSeleccion 
              ? Text("$totalSeleccionados seleccionados", style: TextStyle(color: Colors.black))
              : PopupMenuButton<String>(
                  // offset: Mueve el menú un poco abajo para que no tape el título
                  offset: Offset(0, 45), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  
                  // ESTO ES LO QUE SE VE EN LA BARRA (Texto + Flecha)
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.nombreCarpeta, 
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.black),
                    ],
                  ),
                  
                  // ESTAS SON LAS OPCIONES QUE CAEN HACIA ABAJO
                  onSelected: (value) {
                    if (value == 'config') Navigator.push(context,MaterialPageRoute(builder: (context) => const ConfiguracionScreen()),).then((_) {_cargarDatos(); });
                    if (value == 'refresh') _cargarDatos();
                    if (value == 'logout') _cerrarSesion();
                    if (value == 'gestionar_amistades')Navigator.push(context, MaterialPageRoute(builder: (context) => const GestionarAmistadesScreen()));
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    // Opción 1: Configurar IP
                    const PopupMenuItem<String>(
                      value: 'config',
                      child: Row(
                        children: [
                          Icon(Icons.settings, color: Colors.blueGrey),
                          SizedBox(width: 10),
                          Text('Configuración'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>( // --- NUEVA OPCIÓN ---
                      value: 'gestionar_amistades',
                      child: ListTile(
                        leading: Icon(Icons.person_search),
                        title: Text('Gestionar Amistades'),
                      ),
                    ),
                    // Opción 2: Refrescar
                    const PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.blueGrey),
                          SizedBox(width: 10),
                          Text('Refrescar Datos'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(), // Una línea separadora queda elegante
                    // Opción 3: Cerrar Sesión
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                )
            ),
        
        // --- BOTÓN IZQUIERDO (Back / Cancelar / Cerrar selección) ---
        leading: _buscando 
          ? IconButton(
              icon: Icon(Icons.arrow_back), 
              onPressed: () {
                setState(() {
                  _buscando = false;
                  _searchController.clear();
                  _aplicarFiltros();
                });
              }
            )
          : (_modoSeleccion 
              ? IconButton(icon: Icon(Icons.close), onPressed: _limpiarSeleccion)
              : (widget.parentId != null ? BackButton() : null)
            ),

        // --- ACCIONES DERECHA (Solo búsqueda y orden) ---
        actions: _modoSeleccion 
          ? [
              if (_recursosSeleccionados.isNotEmpty)
                IconButton(icon: Icon(Icons.download), onPressed: _accionDescargarSeleccion),
              IconButton(icon: Icon(Icons.drive_file_move), onPressed: _accionMover),
              IconButton(icon: Icon(Icons.delete), onPressed: _accionBorrar),
            ]
          : [
              // Si no estamos buscando, mostramos la lupa y el orden
              if (!_buscando) ...[
                IconButton(
                  icon: Icon(Icons.search), 
                  onPressed: () => setState(() => _buscando = true)
                ),
                IconButton(
                  icon: Icon(Icons.sort), 
                  onPressed: _mostrarMenuOrden
                ),
                // Aquí ya NO ponemos los botones de config/logout porque están en el título
              ]
            ],
      ),
      body: Column(
        children: [
          // Filtros
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
                    onSelected: (bool selected) { if (selected) _aplicarFiltro(cat); },
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

          // Grid
          Expanded(
            child: _cargando 
              ? Center(child: CircularProgressIndicator())
              : (_albumesVisibles.isEmpty && _recursosFiltrados.isEmpty)
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: Colors.grey), SizedBox(height: 10), Text("Carpeta vacía")]))
                  : GridView.builder(
                      padding: EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _albumesFiltrados.length + _recursosFiltrados.length,
                      itemBuilder: (context, index) {
                        if (index < _albumesFiltrados.length) {
                          return _buildCarpeta(_albumesFiltrados[index]);
                        } else {
                          final recurso = _recursosFiltrados[index - _albumesFiltrados.length];
                          final isSelected = _recursosSeleccionados.contains(recurso.id);
                          final urlImagen = "${ApiService.baseUrl}${recurso.urlThumbnail}";
                          return GestureDetector(
                            onLongPress: () => _toggleSeleccionRecurso(recurso.id),
                            onTap: () {
                              if (_modoSeleccion) {
                                _toggleSeleccionRecurso(recurso.id);
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleRecursoScreen(recurso: recurso, token: widget.token))).then((_) => _cargarDatos());
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: (recurso.esImagen || recurso.esVideo)
                                    ? CachedNetworkImage(
                                        imageUrl: urlImagen,
                                        httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                                        errorWidget: (context, url, error) => Icon(Icons.error),
                                      )
                                    : _getIconoArchivo(recurso),
                                ),
                                if (recurso.tipo == "VIDEO")
                                  Center(child: Container(decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(Icons.play_arrow, color: Colors.white, size: 30))),
                                if (_modoSeleccion)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue.withOpacity(0.4) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                                    ),
                                    child: isSelected 
                                      ? Icon(Icons.check_circle, color: Colors.white, size: 30)
                                      : Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.radio_button_unchecked, color: Colors.white))),
                                  ),
                              ],
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
        mainAxisSize: MainAxisSize.min,
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
            child: _cargando ? CircularProgressIndicator(color: Colors.white) : Icon(Icons.file_upload),
          ),
        ],
      ),
    );
  }
}