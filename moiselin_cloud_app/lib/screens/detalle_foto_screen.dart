import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; 
import '../models/recursos.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

class DetalleRecursoScreen extends StatefulWidget {
  final Recurso recurso;
  final String token;

  const DetalleRecursoScreen({Key? key, required this.recurso, required this.token}) : super(key: key);

  @override
  _DetalleRecursoScreenState createState() => _DetalleRecursoScreenState();
}

class _DetalleRecursoScreenState extends State<DetalleRecursoScreen> {
  final DownloadService _downloadService = DownloadService();
  final ApiService _apiService = ApiService();
  
  // Variables locales para edición (para ver los cambios al instante)
  late String _nombreActual;
  late DateTime? _fechaRealActual;

  // Controladores Multimedia
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Future<String>? _futureTexto;

  @override
  void initState() {
    super.initState();
    // Inicializamos con los datos originales
    _nombreActual = widget.recurso.nombre;
    _fechaRealActual = widget.recurso.fechaReal;
    
    _inicializarRecurso();
  }

  void _inicializarRecurso() {
    String urlCompleta = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";
    
    switch (widget.recurso.tipo) {
      case "VIDEO": _inicializarVideo(urlCompleta); break;
      case "AUDIO": _inicializarAudio(urlCompleta); break;
      case "ARCHIVO": _futureTexto = _cargarTexto(urlCompleta); break;
    }
  }

