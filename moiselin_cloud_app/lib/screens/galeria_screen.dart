import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io'; 
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart'; 

import '../main.dart';
// --- SERVICIOS ---
import '../services/api_service.dart'; // Para constantes estáticas y logout
import '../services/recurso_api.dart'; // Servicio de recursos
import '../services/album_api.dart';   // Servicio de álbumes
import '../services/persona_api.dart'; // Servicio de usuarios/admin
import '../services/download_service.dart';
import '../services/upload_manager.dart';

// --- MODELOS ---
import '../models/recursos.dart';
import "../models/album.dart";

// --- WIDGETS Y PANTALLAS ---
import '../widgets/selector_fotos_propio.dart';
import 'login_screen.dart';
import 'detalle_foto_screen.dart';
import 'gestionar_amistades_screen.dart';
import 'configuracion_screen.dart';
import 'compartidos_screen.dart';
import 'papelera_screen.dart';
import 'admin_screen.dart';
import 'selector_amigo_screen.dart';
import 'upload_progress_screen.dart';

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

class _GaleriaScreenState extends State<GaleriaScreen> with RouteAware, SingleTickerProviderStateMixin{
  // Instancias de servicios
  final ApiService _apiService = ApiService(); // Mantenemos para logout y configs
  final RecursoApiService _recursoApi = RecursoApiService();
  final AlbumApiService _albumApi = AlbumApiService();
  final PersonaApiService _personaApi = PersonaApiService();
  final DownloadService _downloadService = DownloadService();

