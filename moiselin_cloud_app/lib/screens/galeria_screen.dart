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
import 'compartidos_screen.dart';
import 'papelera_screen.dart';
import 'admin_screen.dart';

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
  // --- NUEVA LÓGICA DE SELECCIÓN MIXTA ---
  bool _modoSeleccion = false;
  Set<int> _recursosSeleccionados = {};
  Set<int> _albumesSeleccionados = {}; // Nuevo set para carpetas

  final List<String> _categorias = ["Todos", "Imagen", "Videos", "Musica", "Otros"];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _checkAdmin();
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

  void _checkAdmin() async {
    bool admin = await _apiService.soyAdmin(widget.token);
    if (mounted) {
      setState(() {
        _esAdmin = admin;
      });
    }
  }

  void _aplicarFiltros() {
    // 1. Empezamos con la lista completa (copias para no modificar las originales)
    List<Recurso> listaRecursos = List.from(_todosLosRecursos);
    List<Album> listaAlbumes = List.from(_albumesVisibles);

    // ---------------------------------------------------------
    // 2. FILTRO DE TEXTO (BUSCADOR)
    // ---------------------------------------------------------
    String texto = _searchController.text.toLowerCase();
    if (texto.isNotEmpty) {
      listaRecursos = listaRecursos.where((r) => 
        r.nombre.toLowerCase().contains(texto)
      ).toList();
      listaAlbumes = listaAlbumes.where((a) => 
        a.nombre.toLowerCase().contains(texto)
      ).toList();
    }

    // ---------------------------------------------------------
    // 3. FILTRO DE FECHAS (NUEVO)
    // ---------------------------------------------------------
    if (_rangoFechas != null) {
      // Normalizamos las fechas del rango para cubrir el día completo
      // Inicio: 00:00:00 | Fin: 23:59:59
      DateTime inicio = DateUtils.dateOnly(_rangoFechas!.start);
      DateTime fin = DateUtils.dateOnly(_rangoFechas!.end).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

      listaRecursos = listaRecursos.where((r) {
        DateTime? fechaEvaluar;

        // Elegimos qué fecha usar según el chip seleccionado
        if (_tipoFechaFiltro == 'real') {
          fechaEvaluar = r.fechaReal;
        } else {
          fechaEvaluar = r.fechaSubida;
        }

        // Si el archivo no tiene esa fecha, decidimos si mostrarlo u ocultarlo.
        // Por lo general, se oculta si no cumple el criterio.
        if (fechaEvaluar == null) return false;

        return fechaEvaluar.isAfter(inicio.subtract(const Duration(seconds: 1))) && 
               fechaEvaluar.isBefore(fin.add(const Duration(seconds: 1)));
      }).toList();

      // (Opcional) Filtramos también álbumes por su fecha de creación para ser consistentes
      listaAlbumes = listaAlbumes.where((a) {
        return a.fechaCreacion.isAfter(inicio.subtract(const Duration(seconds: 1))) && 
               a.fechaCreacion.isBefore(fin.add(const Duration(seconds: 1)));
      }).toList();
    }

    // ---------------------------------------------------------
    // 4. FILTRO DE CATEGORÍA (IMAGEN, VIDEO...)
    // ---------------------------------------------------------
    if (_filtroSeleccionado != "Todos") {
      switch (_filtroSeleccionado) {
        case "Imagen":
          listaRecursos = listaRecursos.where((r) => r.tipo == "IMAGEN").toList();
          break;
        case "Videos":
          listaRecursos = listaRecursos.where((r) => r.tipo == "VIDEO").toList();
          break;
        case "Musica":
          listaRecursos = listaRecursos.where((r) => r.tipo == "AUDIO").toList();
          break;
        case "Otros":
          listaRecursos = listaRecursos.where((r) => !["IMAGEN", "VIDEO", "AUDIO"].contains(r.tipo)).toList();
          break;
      }
    }

    // ---------------------------------------------------------
    // 5. ORDENACIÓN
    // ---------------------------------------------------------
    
    // Función auxiliar para ordenar álbumes
    int compararAlbumes(Album a, Album b, bool asc) {
       return asc 
         ? a.fechaCreacion.compareTo(b.fechaCreacion)
         : b.fechaCreacion.compareTo(a.fechaCreacion);
    }

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
        // Para ordenar, si fechaReal es null, usamos una fecha muy antigua para que se vaya al final
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

    // ---------------------------------------------------------
    // 6. ACTUALIZAR VISTA
    // ---------------------------------------------------------
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
                  
                  // Selector de Tipo: Real vs Subida
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("Fecha Captura (Real)"),
                        selected: _tipoFechaFiltro == 'real',
                        onSelected: (val) => setModalState(() => _tipoFechaFiltro = 'real'),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Fecha Subida"),
                        selected: _tipoFechaFiltro == 'subida',
                        onSelected: (val) => setModalState(() => _tipoFechaFiltro = 'subida'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Botón para abrir el Calendario
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(_rangoFechas == null 
                          ? "Seleccionar Rango" 
                          : "${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}"),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)), // Hasta mañana por si acaso
                          initialDateRange: _rangoFechas,
                          locale: const Locale('es', 'ES'), // Si tienes configurado localizations
                        );
                        
                        if (picked != null) {
                          // Actualizamos el estado GLOBAL de la pantalla, no solo del modal
                          setState(() {
                            _rangoFechas = picked;
                          });
                          // Actualizamos el modal para que se vea el cambio de texto en el botón
                          setModalState(() {});
                          
                          Navigator.pop(context); // Cerramos el modal
                          _aplicarFiltros(); // Aplicamos filtro
                        }
                      },
                    ),
                  ),
                  
                  // Botón para Limpiar
                  if (_rangoFechas != null)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _rangoFechas = null;
                          });
                          Navigator.pop(context);
                          _aplicarFiltros();
                        },
                        child: const Text("Borrar filtro de fecha", style: TextStyle(color: Colors.red)),
                      ),
                    )
                ],
              ),
            );
          }
        );
      }
    );
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
        title: Text("Mover a papelera $total elementos"),
        content: const Text("Los archivos seleccionados se moverán a la papelera."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cargando = true);
      
      // 1. Borrar Recursos en LOTE (Rapidísimo)
      if (_recursosSeleccionados.isNotEmpty) {
        await _apiService.borrarLote(widget.token, _recursosSeleccionados.toList());
      }

      // 2. Borrar Álbumes (Para álbumes, como son menos frecuentes, 
      // podemos dejarlos en bucle o crear un endpoint de lote similar si quieres)
      // Por ahora mantenemos el bucle para carpetas
      for (var id in _albumesSeleccionados) {
        await _apiService.borrarAlbum(widget.token, id);
      }
      
      if (mounted) {
        _limpiarSeleccion();
        _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Elementos movidos a la papelera")));
      }
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
        if (_recursosSeleccionados.isNotEmpty) {
           await _apiService.moverLote(widget.token, _recursosSeleccionados.toList(), destinoId);
        }
        
        // 2. Mover Carpetas (Opcional, bucle o lote)
        for (var id in _albumesSeleccionados) {
           await _apiService.moverAlbum(widget.token, id, destinoId);
        }

        if (mounted) {
          _limpiarSeleccion();
          _cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Elementos movidos")));
        }
    });
  }

  String _obtenerTipoArchivo(String pathArchivo) {
    String ext = path.extension(pathArchivo).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif', '.bmp', '.tiff', '.tif'].contains(ext)) return 'IMAGEN';
    if (['.mp4', '.mov', '.avi', '.mkv', '.m4v', '.3gp', '.wmv', '.flv', '.webm'].contains(ext)) return 'VIDEO';
    if (['.mp3', '.wav', '.aac', '.flac', '.m4a', '.wma', '.ogg', '.aiff', '.caf'].contains(ext))return 'AUDIO';
    return 'ARCHIVO';
  }

  Future<void> _subirArchivoUniversal() async {
    // 1. Permitir múltiples archivos
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null && result.files.isNotEmpty) {
      
      // Inicializamos la UI de subida
      setState(() {
        _subiendo = true;
        _progreso = 0.0;
      });

      int total = result.files.length;
      int completados = 0;
      int errores = 0;
      
      // Bucle para procesar cada archivo uno a uno (Cola secuencial)
      for (int i = 0; i < total; i++) {
        var fileInfo = result.files[i];
        
        if (fileInfo.path == null) continue;
        
        File file = File(fileInfo.path!);
        String nombreArchivo = fileInfo.name;
        String tipo = _obtenerTipoArchivo(file.path);

        // Actualizamos el mensaje: "Subiendo 1 de 5: vacaciones.jpg"
        if (mounted) {
          setState(() {
            _mensajeSubida = "Subiendo ${i + 1} de $total:\n$nombreArchivo";
            _progreso = 0.0; // Reseteamos la barra para este archivo
          });
        }

        // --- Verificación de Duplicado ---
        bool existe = await _apiService.verificarDuplicado(widget.token, nombreArchivo, widget.parentId);
        bool reemplazar = false;
        
        if (existe) {
          // Pausamos el bucle para preguntar al usuario
          bool? confirmacion = await showDialog<bool>(
            context: context,
            barrierDismissible: false, // Obligamos a responder
            builder: (ctx) => AlertDialog(
              title: Text("Archivo duplicado (${i + 1}/$total)"),
              content: Text("'$nombreArchivo' ya existe.\n¿Deseas reemplazarlo?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false), // SALTAR este archivo
                  child: const Text("Saltar"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true), // REEMPLAZAR
                  child: const Text("Reemplazar"),
                ),
              ],
            ),
          );
          
          if (confirmacion == null) {
             // Si cierra el diálogo sin elegir, saltamos este archivo
             continue; 
          }
          if (confirmacion == false) {
             // Si elige "Saltar", no subimos y pasamos al siguiente
             continue; 
          }
          reemplazar = true;
        }

        // --- Subida por Chunks ---
        String? resultado = await _apiService.subirPorChunks(
          widget.token, 
          file, 
          tipo, 
          idAlbum: widget.parentId,
          reemplazar: reemplazar,
          onProgress: (p) {
            if (mounted) setState(() => _progreso = p);
          }
        );

        if (resultado != null && !resultado.contains("Error") && resultado != "DUPLICADO") {
          // ÉXITO
          completados++;
          bool borrar = await ApiService.getBorrarAlSubir();
          if (borrar) { try { if (await file.exists()) await file.delete(); } catch (e) {} }
        } else {
          // ERROR
          errores++;
          print("Error subiendo $nombreArchivo: $resultado");
        }
      }

      // --- Final del proceso ---
      if (mounted) {
        setState(() => _subiendo = false);
        _cargarDatos(); // Recargar galería

        String mensajeFinal = "";
        Color colorFinal = Colors.green;

        if (errores == 0) {
          mensajeFinal = "Se han subido $completados archivos correctamente.";
        } else {
          mensajeFinal = "Subidos: $completados. Errores: $errores.";
          colorFinal = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeFinal), backgroundColor: colorFinal)
        );
      }
    }
  }

  void _mostrarCrearAlbumDialog() {
    final TextEditingController _controller = TextEditingController();
    
    // --- CORRECCIÓN: Definimos las variables AQUÍ, fuera del StatefulBuilder ---
    // De esta forma, no se reinician cada vez que se actualiza el diálogo.
    String? _errorTexto; 
    bool _botonDesactivado = true; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // Función interna para validar mientras escribes
            void _validarNombre(String texto) {
              final nombreLimpio = texto.trim();
              
              if (nombreLimpio.isEmpty) {
                setStateDialog(() {
                  _errorTexto = null;
                  _botonDesactivado = true;
                });
                return;
              }

              // Buscamos si ya existe una carpeta con ese nombre
              bool existe = _albumesVisibles.any((album) => 
                  album.nombre.toLowerCase() == nombreLimpio.toLowerCase()
              );

              setStateDialog(() {
                if (existe) {
                  _errorTexto = "Ya existe una carpeta con este nombre";
                  _botonDesactivado = true;
                } else {
                  _errorTexto = null;
                  _botonDesactivado = false;
                }
              });
            }

            return AlertDialog(
              title: const Text('Nueva Carpeta'),
              content: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Nombre de la carpeta",
                  errorText: _errorTexto, 
                ),
                onChanged: (val) => _validarNombre(val),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  // Si _botonDesactivado es true, onPressed es null (botón gris)
                  onPressed: _botonDesactivado 
                      ? null 
                      : () {
                          Navigator.pop(context);
                          _realizarCreacionAlbum(_controller.text.trim());
                        },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _realizarCreacionAlbum(String nombre) async {
    setState(() => _cargando = true);
    // Llamada a la API (pasamos descripción vacía "" como tenías antes)
    bool ok = await _apiService.crearAlbum(widget.token, nombre, "", widget.parentId);
    
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carpeta creada'), backgroundColor: Colors.green),
      );
      _cargarDatos(); // Recargamos para que aparezca
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear la carpeta'), backgroundColor: Colors.red),
      );
      setState(() => _cargando = false);
    }
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
                    if (value == 'admin_panel') Navigator.push(context, MaterialPageRoute(builder: (context) => AdminScreen(token: widget.token)));
                    if (value == 'config') Navigator.push(context,MaterialPageRoute(builder: (context) => const ConfiguracionScreen()),).then((_) {_cargarDatos(); });
                    if (value == 'refresh') _cargarDatos();
                    if (value == 'logout') _cerrarSesion();
                    if (value == 'gestionar_amistades') Navigator.push(context, MaterialPageRoute(builder: (context) => const GestionarAmistadesScreen()));
                    if (value == 'compartidos') Navigator.push(context,MaterialPageRoute(builder: (context) => const CompartidosScreen()),);
                    if (value == 'papelera') Navigator.push(context, MaterialPageRoute(builder: (context) => PapeleraScreen(token: widget.token))).then((_) => _cargarDatos());
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    if (_esAdmin) 
                      const PopupMenuItem<String>(
                        value: 'admin_panel',
                        child: ListTile(
                          leading: Icon(Icons.admin_panel_settings, color: Colors.indigo),
                          title: Text('Administración', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (_esAdmin) const PopupMenuDivider(),
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
                    const PopupMenuItem<String>(
                      value: 'gestionar_amistades',
                      child: ListTile(
                        leading: Icon(Icons.person_search),
                        title: Text('Gestionar Amistades'),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'compartidos',
                      child: ListTile(
                        leading: Icon(Icons.folder_shared),
                        title: Text('Compartidos conmigo'),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'papelera',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.grey),
                        title: Text('Papelera'),
                        contentPadding: EdgeInsets.zero, // Ajuste visual para alinear con los Rows
                      ),
                    ),
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
                  // Si hay fechas seleccionadas, lo pintamos de azul para que se note
                  icon: Icon(Icons.calendar_month, color: _rangoFechas != null ? Colors.blue : Colors.black),
                  onPressed: _mostrarSelectorFechas, // <--- AQUÍ SE LLAMA A LA FUNCIÓN
                ),
                IconButton(
                  icon: Icon(Icons.sort), 
                  onPressed: _mostrarMenuOrden
                ),
                // Aquí ya NO ponemos los botones de config/logout porque están en el título
              ]
            ],
      ),
      body: Stack(
        children: [
          // CAPA 1: TU CONTENIDO ORIGINAL (Filtros + Grid)
          // Aquí pegamos tu Column exactamente como la tenías
          Column(
            children: [
              // Filtros
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
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: Colors.blue[900],
                    shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
                  ),
                );
              },
            ),
          ),

          // 2. AÑADE ESTO AQUÍ: EL INDICADOR DE FECHA ACTIVA
          if (_rangoFechas != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                children: [
                  InputChip(
                    avatar: const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                    label: Text(
                      // Muestra si es fecha Real o Subida y el rango (ej: "Captura: 10/2 - 15/2")
                      "${_tipoFechaFiltro == 'real' ? 'Captura' : 'Subida'}: "
                      "${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - "
                      "${_rangoFechas!.end.day}/${_rangoFechas!.end.month}",
                      style: TextStyle(color: Colors.blue[900], fontSize: 13),
                    ),
                    onDeleted: () {
                      // Al pulsar la X, borramos el filtro
                      setState(() {
                        _rangoFechas = null;
                        _aplicarFiltros(); // Recargamos la lista
                      });
                    },
                    deleteIconColor: Colors.red,
                    backgroundColor: Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.blue.withOpacity(0.3))
                    ),
                  ),
                ],
              ),
            ),

              // Grid
              Expanded(
                child: _cargando 
                  ? const Center(child: CircularProgressIndicator())
                  : (_albumesVisibles.isEmpty && _recursosFiltrados.isEmpty)
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.search_off, size: 60, color: Colors.grey), SizedBox(height: 10), Text("Carpeta vacía")]))
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                            errorWidget: (context, url, error) => const Icon(Icons.error),
                                          )
                                        : _getIconoArchivo(recurso),
                                    ),
                                    if (recurso.tipo == "VIDEO")
                                      Center(child: Container(decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white, size: 30))),
                                    if (_modoSeleccion)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.blue.withOpacity(0.4) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                                        ),
                                        child: isSelected 
                                          ? const Icon(Icons.check_circle, color: Colors.white, size: 30)
                                          : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.radio_button_unchecked, color: Colors.white))),
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

          // CAPA 2: LA BARRA DE PROGRESO FLOTANTE (Solo visible si _subiendo es true)
          if (_subiendo)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Card(
                elevation: 10,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, // Alinear texto a la izquierda
                    children: [
                      // Fila con Título y Porcentaje
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Usamos Flexible para que el nombre del archivo no rompa la fila si es largo
                          Flexible(
                            child: Text(
                              _mensajeSubida, // <--- VARIABLE DINÁMICA
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "${(_progreso * 100).toStringAsFixed(0)}%", 
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _progreso,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: Colors.grey[200],
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
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