  void _descargarArchivo() async {

    // URL base
    String urlCompleta = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";
    
    // Nombre con extensión correcta
    String nombreFinal = widget.recurso.nombre;
    String extension = "";
    switch (widget.recurso.tipo) {
      case "VIDEO": extension = ".mp4"; break;
      case "IMAGEN": extension = ".jpg"; break;
      case "AUDIO": extension = ".mp3"; break;
      case "ARCHIVO": extension = ".pdf"; break; // O .txt según veas
    }
    if (!nombreFinal.toLowerCase().endsWith(extension)) {
      nombreFinal += extension;
    }

    // Llamamos al servicio (ahora devuelve String?)
    String? rutaGuardado = await _downloadService.descargarYGuardar(
      urlCompleta, 
      nombreFinal, 
      widget.recurso.tipo, 
      widget.token
    );

    if (mounted) {
      if (rutaGuardado != null) {
        // ÉXITO: Mostramos la ruta real
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guardado en:\n$rutaGuardado"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5), // Más tiempo para leer
          )
        );
      } else {
        // ERROR
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al descargar. Revisa permisos."),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  Future<void> _inicializarVideo(String url) async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: {"Authorization": "Bearer ${widget.token}"});
    try {
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (ctx, msg) => Center(child: Text("Error video: $msg", style: TextStyle(color: Colors.white))),
      );
      setState(() {});
    } catch (e) { print("Error video: $e"); }
  }

  void _inicializarAudio(String url) {
    _audioPlayer.onPlayerStateChanged.listen((s) { if(mounted) setState(() => _isPlayingAudio = s == PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((d) { if(mounted) setState(() => _duration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if(mounted) setState(() => _position = p); });
    _audioPlayer.setSourceUrl(url);
  }

  Future<String> _cargarTexto(String url) async {
    try {
      final r = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer ${widget.token}"});
      return r.statusCode == 200 ? r.body : "Error ${r.statusCode}";
    } catch (e) { return "Error: $e"; }
  }

  // --- FUNCIONES DE EDICIÓN ---

  void _editarNombre() {
    final controller = TextEditingController(text: _nombreActual);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cambiar nombre"),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar")),
          TextButton(
            onPressed: () async {
              final nuevoNombre = controller.text.trim();
              if (nuevoNombre.isNotEmpty && nuevoNombre != _nombreActual) {
                Navigator.pop(ctx);
                bool ok = await _apiService.editarNombre(widget.token, widget.recurso.id, nuevoNombre);
                if (ok) setState(() => _nombreActual = nuevoNombre);
              } else {
                Navigator.pop(ctx);
              }
            }, 
            child: Text("Guardar")
          ),
        ],
      ),
    );
  }

  void _editarFechaReal() async {
    final initialDate = _fechaRealActual ?? DateTime.now();
    // 1. Elegir Día
    final fecha = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (fecha != null) {
      // 2. Elegir Hora
      final hora = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (hora != null) {
        final nuevaFechaReal = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
        
        // Guardar
        bool ok = await _apiService.editarFecha(widget.token, widget.recurso.id, nuevaFechaReal);
        if (ok) setState(() => _fechaRealActual = nuevaFechaReal);
      }
    }
  }

  void _borrarRecurso() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Eliminar archivo"),
        content: Text("¿Seguro que quieres eliminarlo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      bool exito = await _apiService.borrarRecurso(widget.token, widget.recurso.id);
      if (exito && mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CONTENIDO
          Center(child: _buildContenido()),

          // BOTÓN ATRÁS
          Positioned(
            top: 40, left: 10,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // PANEL DESLIZANTE
          DraggableScrollableSheet(
            initialChildSize: 0.1,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 5, margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Text("Detalles", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),

                    // --- SECCIÓN EDITABLE ---
                    _buildEditableRow(Icons.title, "Nombre", _nombreActual, _editarNombre),
                    Divider(),
                    _buildInfoRow(Icons.category, "Tipo", widget.recurso.tipo),
                    Divider(),
                    _buildInfoRow(Icons.cloud_upload, "Fecha Subida", DateFormat('dd/MM/yyyy HH:mm').format(widget.recurso.fechaSubida)),
                    Divider(),
                    // FECHA REAL EDITABLE
                    _buildEditableRow(
                      Icons.camera_alt, 
                      "Fecha Captura (Real)", 
                      _fechaRealActual != null 
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_fechaRealActual!)
                          : "Sin fecha asignada", 
                      _editarFechaReal
                    ),

                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(Icons.share, "Compartir", Colors.blue, () {}),
                        _buildActionButton(Icons.delete, "Eliminar", Colors.red, _borrarRecurso),
                        _buildActionButton(Icons.download, "Descargar", Colors.green, _descargarArchivo),
                      ],
                    ),
                    SizedBox(height: 50),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Row Normal (Solo lectura)
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Row Editable (Con lápiz)
  Widget _buildEditableRow(IconData icon, String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: onEdit,
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // Helpers multimedia (Copiados de tu versión anterior, resumidos aquí)
  Widget _buildContenido() {
    final url = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}"; // Recuerda el parche HTTP en init
    switch (widget.recurso.tipo) {
      case "IMAGEN": return InteractiveViewer(child: CachedNetworkImage(imageUrl: url, httpHeaders: {"Authorization": "Bearer ${widget.token}"}, fit: BoxFit.contain));
      case "VIDEO": return (_chewieController != null && _videoPlayerController!.value.isInitialized) ? Chewie(controller: _chewieController!) : CircularProgressIndicator();
      case "AUDIO": return _buildReproductorAudio();
      case "ARCHIVO": return _buildVisorTexto();
      default: return Text("Formato no soportado", style: TextStyle(color: Colors.white));
    }
  }

  Widget _buildReproductorAudio() {
    return Container(
      width: 300, height: 250,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.music_note, size: 60, color: Colors.amber),
        SizedBox(height: 20),
        Text(_nombreActual, style: TextStyle(color: Colors.white), textAlign: TextAlign.center), // Nombre actualizado
        Slider(value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()), min: 0, max: _duration.inSeconds.toDouble(), onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt()))),
        IconButton(icon: Icon(_isPlayingAudio ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40), onPressed: () => _isPlayingAudio ? _audioPlayer.pause() : _audioPlayer.play(UrlSource("${ApiService.baseUrl}${widget.recurso.urlVisualizacion}")))
      ]),
    );
  }

  Widget _buildVisorTexto() {
    return FutureBuilder<String>(future: _futureTexto, builder: (ctx, s) => s.hasData ? Container(color: Colors.white, padding: EdgeInsets.all(10), child: SingleChildScrollView(child: Text(s.data!))) : CircularProgressIndicator());
  }
}