  int _columnas = 3;
  int _columnasBase = 3;
  bool _haciendoZoom = false;
  bool _cargando = true;
  bool _esAdmin = false;
  bool _subiendo = false;
  double _progreso = 0.0;
  String _filtroSeleccionado = "Todos"; 
  List<Recurso> _todosLosRecursos = []; 
  List<Recurso> _recursosFiltrados = []; 
  List<Album> _albumesVisibles = [];
  List<Album> _albumesFiltrados = [];
  bool _buscando = false;
  final TextEditingController _searchController = TextEditingController();
  String _filtroOrden = "subida_desc";
  String _mensajeSubida = "Subiendo...";
  DateTimeRange? _rangoFechas;
  String _tipoFechaFiltro = 'real';
  bool _modoSeleccion = false;
  Set<int> _recursosSeleccionados = {};
  Set<int> _albumesSeleccionados = {};
  final List<String> _categorias = ["Todos", "Favoritos", "Imagen", "Videos", "Musica", "Otros"];
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final UploadManager _uploadManager = UploadManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _cargarDatos();
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _blinkController = AnimationController(vsync: this,duration: const Duration(milliseconds: 800),);
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(_blinkController);
    _uploadManager.addListener(_handleUploadStateChange);
    _checkAdmin();
  }

  void _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final albumes = await _albumApi.obtenerMisAlbumes(widget.token);
      List<Recurso> recursos;
      if (widget.parentId != null) {
        recursos = await _albumApi.verContenidoAlbum(widget.token, widget.parentId!);
      } else {
        recursos = await _recursoApi.obtenerMisRecursos();
      }

      if (mounted) {
        setState(() {
          _albumesVisibles = albumes.where((a) => a.idAlbumPadre == widget.parentId && !a.estaEnPapelera).toList();
          if (widget.parentId != null) {
            _todosLosRecursos = recursos.where((r) => !r.estaEnPapelera) .toList(); 
          } else {
            _todosLosRecursos = recursos.where((r) => r.idAlbumPadre == null && !r.estaEnPapelera).toList();
          }
          _aplicarFiltros();
          _cargando = false;
        });
      }
    } catch (e) {
      print("Error en _cargarDatos: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _handleUploadStateChange() {
    if (_uploadManager.isUploading) {
      if (!_blinkController.isAnimating) _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      if(mounted) _blinkController.value = 1.0; // Reset opacidad
      // Opcional: Recargar datos si terminó una subida
      if (_uploadManager.tasks.any((t) => t.status == UploadStatus.completed)) {
         _cargarDatos();
      }
    }
    if (mounted) setState(() {}); 
  }

  void _handleUploadButton() {
    // CASO 1: YA ESTÁ SUBIENDO -> IR A PANTALLA PROGRESO
    if (_uploadManager.isUploading || _uploadManager.tasks.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadProgressScreen(currentAlbumId: widget.parentId),
        ),
      );
      return;
    }

    // CASO 2: NO ESTÁ SUBIENDO -> MOSTRAR TU MENÚ DE OPCIONES
    _mostrarOpcionesSubida();
  }

  void _checkAdmin() async {
    // PersonaApi gestiona el token internamente
    bool admin = await _personaApi.soyAdmin();
    if (mounted) {
      setState(() {
        _esAdmin = admin;
      });
    }
  }

  void _aplicarFiltros() {
    List<Recurso> listaRecursos = List.from(_todosLosRecursos);
    List<Album> listaAlbumes = List.from(_albumesVisibles);

    // 1. FILTRO DE TEXTO
    String texto = _searchController.text.toLowerCase();
    if (texto.isNotEmpty) {
      listaRecursos = listaRecursos.where((r) => r.nombre.toLowerCase().contains(texto)).toList();
      listaAlbumes = listaAlbumes.where((a) => a.nombre.toLowerCase().contains(texto)).toList();
    }

    // 2. FILTRO DE FECHAS
    if (_rangoFechas != null) {
      DateTime inicio = DateUtils.dateOnly(_rangoFechas!.start);
      DateTime fin = DateUtils.dateOnly(_rangoFechas!.end).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

      listaRecursos = listaRecursos.where((r) {
        DateTime? fechaEvaluar = (_tipoFechaFiltro == 'real') ? r.fechaReal : r.fechaSubida;
        if (fechaEvaluar == null) return false;
        return fechaEvaluar.isAfter(inicio.subtract(const Duration(seconds: 1))) && 
               fechaEvaluar.isBefore(fin.add(const Duration(seconds: 1)));
      }).toList();

      listaAlbumes = listaAlbumes.where((a) {
        return a.fechaCreacion.isAfter(inicio.subtract(const Duration(seconds: 1))) && 
               a.fechaCreacion.isBefore(fin.add(const Duration(seconds: 1)));
      }).toList();
    }

    // 3. FILTRO DE CATEGORÍA
    if (_filtroSeleccionado != "Todos") {
      switch (_filtroSeleccionado) {
        case "Favoritos": listaRecursos = listaRecursos.where((r) => r.favorito == true).toList(); break;
        case "Imagen": listaRecursos = listaRecursos.where((r) => r.tipo == "IMAGEN").toList(); break;
        case "Videos": listaRecursos = listaRecursos.where((r) => r.tipo == "VIDEO").toList(); break;
        case "Musica": listaRecursos = listaRecursos.where((r) => r.tipo == "AUDIO").toList(); break;
        case "Otros": listaRecursos = listaRecursos.where((r) => !["IMAGEN", "VIDEO", "AUDIO"].contains(r.tipo)).toList(); break;
      }
    }

    // 4. ORDENACIÓN
    int compararAlbumes(Album a, Album b, bool asc) {
       return asc ? a.fechaCreacion.compareTo(b.fechaCreacion) : b.fechaCreacion.compareTo(a.fechaCreacion);
    }

    switch (_filtroOrden) {
      case 'subida_desc':
        listaRecursos.sort((a, b) => b.fechaSubida.compareTo(a.fechaSubida));
        listaAlbumes.sort((a, b) => compararAlbumes(a, b, false)); 
        break;
      case 'subida_asc':
        listaRecursos.sort((a, b) => a.fechaSubida.compareTo(b.fechaSubida));
        listaAlbumes.sort((a, b) => compararAlbumes(a, b, true));
        break;
      case 'real_desc': 
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

    setState(() {
      _recursosFiltrados = listaRecursos;
      _albumesFiltrados = listaAlbumes;
    });
  }

  void _mostrarSelectorFechas() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filtrar por fecha", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      ChoiceChip(label: const Text("Fecha Captura (Real)"), selected: _tipoFechaFiltro == 'real', onSelected: (val) => setModalState(() => _tipoFechaFiltro = 'real')),
                      const SizedBox(width: 10),
                      ChoiceChip(label: const Text("Fecha Subida"), selected: _tipoFechaFiltro == 'subida', onSelected: (val) => setModalState(() => _tipoFechaFiltro = 'subida')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(_rangoFechas == null ? "Seleccionar Rango" : "${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}"),
                      onPressed: () async {
                        final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)), initialDateRange: _rangoFechas, locale: const Locale('es', 'ES'));
                        if (picked != null) {
                          setState(() => _rangoFechas = picked);
                          setModalState(() {});
                          Navigator.pop(context);
                          _aplicarFiltros();
                        }
                      },
                    ),
                  ),
                  if (_rangoFechas != null)
                    Center(child: TextButton(onPressed: () { setState(() => _rangoFechas = null); Navigator.pop(context); _aplicarFiltros(); }, child: const Text("Borrar filtro de fecha", style: TextStyle(color: Colors.red)))),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _mostrarMenuOrden() {
    showModalBottomSheet(context: context, builder: (ctx) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [ const Text("Ordenar por", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Divider(), _buildOpcionOrden("📅 Fecha de Subida (Reciente)", "subida_desc"), _buildOpcionOrden("📅 Fecha de Subida (Antiguo)", "subida_asc"), _buildOpcionOrden("📷 Fecha Captura (Reciente)", "real_desc"), _buildOpcionOrden("🔤 Nombre (A-Z)", "nombre_asc")])));
  }

  Widget _buildOpcionOrden(String texto, String valor) {
    bool seleccionado = _filtroOrden == valor;
    return ListTile(title: Text(texto, style: TextStyle(fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal, color: seleccionado ? Colors.blue : Colors.black)), trailing: seleccionado ? const Icon(Icons.check, color: Colors.blue) : null, onTap: () { setState(() => _filtroOrden = valor); _aplicarFiltros(); Navigator.pop(context); });
  }

  void _accionDescargarSeleccion() async {
    if (_recursosSeleccionados.isEmpty) return;
    String? directorioDestino = await FilePicker.platform.getDirectoryPath();
    if (directorioDestino == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Guardando en: $directorioDestino...")));
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
        
        // El DownloadService aún necesita el token como string para los headers
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Se han guardado $exitoCount archivos."), backgroundColor: Colors.green));
    }
  }

  void _toggleSeleccionRecurso(int id) {
    setState(() {
      if (_recursosSeleccionados.contains(id)) _recursosSeleccionados.remove(id); else _recursosSeleccionados.add(id);
      _actualizarModoSeleccion();
    });
  }
  
  void _toggleSeleccionAlbum(int id) {
    setState(() {
      if (_albumesSeleccionados.contains(id)) _albumesSeleccionados.remove(id); else _albumesSeleccionados.add(id);
      _actualizarModoSeleccion();
    });
  }
  
  void _actualizarModoSeleccion() { _modoSeleccion = _recursosSeleccionados.isNotEmpty || _albumesSeleccionados.isNotEmpty; }
  
  void _limpiarSeleccion() { setState(() { _recursosSeleccionados.clear(); _albumesSeleccionados.clear(); _modoSeleccion = false; }); }

  void _accionBorrar() async {
    int total = _recursosSeleccionados.length + _albumesSeleccionados.length;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text("Mover a papelera $total elementos"), content: const Text("Los archivos seleccionados se moverán a la papelera."), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red)))]));

    if (confirm == true) {
      setState(() => _cargando = true);
      
      String mensajeFinal = "";
      bool huboError = false;

      // 1. Borrar Recursos
      if (_recursosSeleccionados.isNotEmpty) {
        final res = await _recursoApi.borrarLote(_recursosSeleccionados.toList());
        
        if (res['exito']) {
          mensajeFinal = res['mensaje'];
        } else {
          // SI FALLA: Guardamos el error y marcamos flag
          mensajeFinal = res['mensaje']; // "No tienes permisos..."
          huboError = true;
        }
      }

      // 2. Borrar Álbumes (Solo si no hubo error crítico antes)
      if (!huboError) {
        for (var id in _albumesSeleccionados) {
          await _albumApi.borrarAlbum(widget.token, id);
        }
      }
      
      if (mounted) {
        setState(() => _cargando = false); // Quitamos carga

        if (!huboError) {
          // ÉXITO
          _limpiarSeleccion();
          _cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeFinal.isEmpty ? "Elementos borrados" : mensajeFinal))
          );
        } else {
          // ERROR (Rojo)
          // No limpiamos selección para que el usuario vea qué falló
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeFinal), 
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            )
          );
        }
      }
    }
  }

  void _accionMover() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 300,
          child: Column(
            children: [
              const Text("Mover a...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<Album>>(
                  future: _albumApi.obtenerMisAlbumes(widget.token), // AlbumApi con token
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final carpetas = snapshot.data!;
                    
                    return ListView.builder(
                      itemCount: carpetas.length + 1,
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          return ListTile(leading: const Icon(Icons.home, color: Colors.blue), title: const Text("Inicio"), onTap: () => Navigator.pop(ctx, null));
                        }
                        final album = carpetas[index - 1];
                        if (_albumesSeleccionados.contains(album.id)) return const SizedBox.shrink();
                        if (album.id == widget.parentId) return const SizedBox.shrink(); 
                        
                        return ListTile(leading: const Icon(Icons.folder, color: Colors.amber), title: Text(album.nombre), onTap: () => Navigator.pop(ctx, album.id));
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
        
        // Mover Recursos (RecursoApi sin token)
        if (_recursosSeleccionados.isNotEmpty) {
           await _recursoApi.moverLote(_recursosSeleccionados.toList(), destinoId);
        }
        
        // Mover Carpetas (AlbumApi con token)
        for (var id in _albumesSeleccionados) {
           await _albumApi.moverAlbum(widget.token, id, destinoId);
        }

        if (mounted) {
          _limpiarSeleccion();
          _cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Elementos movidos")));
        }
    });
  }

  void _mostrarOpcionesSubida() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
            ),
            // He cambiado el texto de "¿Qué deseas subir?" a "¿Qué deseas añadir?" para que encaje mejor
            const Text("¿Qué deseas añadir?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // --- OPCIÓN NUEVA: CREAR CARPETA ---
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.create_new_folder, color: Colors.purple)
              ),
              title: const Text("Nueva Carpeta"),
              subtitle: const Text("Crear un álbum para organizar"),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarCrearAlbumDialog(); // Esta función ya la tienes en tu código
              }
            ),
            
            const SizedBox(height: 10),

            // --- OPCIÓN FOTOS ---
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library, color: Colors.blue)
              ),
              title: const Text("Fotos y Vídeos"),
              subtitle: const Text("Galería (Permite borrar original)"),
              onTap: () {
                Navigator.pop(ctx);
                _subirDesdeGaleria();
              }
            ),
            
            const SizedBox(height: 10),
            
            // --- OPCIÓN ARCHIVOS ---
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.insert_drive_file, color: Colors.orange)
              ),
              title: const Text("Archivos"),
              subtitle: const Text("Documentos, PDF, Audio..."),
              onTap: () {
                Navigator.pop(ctx);
                _subirDesdeArchivos();
              }
            ),
            const SizedBox(height: 20)
          ]
        )
      )
    );
  }

  void _mostrarAlertaPermisos(String mensaje) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Falta permiso"), content: Text(mensaje), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")), TextButton(onPressed: () { Navigator.pop(ctx); PhotoManager.openSetting(); }, child: const Text("Abrir Ajustes"))]));
  }

  Future<void> _subirDesdeGaleria() async {
    // 1. Seleccionar fotos
    final List<AssetEntity>? assets = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => const SelectorFotosPropio(maxSelection: 100), 
        fullscreenDialog: true
      )
    );
    
    if (assets == null || assets.isEmpty) return;

    // 2. Mostrar feedback rápido mientras procesamos
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Procesando ${assets.length} archivos para subir..."))
      );
    }

    // 3. Convertir Assets a Files (asíncrono pero rápido)
    List<File> archivosParaSubir = [];
    for (var asset in assets) {
      File? file = await asset.file;
      if (file != null) {
        archivosParaSubir.add(file);
      }
    }

    // 4. ¡LA CLAVE! Delegar al Manager
    // Esto activa isUploading = true, inicia el parpadeo y la cola paralela
    if (archivosParaSubir.isNotEmpty) {
      _uploadManager.addFiles(archivosParaSubir, widget.parentId);
    }
  }

  Future<void> _subirDesdeArchivos() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) { _mostrarAlertaPermisos("Se requiere acceso a la galería."); return; }
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true, 
      type: FileType.any
    );
    
    if (result == null) return;

    // 3. Convertir a File
    List<File> files = result.paths
        .where((path) => path != null)
        .map((path) => File(path!))
        .toList();

    // 4. Delegar al Manager
    if (files.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Añadidos ${files.length} archivos a la cola."))
      );
      _uploadManager.addFiles(files, widget.parentId);
    }
  }

  void _mostrarCrearAlbumDialog() {
    final TextEditingController _controller = TextEditingController();
    String? _errorTexto; 
    bool _botonDesactivado = true; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void _validarNombre(String texto) {
              final nombreLimpio = texto.trim();
              if (nombreLimpio.isEmpty) { setStateDialog(() { _errorTexto = null; _botonDesactivado = true; }); return; }
              bool existe = _albumesVisibles.any((album) => album.nombre.toLowerCase() == nombreLimpio.toLowerCase());
              setStateDialog(() { if (existe) { _errorTexto = "Ya existe una carpeta con este nombre"; _botonDesactivado = true; } else { _errorTexto = null; _botonDesactivado = false; } });
            }

            return AlertDialog(
              title: const Text('Nueva Carpeta'),
              content: TextField(controller: _controller, autofocus: true, decoration: InputDecoration(hintText: "Nombre de la carpeta", errorText: _errorTexto), onChanged: (val) => _validarNombre(val)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(onPressed: _botonDesactivado ? null : () { Navigator.pop(context); _realizarCreacionAlbum(_controller.text.trim()); }, child: const Text('Crear')),
              ],
            );
          },
        );
      },
    );
  }

  void _realizarCreacionAlbum(String nombre) async {
    setState(() => _cargando = true);
    // AlbumApi con token
    final res = await _albumApi.crearAlbum(widget.token, nombre, "", widget.parentId);
    
    if (res['exito'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carpeta creada'), backgroundColor: Colors.green));
      _cargarDatos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mensaje'] ?? 'Error al crear carpeta'), backgroundColor: Colors.red));
      setState(() => _cargando = false);
    }
  }
  
  void _aplicarFiltro(String categoria) {
    List<Recurso> temp;
    switch (categoria) {
      case "Favoritos": temp = _todosLosRecursos.where((r) => r.favorito == true).toList(); break;
      case "Imagen": temp = _todosLosRecursos.where((r) => r.tipo == "IMAGEN").toList(); break;
      case "Videos": temp = _todosLosRecursos.where((r) => r.tipo == "VIDEO").toList(); break;
      case "Musica": temp = _todosLosRecursos.where((r) => r.tipo == "AUDIO").toList(); break;
      case "Otros": temp = _todosLosRecursos.where((r) => !["IMAGEN", "VIDEO", "AUDIO"].contains(r.tipo)).toList(); break;
      case "Todos": default: temp = List.from(_todosLosRecursos); break;
    }
    setState(() { _filtroSeleccionado = categoria; _recursosFiltrados = temp; });
  }

  void _cerrarSesion() async {
    await _apiService.logout();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
  }

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
            MaterialPageRoute(builder: (_) => GaleriaScreen(token: widget.token, parentId: album.id, nombreCarpeta: album.nombre))
          );
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent, 
              borderRadius: BorderRadius.circular(10), 
              border: isSelected ? Border.all(color: Colors.blue, width: 2) : null
            ),
            // CORRECCIÓN AQUÍ: Usamos LayoutBuilder para que el icono se encoja si no cabe
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculamos el tamaño disponible
                double altoDisponible = constraints.maxHeight;
                
                // Le damos al icono un 60% del alto disponible, con un tope de 60px
                double iconSize = altoDisponible * 0.6;
                if (iconSize > 60) iconSize = 60;
                if (iconSize < 24) iconSize = 24; // Mínimo de seguridad

                // Calculamos tamaño de fuente proporcional (opcional, para que no se vea gigante)
                double fontSize = iconSize * 0.25;
                if (fontSize < 10) fontSize = 10;
                if (fontSize > 14) fontSize = 14;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [ 
                    Icon(Icons.folder, size: iconSize, color: Colors.amber), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0), 
                      child: Text(
                        album.nombre, 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize), 
                        overflow: TextOverflow.ellipsis, // Esto pone los puntos suspensivos ...
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      )
                    )
                  ]
                );
              }
            ),
          ),
          if (_modoSeleccion) 
            Positioned(
              top: 4, 
              right: 4, 
              child: isSelected 
                ? const Icon(Icons.check_circle, color: Colors.blue, size: 24) 
                : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 24)
            ),
        ],
      ),
    );
  }

  void _mostrarDialogoCompartir(List<int> idsRecursos, List<int> idsAlbumes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que se ajuste mejor al contenido
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (ctx) {
        // CORRECCIÓN: Añadimos SingleChildScrollView y SafeArea
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Una pequeña barra gris para indicar que se puede deslizar (opcional pero estético)
                  Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
                  ),
                  
                  const Text("Compartir selección", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // OPCIÓN 1: APPS EXTERNAS
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle),
                      child: const Icon(Icons.share, color: Colors.green),
                    ),
                    title: const Text("Enviar a otras apps"),
                    subtitle: const Text("WhatsApp, Instagram..."),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final url = await _recursoApi.crearEnlacePublico(idsRecursos, idsAlbumes, null, 7);
                      if (url != null) {
                        Share.share("Te comparto estos archivos: $url"); 
                      }
                    },
                  ),
                  
                  const Divider(),

                  // OPCIÓN 2: INTERNO
                  ListTile(
                    leading: Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(color: Colors.blue[100], shape: BoxShape.circle),
                       child: const Icon(Icons.people, color: Colors.blue),
                    ),
                    title: const Text("Compartir con amigo"),
                    subtitle: const Text("Usuarios de Moiselin Cloud"),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final idAmigo = await Navigator.push(context, MaterialPageRoute(builder: (_) => SelectorAmigoScreen(token: widget.token)));
                      
                      if (idAmigo != null) {
                        int exitos = 0;
                        int errores = 0;

                        // A. COMPARTIR RECURSOS
                        for(int idR in idsRecursos) {
                           final bool exito = await _recursoApi.compartirRecurso(idR, idAmigo);
                           if (exito) exitos++; else errores++;
                        }

                        // B. COMPARTIR ÁLBUMES
                        for(int idA in idsAlbumes) {
                           final res = await _albumApi.invitarAAlbum(widget.token, idA, idAmigo, 'COLABORADOR');
                           if(res['exito'] == true) exitos++; else errores++;
                        }

                        if (mounted) {
                          if (errores == 0 && exitos > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Todo compartido correctamente"), backgroundColor: Colors.green));
                          } else if (exitos > 0 && errores > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Algunos elementos ya estaban compartidos o fallaron"), backgroundColor: Colors.orange));
                          } else if (exitos == 0 && errores > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Ya compartido o sin permisos"), backgroundColor: Colors.red));
                          }
                        }
                      }
                    },
                  ),

                  const Divider(),

                  // OPCIÓN 3: ENLACE PÚBLICO
                  ListTile(
                    leading: Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                       child: const Icon(Icons.link, color: Colors.orange),
                    ),
                    title: const Text("Crear enlace de descarga"),
                    subtitle: const Text("Con contraseña o expiración"),
                    onTap: () {
                       Navigator.pop(ctx);
                       _mostrarDialogoConfigurarEnlace(idsRecursos, idsAlbumes);
                    },
                  ),
                  
                  // Espacio extra al final para evitar cortes con bordes curvos o gestos
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  // Este es el método auxiliar para la Opción 3 (tu antiguo diálogo)
  void _mostrarDialogoConfigurarEnlace(List<int> idsRecursos, List<int> idsAlbumes) {
    bool usarPassword = false;
    String password = "";
    int expiracion = 0; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Configurar enlace"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Se generará un enlace para ${idsRecursos.length + idsAlbumes.length} elementos."),
                  const SizedBox(height: 15),
                  CheckboxListTile(title: const Text("Proteger con contraseña"), value: usarPassword, onChanged: (val) => setDialogState(() => usarPassword = val!)),
                  if (usarPassword) TextField(decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()), onChanged: (val) => password = val),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: expiracion,
                    decoration: const InputDecoration(labelText: "Caducidad"),
                    items: const [DropdownMenuItem(value: 0, child: Text("Nunca")), DropdownMenuItem(value: 1, child: Text("1 Día")), DropdownMenuItem(value: 7, child: Text("1 Semana")), DropdownMenuItem(value: 30, child: Text("1 Mes"))],
                    onChanged: (val) => setDialogState(() => expiracion = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  String? url = await _recursoApi.crearEnlacePublico(
                    idsRecursos, 
                    idsAlbumes, 
                    usarPassword && password.isNotEmpty ? password : null, 
                    expiracion
                  );

                  if (url != null && mounted) {
                    _mostrarDialogoUrl(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error creando enlace")));
                  }
                },
                child: const Text("Generar"),
              ),
            ],
          );
        }
      ),
    );
  }

