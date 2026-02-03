import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recursos.dart'; // O recurso.dart según como lo llamaste
import '../services/api_service.dart';

class DetalleFotoScreen extends StatelessWidget {
  final Recurso recurso;
  final String token;

  const DetalleFotoScreen({
    Key? key,
    required this.recurso,
    required this.token,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // URL completa de la imagen en alta calidad
    final fullUrl = "${ApiService.baseUrl}${recurso.urlVisualizacion}";

    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para resaltar la foto
      body: Stack(
        children: [
          // 1. LA FOTO (Ocupa toda la pantalla)
          Center(
            child: InteractiveViewer(
              panEnabled: true, // Permitir mover
              minScale: 0.5,
              maxScale: 4.0, // Permitir Zoom hasta 4x
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                httpHeaders: {"Authorization": "Bearer $token"},
                placeholder: (context, url) => CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 2. BOTÓN ATRÁS (Flotante arriba a la izquierda)
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. HOJA DE DETALLES (Deslizable desde abajo)
          DraggableScrollableSheet(
            initialChildSize: 0.1, // Empieza mostrando solo el 10% (la puntita)
            minChildSize: 0.1,     // Lo mínimo que se puede bajar
            maxChildSize: 0.6,     // Lo máximo que sube (60% de la pantalla)
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  children: [
                    // Pequeña barra gris para indicar que se puede deslizar
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    
                    // Título
                    Text(
                      "Detalles del Archivo",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),

                    // Características
                    _buildDetalleItem(Icons.image, "Nombre", recurso.nombre),
                    _buildDetalleItem(Icons.category, "Tipo", recurso.tipo),
                    _buildDetalleItem(Icons.calendar_today, "Subido el", recurso.fechaSubida.toString()),
                    _buildDetalleItem(Icons.fingerprint, "ID Recurso", recurso.id.toString()),
                    
                    SizedBox(height: 20),
                    // Botón de ejemplo para acciones futuras
                    ElevatedButton.icon(
                      onPressed: () {
                        // Aquí podrías implementar borrar o compartir
                      },
                      icon: Icon(Icons.share),
                      label: Text("Compartir"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para las filas de detalles
  Widget _buildDetalleItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}