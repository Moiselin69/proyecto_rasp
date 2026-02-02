import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/recursos.dart';
import 'login_screen.dart';
class GaleriaScreen extends StatefulWidget {
  final String token;

  const GaleriaScreen({Key? key, required this.token}) : super(key: key);

  @override
  _GaleriaScreenState createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Recurso>> _recursosFuture;

  @override
  void initState() {
    super.initState();
    _cargarRecursos();
  }

  void _cargarRecursos() {
    setState(() {
      _recursosFuture = _apiService.obtenerMisRecursos(widget.token);
    });
  }

  void _cerrarSesion() async {
    await _apiService.logout(); // Borra el token del móvil
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => LoginScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Moiselin Cloud"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarRecursos, // Botón para recargar
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _cerrarSesion, // Botón salir
          ),
        ],
      ),
      body: FutureBuilder<List<Recurso>>(
        future: _recursosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red),
                  SizedBox(height: 10),
                  Text("Error cargando fotos"),
                  TextButton(onPressed: _cargarRecursos, child: Text("Reintentar"))
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No tienes fotos subidas aún."));
          }

          final recursos = snapshot.data!;

          return GridView.builder(
            padding: EdgeInsets.all(4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 columnas de fotos
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: recursos.length,
            itemBuilder: (context, index) {
              final recurso = recursos[index];
              
              // Construimos la URL completa para la miniatura
              // Ejemplo: https://192.168.1.35:8000/recurso/archivo/5?size=small
              final urlImagen = "${ApiService.baseUrl}${recurso.urlThumbnail}";

              return GestureDetector(
                onTap: () {
                  // Aquí pondremos luego la lógica para ver la foto en grande
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Abrir: ${recurso.nombre}"))
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: recurso.esImagen
                    ? CachedNetworkImage(
                        imageUrl: urlImagen,
                        httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container( // Diseño para videos/archivos
                        color: Colors.blueGrey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam, size: 40, color: Colors.blueGrey),
                            SizedBox(height: 4),
                            Text(
                              "VIDEO", 
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí pondremos la lógica para subir fotos
        },
        child: Icon(Icons.add_a_photo),
      ),
    );
  }
}