void _mostrarDialogoUrl(String url) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("¡Enlace listo!"), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [ 
            const Icon(Icons.check_circle, color: Colors.green, size: 50), 
            const SizedBox(height: 10), 
            SelectableText(url, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
            const SizedBox(height: 5), 
            const Text("Copia este enlace y envíalo.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
          ]
        ), 
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.copy), 
            label: const Text("Copiar"), 
            onPressed: () { 
              Clipboard.setData(ClipboardData(text: url)); 
              Navigator.pop(ctx); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enlace copiado"))); 
            }
          ),
          // Botón extra para compartir directamente el enlace generado
          TextButton(
            child: const Text("Compartir"),
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(url);
            }
          )
        ]
      )
    );
  }

  Widget _getIconoArchivo(Recurso recurso) {
    IconData icono;
    Color color;
    if (recurso.tipo == "VIDEO") { icono = Icons.play_circle_fill; color = Colors.redAccent; }
    else if (recurso.tipo == "AUDIO") { icono = Icons.audiotrack; color = Colors.purpleAccent; }
    else { icono = Icons.insert_drive_file; color = Colors.blueGrey; }

    return Container(color: Colors.grey[200], child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icono, size: 40, color: color), SizedBox(height: 4), Text(recurso.tipo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]));
  }

  @override
  Widget build(BuildContext context) {
    int totalSeleccionados = _recursosSeleccionados.length + _albumesSeleccionados.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: _buscando 
          ? TextField(controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(hintText: "Buscar archivo...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)), onChanged: (val) => _aplicarFiltros())
          : (_modoSeleccion 
              ? Text("$totalSeleccionados seleccionados", style: const TextStyle(color: Colors.black))
              : PopupMenuButton<String>(
                  offset: const Offset(0, 45), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(widget.nombreCarpeta, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), const Icon(Icons.arrow_drop_down, color: Colors.black)]),
                  onSelected: (value) {
                    if (value == 'admin_panel') Navigator.push(context, MaterialPageRoute(builder: (context) => AdminScreen(token: widget.token)));
                    if (value == 'config') Navigator.push(context,MaterialPageRoute(builder: (context) => const ConfiguracionScreen())).then((_) => _cargarDatos());
                    if (value == 'refresh') _cargarDatos();
                    if (value == 'logout') _cerrarSesion();
                    if (value == 'gestionar_amistades') Navigator.push(context, MaterialPageRoute(builder: (context) => const GestionarAmistadesScreen()));
                    if (value == 'compartidos') Navigator.push(context,MaterialPageRoute(builder: (context) => const CompartidosScreen()));
                    if (value == 'papelera') Navigator.push(context, MaterialPageRoute(builder: (context) => PapeleraScreen(token: widget.token))).then((_) => _cargarDatos());
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    if (_esAdmin) const PopupMenuItem<String>(value: 'admin_panel', child: ListTile(leading: Icon(Icons.admin_panel_settings, color: Colors.indigo), title: Text('Administración', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), contentPadding: EdgeInsets.zero)),
                    if (_esAdmin) const PopupMenuDivider(),
                    const PopupMenuItem<String>(value: 'config', child: Row(children: [Icon(Icons.settings, color: Colors.blueGrey), SizedBox(width: 10), Text('Configuración')])),
                    const PopupMenuItem<String>(value: 'gestionar_amistades', child: ListTile(leading: Icon(Icons.person_search), title: Text('Gestionar Amistades'))),
                    const PopupMenuItem<String>(value: 'compartidos', child: ListTile(leading: Icon(Icons.folder_shared), title: Text('Compartidos conmigo'))),
                    const PopupMenuItem<String>(value: 'papelera', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.grey), title: Text('Papelera'), contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem<String>(value: 'refresh', child: Row(children: [Icon(Icons.refresh, color: Colors.blueGrey), SizedBox(width: 10), Text('Refrescar Datos')])),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 10), Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent))])),
                  ],
                )
            ),
        leading: _buscando 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { setState(() { _buscando = false; _searchController.clear(); _aplicarFiltros(); }); })
          : (_modoSeleccion 
              ? IconButton(icon: const Icon(Icons.close), onPressed: _limpiarSeleccion)
              : (widget.parentId != null ? const BackButton() : null)
            ),
        actions: _modoSeleccion 
          ? [
              IconButton(icon: const Icon(Icons.share), onPressed: () {
                if (_recursosSeleccionados.isNotEmpty || _albumesSeleccionados.isNotEmpty) {
                  _mostrarDialogoCompartir(_recursosSeleccionados.toList(), _albumesSeleccionados.toList());
                }
              }),
              if (_recursosSeleccionados.isNotEmpty) IconButton(icon: const Icon(Icons.download), onPressed: _accionDescargarSeleccion),
              IconButton(icon: const Icon(Icons.drive_file_move), onPressed: _accionMover),
              IconButton(icon: const Icon(Icons.delete), onPressed: _accionBorrar),
            ]
          : [
              if (!_buscando) ...[
                IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _buscando = true)),
                IconButton(icon: Icon(Icons.calendar_month, color: _rangoFechas != null ? Colors.blue : Colors.black), onPressed: _mostrarSelectorFechas),
                IconButton(icon: const Icon(Icons.sort), onPressed: _mostrarMenuOrden),
              ]
            ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // FILTROS
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        labelStyle: TextStyle(color: isSelected ? Colors.blue[900] : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        checkmarkColor: Colors.blue[900],
                        shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
                      ),
                    );
                  },
                ),
              ),
              if (_rangoFechas != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  child: Row(children: [InputChip(avatar: const Icon(Icons.calendar_today, size: 16, color: Colors.blue), label: Text("${_tipoFechaFiltro == 'real' ? 'Captura' : 'Subida'}: ${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}", style: TextStyle(color: Colors.blue[900], fontSize: 13)), onDeleted: () { setState(() { _rangoFechas = null; _aplicarFiltros(); }); }, deleteIconColor: Colors.red, backgroundColor: Colors.blue[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blue.withOpacity(0.3))))]),
                ),

              Expanded(
                child: _cargando 
                  ? const Center(child: CircularProgressIndicator())
                  : (_albumesVisibles.isEmpty && _recursosFiltrados.isEmpty)
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.search_off, size: 60, color: Colors.grey), SizedBox(height: 10), Text("Carpeta vacía")]))
                    : GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onScaleStart: (details) => setState(() { _columnasBase = _columnas; _haciendoZoom = true; }),
                        onScaleUpdate: (details) { if (details.scale != 1.0) setState(() { double nuevas = _columnasBase / details.scale; _columnas = nuevas.round().clamp(2, 6); }); },
                        onScaleEnd: (details) => setState(() => _haciendoZoom = false),
                        child: GridView.builder(
                          physics: _haciendoZoom ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _columnas, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8),
                          itemCount: _albumesFiltrados.length + _recursosFiltrados.length,
                          itemBuilder: (context, index) {
                             if (index < _albumesFiltrados.length) {
                               return _buildCarpeta(_albumesFiltrados[index]);
                             } else {
                               final recurso = _recursosFiltrados[index - _albumesFiltrados.length];
                               final isSelected = _recursosSeleccionados.contains(recurso.id);
                               final urlImagen = "${ApiService.baseUrl}/recurso/archivo/${recurso.id}?size=small";
                               
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
                                        // 2. Envolvemos en Hero para la animación de transición
                                        ? Hero(
                                            tag: "recurso_${recurso.id}", // Tag único para conectar con la otra pantalla
                                            child: CachedNetworkImage(
                                              imageUrl: urlImagen,
                                              
                                              httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                                              fit: BoxFit.cover,
                                            
                                              memCacheWidth: 300,
                                              placeholder: (context, url) => Container(color: Colors.grey[200]),
                                              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          )
                                        : _getIconoArchivo(recurso),
                                    ),
                                     Positioned(
                                       top: 5, left: 5,
                                       child: GestureDetector(
                                         onTap: () async {
                                           // Usamos RecursoApi (sin token)
                                           bool exito = await _recursoApi.toggleFavorito(recurso.id, !recurso.favorito);
                                           if (exito) { setState(() { recurso.favorito = !recurso.favorito; if (_filtroSeleccionado == "Favoritos") _aplicarFiltros(); }); }
                                         },
                                         child: Icon(recurso.favorito ? Icons.favorite : Icons.favorite_border, color: recurso.favorito ? Colors.red : Colors.white70, size: 20),
                                       ),
                                     ),
                                     if (recurso.tipo == "VIDEO") Center(child: Container(decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white, size: 30))),
                                     if (_modoSeleccion) Positioned(top: 4, right: 4, child: Container(decoration: BoxDecoration(color: isSelected ? Colors.blue.withOpacity(0.4) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: isSelected ? Border.all(color: Colors.blue, width: 3) : null), child: isSelected ? const Icon(Icons.check_circle, color: Colors.white, size: 30) : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.radio_button_unchecked, color: Colors.white))))),
                                   ],
                                 ),
                               );
                             }
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (_subiendo)
            Positioned(
              bottom: 80, left: 20, right: 20,
              child: Card(elevation: 10, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(_mensajeSubida, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)), const SizedBox(width: 10), Text("${(_progreso * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))]), const SizedBox(height: 10), LinearProgressIndicator(value: _progreso, minHeight: 8, borderRadius: BorderRadius.circular(5), backgroundColor: Colors.grey[200], color: Colors.blue)]))),
            ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _uploadManager.isUploading ? _blinkAnimation.value : 1.0,
            child: FloatingActionButton(
              onPressed: _handleUploadButton,
              // El color SÍ usa Colors
              backgroundColor: _uploadManager.isUploading ? Colors.orange : Colors.blue,
              // EL ERROR ESTABA AQUÍ: Usamos Icons.upload_file (no Colors)
              child: Icon(
                _uploadManager.isUploading ? Icons.upload_file : Icons.add,
              ),
            ),
          );
        },
      ),
    );
  }
}
