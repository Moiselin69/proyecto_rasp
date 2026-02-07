import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

// Asegúrate de que estos imports apunten a tus archivos reales
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
  // Variables locales para edición
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
    _nombreActual = widget.recurso.nombre;
    _fechaRealActual = widget.recurso.fechaReal;
    _inicializarRecurso();
  }

  void _inicializarRecurso() {
    String urlCompleta = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";

    switch (widget.recurso.tipo) {
      case "VIDEO":
        _inicializarVideo(urlCompleta);
        break;
      case "AUDIO":
        _inicializarAudio(urlCompleta);
        break;
      case "ARCHIVO": // Asumiendo que es texto plano o similar
        _futureTexto = _cargarTexto(urlCompleta);
        break;
    }
  }

  // --- FUNCIONES MULTIMEDIA ---

  Future<void> _inicializarVideo(String url) async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {"Authorization": "Bearer ${widget.token}"},
    );
    try {
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (ctx, msg) => Center(child: Text("Error video: $msg", style: const TextStyle(color: Colors.white))),
      );
      if (mounted) setState(() {});
    } catch (e) {
      print("Error inicializando video: $e");
    }
  }

  void _inicializarAudio(String url) {
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlayingAudio = s == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    
    // Configurar la fuente pero no reproducir automáticamente
    _audioPlayer.setSourceUrl(url); 
  }

  Future<String> _cargarTexto(String url) async {
    try {
      final r = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer ${widget.token}"});
      return r.statusCode == 200 ? r.body : "Error ${r.statusCode}";
    } catch (e) {
      return "Error de conexión: $e";
    }
  }

  // --- FUNCIONES DE ACCIÓN (Compartir, Descargar, Borrar, Editar) ---

  void _mostrarDialogoCompartir() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Compartir con...'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<dynamic>>(
              future: ApiService.verAmigos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No tienes amigos para compartir.'));
                }

                final amigos = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: amigos.length,
                  itemBuilder: (context, index) {
                    final amigo = amigos[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Text(amigo['nombre'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text('${amigo['nombre']} ${amigo['apellidos'] ?? ''}'),
                      subtitle: Text(amigo['correo_electronico']),
                      onTap: () {
                        Navigator.pop(context);
                        _enviarRecurso(amigo['id'], amigo['nombre']);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enviarRecurso(int idAmigo, String nombreAmigo) async {
    try {
      // Ajuste para obtener el ID dependiendo de si tu modelo es una clase o un mapa
      final int idRecurso = widget.recurso.id; 

      // Asumiendo que ApiService.compartirRecurso devuelve un String con el mensaje
      String mensaje = await ApiService.compartirRecurso(idRecurso, idAmigo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: mensaje.toLowerCase().contains('solicitud') ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _descargarArchivo() async {
    String? directorioDestino = await FilePicker.platform.getDirectoryPath();
    if (directorioDestino == null) return;

    String urlCompleta = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";
    String nombreFinal = widget.recurso.nombre;

    // Añadir extensión si falta (lógica básica)
    if (path.extension(nombreFinal).isEmpty) {
      switch (widget.recurso.tipo) {
        case "VIDEO": nombreFinal += ".mp4"; break;
        case "IMAGEN": nombreFinal += ".jpg"; break;
        case "AUDIO": nombreFinal += ".mp3"; break;
        case "ARCHIVO": nombreFinal += ".pdf"; break;
      }
    }

    String? resultado = await _downloadService.descargarYGuardar(
      urlCompleta,
      nombreFinal,
      widget.recurso.tipo,
      widget.token,
      rutaPersonalizada: directorioDestino,
    );

    if (mounted && resultado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Guardado correctamente."), backgroundColor: Colors.green),
      );
    }
  }

  void _borrarRecurso() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar archivo"),
        content: const Text("¿Seguro que quieres eliminarlo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // Necesitarás tener este método en tu ApiService
      // bool exito = await _apiService.borrarRecurso(widget.token, widget.recurso.id);
      // Por ahora simulo éxito si no tienes la función implementada:
      bool exito = true; 
      
      if (exito && mounted) {
        Navigator.pop(context); // Vuelve a la galería
      }
    }
  }

  void _editarNombre() {
    final controller = TextEditingController(text: _nombreActual);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cambiar nombre"),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              final nuevoNombre = controller.text.trim();
              if (nuevoNombre.isNotEmpty && nuevoNombre != _nombreActual) {
                Navigator.pop(ctx);
                // bool ok = await _apiService.editarNombre(widget.token, widget.recurso.id, nuevoNombre);
                bool ok = true; // Simulación
                if (ok) setState(() => _nombreActual = nuevoNombre);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _editarFechaReal() async {
    final initialDate = _fechaRealActual ?? DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (fecha != null) {
      if (!mounted) return;
      final hora = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (hora != null) {
        final nuevaFechaReal = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
        // bool ok = await _apiService.editarFecha(widget.token, widget.recurso.id, nuevaFechaReal);
        bool ok = true; // Simulación
        if (ok) setState(() => _fechaRealActual = nuevaFechaReal);
      }
    }
  }

  // --- DISPOSE ---
  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. CONTENIDO CENTRAL (Imagen, Video, Audio)
          Center(child: _buildContenidoMultimedia()),

          // 2. BOTÓN ATRÁS (Arriba izquierda)
          Positioned(
            top: 40,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. PANEL DESLIZANTE DE INFORMACIÓN
          DraggableScrollableSheet(
            initialChildSize: 0.15, // Altura inicial (un poco visible)
            minChildSize: 0.1,      // Mínimo visible
            maxChildSize: 0.6,      // Máximo extendido
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Barra superior pequeña para indicar que se desliza
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    
                    const Text("Detalles del Archivo", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Filas de Información
                    _buildEditableRow(Icons.title, "Nombre", _nombreActual, _editarNombre),
                    const Divider(),
                    _buildInfoRow(Icons.category, "Tipo", widget.recurso.tipo),
                    const Divider(),
                    _buildInfoRow(Icons.cloud_upload, "Subido el", DateFormat('dd/MM/yyyy HH:mm').format(widget.recurso.fechaSubida)),
                    const Divider(),
                    _buildEditableRow(
                      Icons.camera_alt, 
                      "Fecha Captura", 
                      _fechaRealActual != null ? DateFormat('dd/MM/yyyy HH:mm').format(_fechaRealActual!) : "Sin asignar", 
                      _editarFechaReal
                    ),

                    const SizedBox(height: 30),

                    // Botones de Acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(Icons.share, "Compartir", Colors.blue, _mostrarDialogoCompartir),
                        _buildActionButton(Icons.delete, "Eliminar", Colors.red, _borrarRecurso),
                        _buildActionButton(Icons.download, "Descargar", Colors.green, _descargarArchivo),
                      ],
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildContenidoMultimedia() {
    final url = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}"; 
    
    switch (widget.recurso.tipo) {
      case "IMAGEN":
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: {"Authorization": "Bearer ${widget.token}"},
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
          ),
        );
      case "VIDEO":
        if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
          return Chewie(controller: _chewieController!);
        } else {
          return const CircularProgressIndicator();
        }
      case "AUDIO":
        return _buildReproductorAudio();
      case "ARCHIVO":
        return _buildVisorTexto();
      default:
        return const Text("Vista previa no disponible", style: TextStyle(color: Colors.white));
    }
  }

  Widget _buildReproductorAudio() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 60, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            _nombreActual, 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), 
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Slider(
            activeColor: Colors.amber,
            inactiveColor: Colors.grey,
            value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
            min: 0,
            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
            onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
          ),
          IconButton(
            icon: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 60),
            onPressed: () {
              if (_isPlayingAudio) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play(UrlSource("${ApiService.baseUrl}${widget.recurso.urlVisualizacion}"));
              }
            },
          ),
          Text(
            "${_position.toString().split('.').first} / ${_duration.toString().split('.').first}",
            style: const TextStyle(color: Colors.grey),
          )
        ],
      ),
    );
  }

  Widget _buildVisorTexto() {
    return FutureBuilder<String>(
      future: _futureTexto,
      builder: (ctx, s) {
        if (s.hasData) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(child: Text(s.data!, style: const TextStyle(color: Colors.black))),
          );
        }
        return const CircularProgressIndicator();
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(IconData icon, String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: onEdit,
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}