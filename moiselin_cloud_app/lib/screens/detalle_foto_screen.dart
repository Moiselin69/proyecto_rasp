import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path; 

import '../models/recursos.dart';
import '../models/metadatos.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/recurso_api.dart'; // <--- Nuevo servicio

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'selector_amigo_screen.dart';
import 'package:flutter/services.dart';

class DetalleRecursoScreen extends StatefulWidget {
  final Recurso recurso;
  final String token;

  const DetalleRecursoScreen({Key? key, required this.recurso, required this.token}) : super(key: key);

  @override
  _DetalleRecursoScreenState createState() => _DetalleRecursoScreenState();
}

class _DetalleRecursoScreenState extends State<DetalleRecursoScreen> {
  // Instancias de los nuevos servicios
  final RecursoApiService _recursoApi = RecursoApiService();
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
  MetadatosFoto? _meta;

  @override
  void initState() {
    super.initState();
    _nombreActual = widget.recurso.nombre;
    _fechaRealActual = widget.recurso.fechaReal;
    _cargarMetadatos();
    _inicializarRecurso();
  }

  Widget _buildInfoExif() {
    if (_meta == null) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 10),
        const Divider(),
        const Text("Datos EXIF", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),

        // Fila de Datos Técnicos (ISO, Apertura, etc.)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (_meta!.iso != null) _datoChip(Icons.iso, "ISO ${_meta!.iso}"),
            if (_meta!.apertura != null) _datoChip(Icons.camera, "${_meta!.apertura}"),
            if (_meta!.velocidad != null) _datoChip(Icons.shutter_speed, "${_meta!.velocidad}"),
          ],
        ),
        
        const SizedBox(height: 10),

        if (_meta!.dispositivo != null)
          ListTile(
            leading: const Icon(Icons.phone_iphone),
            title: Text(_meta!.dispositivo!),
            subtitle: const Text("Dispositivo"),
            dense: true,
          ),

        // MAPA (Solo si hay GPS)
        if (_meta!.latitud != null && _meta!.longitud != null)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300)
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_meta!.latitud!, _meta!.longitud!),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tuapp.moiselin',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_meta!.latitud!, _meta!.longitud!),
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _datoChip(IconData icon, String texto) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: Colors.black54,
      padding: const EdgeInsets.all(0),
    );
  }

  void _cargarMetadatos() async {
    // 1. Optimización: Si no es imagen o video, no buscamos EXIF
    if (widget.recurso.tipo != "IMAGEN" && widget.recurso.tipo != "VIDEO") return;

    // 2. Llamada a la API (El servicio gestiona el token internamente)
    final datos = await _recursoApi.obtenerMetadatos(widget.recurso.id);
    
    // 3. Actualizar la interfaz
    if (mounted) {
      setState(() {
        _meta = datos;
      });
    }
  }

  void _inicializarRecurso() {
    String urlCompleta = "${ApiService.baseUrl}/recurso/archivo/${widget.recurso.id}";

    switch (widget.recurso.tipo) {
      case "VIDEO":
        _inicializarVideo(urlCompleta);
        break;
      case "AUDIO":
        _inicializarAudio(urlCompleta);
        break;
      case "ARCHIVO":
        _futureTexto = _cargarTexto(urlCompleta);
        break;
    }
  }

  // --- FUNCIONES MULTIMEDIA ---

  Future<void> _inicializarVideo(String url) async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {"Authorization": "Bearer ${widget.token}"}, // El player necesita el token aquí explícitamente
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
    
    // Para audios protegidos, AudioPlayer a veces necesita headers o un proxy.
    // Si la URL es pública o el token va en query param funciona directo.
    // Si no, considera usar UrlSource con headers si la librería lo soporta o descargar primero.
    _audioPlayer.setSourceUrl(url); 
  }

  Future<String> _cargarTexto(String url) async {
    try {
      // Aquí seguimos usando http directo porque necesitamos el body raw
      final r = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer ${widget.token}"});
      return r.statusCode == 200 ? r.body : "Error ${r.statusCode}";
    } catch (e) {
      return "Error de conexión: $e";
    }
  }

  // --- FUNCIONES DE ACCIÓN ---

  void _mostrarDialogoCompartir(Recurso recurso) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Compartir recurso", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // OPCIÓN 1: APPS EXTERNAS
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle),
                  child: const Icon(Icons.share, color: Colors.green),
                ),
                title: const Text("Enviar a otras apps"),
                subtitle: const Text("WhatsApp, Instagram, Telegram..."),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Creamos un enlace público temporal (7 días)
                  final url = await _recursoApi.crearEnlacePublico([recurso.id], [], null, 7);
                  if (url != null) {
                    // Compartimos el texto con el enlace
                    Share.share("Mira este archivo: $url");
                  }
                },
              ),
              
              const Divider(),

              // OPCIÓN 2: INTERNO (Amigos)
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
                     bool ok = await _recursoApi.compartirRecurso(recurso.id, idAmigo);
                     if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? "Compartido con éxito" : "Error al compartir"),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ));
                    }
                  }
                },
              ),

              const Divider(),

              // OPCIÓN 3: ENLACE PÚBLICO (Avanzado)
              ListTile(
                leading: Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                   child: const Icon(Icons.link, color: Colors.orange),
                ),
                title: const Text("Opciones de enlace"),
                subtitle: const Text("Contraseña, expiración..."),
                onTap: () {
                   Navigator.pop(ctx);
                   _mostrarDialogoConfigurarEnlace(recurso);
                },
              ),
            ],
          ),
        );
      }
    );
  }
  void _mostrarDialogoConfigurarEnlace(Recurso recurso) {
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
                  const Text("Generar enlace de descarga para este archivo."),
                  const SizedBox(height: 15),
                  CheckboxListTile(
                    title: const Text("Proteger con contraseña"),
                    value: usarPassword,
                    onChanged: (val) => setDialogState(() => usarPassword = val!)
                  ),
                  if (usarPassword)
                    TextField(
                      decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()),
                      onChanged: (val) => password = val,
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: expiracion,
                    decoration: const InputDecoration(labelText: "Caducidad"),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text("Nunca")),
                      DropdownMenuItem(value: 1, child: Text("1 Día")),
                      DropdownMenuItem(value: 7, child: Text("1 Semana")),
                      DropdownMenuItem(value: 30, child: Text("1 Mes"))
                    ],
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
                    [recurso.id], 
                    [], 
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

  void _descargarArchivo() async {
    String? directorioDestino = await FilePicker.platform.getDirectoryPath();
    if (directorioDestino == null) return;

    String urlCompleta = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";
    String nombreFinal = _nombreActual; 

    // Añadir extensión si falta
    if (path.extension(nombreFinal).isEmpty) {
      switch (widget.recurso.tipo) {
        case "VIDEO": nombreFinal += ".mp4"; break;
        case "IMAGEN": nombreFinal += ".jpg"; break;
        case "AUDIO": nombreFinal += ".mp3"; break;
        case "ARCHIVO": nombreFinal += ".pdf"; break;
      }
    }

    // DownloadService se mantiene igual
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
        content: const Text("Se moverá a la papelera de reciclaje."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // Usamos RecursoApiService
      bool exito = await _recursoApi.borrarRecurso(widget.recurso.id);
      
      if (exito && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Archivo movido a la papelera")),
         );
        Navigator.pop(context); // Vuelve a la galería
      } else if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Error al eliminar el archivo"), backgroundColor: Colors.red),
         );
      }
    }
  }

  // --- LÓGICA DE RENOMBRADO SEGURA Y LIMITADA ---
  void _editarNombre() {
    String extension = path.extension(_nombreActual); 
    String nombreSinExt = path.basenameWithoutExtension(_nombreActual);

    final controller = TextEditingController(text: nombreSinExt);
    bool cargando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Cambiar nombre"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Edita el nombre sin modificar la extensión.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: "Nombre",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Text(
                          extension,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  if (cargando) const Padding(padding: EdgeInsets.only(top: 20), child: LinearProgressIndicator()),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: cargando ? null : () async {
                    String nuevoBase = controller.text.trim();
                    if (nuevoBase.isEmpty) return;
                    
                    String nuevoNombreCompleto = "$nuevoBase$extension";
                    
                    if (nuevoNombreCompleto == _nombreActual) {
                      Navigator.pop(context);
                      return;
                    }

                    setStateDialog(() => cargando = true);

                    // 1. INTENTO DE RENOMBRADO (Usando RecursoApiService)
                    int codigo = await _recursoApi.editarNombre(
                        widget.recurso.id, 
                        nuevoNombreCompleto, 
                        reemplazar: false
                    );

                    setStateDialog(() => cargando = false);

                    if (codigo == 200) {
                      // ÉXITO
                      Navigator.pop(context);
                      setState(() => _nombreActual = nuevoNombreCompleto);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Nombre actualizado")),
                      );
                    } 
                    else if (codigo == 409) {
                      // 2. CONFLICTO: PREGUNTAR AL USUARIO
                      bool? reemplazar = await showDialog<bool>(
                        context: context,
                        builder: (subCtx) => AlertDialog(
                          title: const Text("Nombre duplicado"),
                          content: Text("Ya existe un archivo llamado '$nuevoNombreCompleto' en esta carpeta.\n\n¿Quieres reemplazarlo?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(subCtx, false), child: const Text("Cancelar")),
                            TextButton(onPressed: () => Navigator.pop(subCtx, true), child: const Text("Reemplazar", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );

                      if (reemplazar == true) {
                        setStateDialog(() => cargando = true);
                        
                        // 3. REINTENTO CON REEMPLAZO FORZADO
                        int cod2 = await _recursoApi.editarNombre(
                            widget.recurso.id, 
                            nuevoNombreCompleto, 
                            reemplazar: true
                        );
                        
                        if (cod2 == 200) {
                           Navigator.pop(context);
                           setState(() => _nombreActual = nuevoNombreCompleto);
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("Archivo reemplazado y renombrado")),
                           );
                        } else {
                           Navigator.pop(context);
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("Error al reemplazar el archivo")),
                           );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Error desconocido al renombrar")),
                      );
                    }
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
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
        
        // Llamada usando RecursoApiService
        bool ok = await _recursoApi.editarFecha(widget.recurso.id, nuevaFechaReal);
        
        if (ok) {
           setState(() => _fechaRealActual = nuevaFechaReal);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Error al actualizar la fecha")),
           );
        }
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

  // --- CONSTRUCCIÓN DE LA UI (IGUAL QUE ANTES) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _buildContenidoMultimedia()),

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

          DraggableScrollableSheet(
            initialChildSize: 0.15,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
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
                    _buildInfoExif(),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(Icons.share, "Compartir", Colors.blue, () => _mostrarDialogoCompartir(widget.recurso) ),
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
    final url = "${ApiService.baseUrl}/recurso/archivo/${widget.recurso.id}";
    
    switch (widget.recurso.tipo) {
      case "IMAGEN":
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
          tag: "recurso_${widget.recurso.id}",
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: {"Authorization": "Bearer ${widget.token}"},
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
          ),
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