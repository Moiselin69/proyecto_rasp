import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../models/recursos.dart';
import '../services/api_service.dart';

class DetalleRecursoScreen extends StatefulWidget {
  final Recurso recurso;
  final String token;

  const DetalleRecursoScreen({Key? key, required this.recurso, required this.token}) : super(key: key);

  @override
  _DetalleRecursoScreenState createState() => _DetalleRecursoScreenState();
}

class _DetalleRecursoScreenState extends State<DetalleRecursoScreen> {
  // Controladores de Video
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  // Controladores de Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Contenido de Texto
  Future<String>? _futureTexto;

  @override
  void initState() {
    super.initState();
    _inicializarRecurso();
  }

  void _inicializarRecurso() {
    // CAMBIO IMPORTANTE: Usamos tu método getUrlCompleta o concatenamos directamente
    // Usamos ApiService.baseUrl + recurso.urlVisualizacion
    final String urlCompleta = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";

    switch (widget.recurso.tipo) {
      case "VIDEO":
        _inicializarVideo(urlCompleta);
        break;
      case "AUDIO":
        _inicializarAudio(urlCompleta);
        break;
      case "ARCHIVO": 
        // Si el tipo es genérico "ARCHIVO", intentamos ver si es texto por su extensión (opcional)
        // O simplemente intentamos cargarlo como texto
        _futureTexto = _cargarTexto(urlCompleta);
        break;
    }
  }

  // --- LÓGICA DE VIDEO ---
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
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(child: Text("Error al reproducir video: $errorMessage", style: TextStyle(color: Colors.white)));
        },
      );
      setState(() {});
    } catch (e) {
      print("Error inicializando video: $e");
    }
  }

  // --- LÓGICA DE AUDIO ---
  void _inicializarAudio(String url) {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingAudio = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    
    // Configurar la fuente (UrlSource es parte de audioplayers ^5.x)
    // Nota: Si tu servidor requiere headers para el audio, AudioPlayers puede tener limitaciones.
    // A veces es necesario pasar el token en la URL (?token=...) si la librería no soporta headers.
    _audioPlayer.setSourceUrl(url); 
  }

  // --- LÓGICA DE TEXTO ---
  Future<String> _cargarTexto(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (response.statusCode == 200) {
        return response.body;
      } else {
        return "No se pudo cargar el archivo. Código: ${response.statusCode}";
      }
    } catch (e) {
      return "Error de conexión: $e";
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
    // CAMBIO: Usamos 'nombre' en lugar de 'nombreOriginal'
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(widget.recurso.nombre, style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _buildContenido(),
      ),
    );
  }

  Widget _buildContenido() {
    // Construimos la URL igual que arriba
    final String urlImagen = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";

    switch (widget.recurso.tipo) {
      case "IMAGEN":
        return InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: urlImagen,
            httpHeaders: {"Authorization": "Bearer ${widget.token}"},
            placeholder: (context, url) => CircularProgressIndicator(),
            errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
            fit: BoxFit.contain,
          ),
        );

      case "VIDEO":
        if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
          return Chewie(controller: _chewieController!);
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Cargando video...", style: TextStyle(color: Colors.white)),
            ],
          );
        }

      case "AUDIO":
        return _buildReproductorAudio();

      case "ARCHIVO":
        return _buildVisorTexto();

      default:
        return Text("Tipo de archivo no soportado", style: TextStyle(color: Colors.white));
    }
  }

  Widget _buildReproductorAudio() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      width: 300,
      height: 250,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 60, color: Colors.amber),
          SizedBox(height: 20),
          // CAMBIO: Usamos 'nombre'
          Text(
            widget.recurso.nombre, 
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), 
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis
          ),
          SizedBox(height: 20),
          Slider(
            activeColor: Colors.amber,
            inactiveColor: Colors.grey,
            min: 0,
            max: _duration.inSeconds.toDouble(),
            value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
            onChanged: (value) async {
              final position = Duration(seconds: value.toInt());
              await _audioPlayer.seek(position);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(_position), style: TextStyle(color: Colors.grey)),
              Text(_formatTime(_duration), style: TextStyle(color: Colors.grey)),
            ],
          ),
          SizedBox(height: 10),
          IconButton(
            iconSize: 60,
            icon: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.amber),
            onPressed: () async {
              if (_isPlayingAudio) {
                await _audioPlayer.pause();
              } else {
                final String url = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";
                await _audioPlayer.play(UrlSource(url));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisorTexto() {
    return FutureBuilder<String>(
      future: _futureTexto,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
          );
        } else {
          return Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8)
            ),
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              child: Text(
                snapshot.data ?? "Archivo vacío",
                style: TextStyle(color: Colors.black, fontSize: 14, fontFamily: 'Courier'),
              ),
            ),
          );
        }
      },
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}