import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/recursos.dart'; // O recurso.dart
import '../services/api_service.dart';

class DetalleFotoScreen extends StatefulWidget {
  final Recurso recurso;
  final String token;

  const DetalleFotoScreen({
    Key? key,
    required this.recurso,
    required this.token,
  }) : super(key: key);

  @override
  _DetalleFotoScreenState createState() => _DetalleFotoScreenState();
}

class _DetalleFotoScreenState extends State<DetalleFotoScreen> {
  final ApiService _apiService = ApiService();
  late String _nombreActual;
  late String _fechaRealTexto; // Fecha editable (cuando se tomó la foto)

  @override
  void initState() {
    super.initState();
    _nombreActual = widget.recurso.nombre;
    
    _fechaRealTexto = _formatearFechaBonita(widget.recurso.fechaReal.toString());
  }

  // --- LÓGICA PARA EDITAR NOMBRE ---
  void _editarNombre() {
    TextEditingController controller = TextEditingController(text: _nombreActual);
    
    showDialog(
      context: context,
      // CAMBIO 1: Renombramos 'context' a 'dialogContext' para no confundirnos
      builder: (dialogContext) => AlertDialog(
        title: Text("Renombrar archivo"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: "Nuevo nombre"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: Text("Cancelar")
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final nuevoNombre = controller.text;
              
                final messenger = ScaffoldMessenger.of(context);
                
                // 1. Cerramos el diálogo usando su propio contexto
                Navigator.pop(dialogContext); 

                // 2. Llamada asíncrona
                bool exito = await _apiService.editarNombre(
                    widget.token, widget.recurso.id, nuevoNombre);
                
                // 3. Verificamos si la PANTALLA DE FONDO sigue viva
                if (!mounted) return; 

                // 4. Resultado
                if (exito) {
                  setState(() => _nombreActual = nuevoNombre);
                  
                  // --- USAMOS LA VARIABLE 'messenger' GUARDADA ---
                  // Ya no usamos 'ScaffoldMessenger.of(context)' aquí porque podría fallar
                  messenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 10),
                            Expanded(child: Text("Nombre cambiado correctamente")),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      )
                  );
                } else {
                   messenger.showSnackBar(
                      SnackBar(
                        content: Text("Error: No se pudo cambiar el nombre"), 
                        backgroundColor: Colors.red
                      )
                   );
                }
              }
            },
            child: Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA PARA EDITAR FECHA ---
  void _editarFecha() async {
    // 1. Elegir Fecha
    DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale("es", "ES"),
    );

    if (fecha == null) return;
    if (!mounted) return;

    // 2. Elegir Hora
    TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (hora == null) return;

    // Combinar fecha y hora
    DateTime fechaFinal = DateTime(
      fecha.year, fecha.month, fecha.day, hora.hour, hora.minute
    );

    // --- CAMBIO CLAVE: Guardamos el mensajero antes de llamar a la API ---
    final messenger = ScaffoldMessenger.of(context);

    // 3. Llamada a la API
    bool exito = await _apiService.editarFecha(
        widget.token, widget.recurso.id, fechaFinal);

    if (!mounted) return;

    // 4. Resultado con Notificación Idéntica al Nombre
    if (exito) {
      setState(() {
        _fechaRealTexto = DateFormat('yyyy-MM-dd HH:mm').format(fechaFinal);
      });

      // Notificación VERDE y BONITA
      messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Fecha real actualizada")),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          )
      );
    } else {
      // Notificación de ERROR (por si acaso)
      messenger.showSnackBar(
          SnackBar(
            content: Text("Error al actualizar la fecha"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = "${ApiService.baseUrl}${widget.recurso.urlVisualizacion}";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. IMAGEN
          Center(
            child: InteractiveViewer(
              minScale: 0.5, maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                httpHeaders: {"Authorization": "Bearer ${widget.token}"},
                placeholder: (context, url) => CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 2. BOTÓN ATRÁS
          Positioned(
            top: 40, left: 10,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. PANEL DE DETALLES
          DraggableScrollableSheet(
            initialChildSize: 0.1, minChildSize: 0.1, maxChildSize: 0.6,
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
                    Center(child: Container(width: 40, height: 5, color: Colors.grey[300])),
                    SizedBox(height: 20),
                    Text("Detalles", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),

                    // EDITABLES
                    _buildEditableItem(Icons.edit, "Nombre", _nombreActual, _editarNombre),
                    _buildEditableItem(Icons.event, "Fecha Real (Editable)", _fechaRealTexto, _editarFecha),
                    
                    Divider(),
                    
                    // FIJOS (Aquí añadimos la fecha de subida)
                    _buildFijoItem(Icons.cloud_upload, "Fecha de Subida", _formatearFechaBonita(widget.recurso.fechaSubida.toString())),
                    _buildFijoItem(Icons.category, "Tipo", widget.recurso.tipo),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditableItem(IconData icon, String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: Colors.blue, size: 28),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(icon: Icon(icon, color: Colors.blueAccent), onPressed: onEdit)
        ],
      ),
    );
  }

  Widget _buildFijoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 28),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  String _formatearFechaBonita(String? fechaRaw) {
    if (fechaRaw == null || fechaRaw.isEmpty || fechaRaw == "null") {
      return "Sin fecha";
    }
    try {
      DateTime fecha = DateTime.parse(fechaRaw);
      return DateFormat('dd-MM-yyyy HH:mm').format(fecha);
    } catch (e) {
      return fechaRaw;
    }
  }
}