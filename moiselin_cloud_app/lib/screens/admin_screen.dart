import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  final String token;
  const AdminScreen({Key? key, required this.token}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _api = ApiService();
  
  List<dynamic> _usuarios = [];
  Map<String, dynamic> _statsDisco = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() async {
    try {
      // Ahora recibimos un Map con usuarios y disco
      final data = await _api.getUsuariosAdmin(widget.token);
      if (mounted) {
        setState(() {
          _usuarios = data['usuarios'];
          _statsDisco = data['disco'];
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
      print("Error cargando admin: $e");
    }
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return "Ilimitado";
    int b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return "$b B";
    if (b < 1024 * 1024) return "${(b/1024).toStringAsFixed(1)} KB";
    if (b < 1024 * 1024 * 1024) return "${(b/(1024*1024)).toStringAsFixed(1)} MB";
    return "${(b/(1024*1024*1024)).toStringAsFixed(2)} GB";
  }

  // --- WIDGET DE LA TARJETA DEL SERVIDOR ---
  Widget _buildServerCard() {
    if (_statsDisco.isEmpty) return SizedBox.shrink();

    int total = _statsDisco['total'] ?? 0;
    int usado = _statsDisco['usado'] ?? 0;
    int libre = _statsDisco['libre'] ?? 0;

    double porcentaje = total > 0 ? usado / total : 0.0;

    return Card(
      elevation: 4,
      margin: EdgeInsets.all(10),
      color: Colors.indigo[50], // Un color suave para diferenciarlo
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.indigo),
                SizedBox(width: 10),
                Text("Almacenamiento Físico del Servidor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Usado: ${_formatBytes(usado)}", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                Text("Total: ${_formatBytes(total)}"),
              ],
            ),
            SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: porcentaje,
                minHeight: 15,
                backgroundColor: Colors.white,
                color: porcentaje > 0.8 ? Colors.red : Colors.indigo,
              ),
            ),
            SizedBox(height: 5),
            Text(
              "Espacio Libre Real: ${_formatBytes(libre)}", 
              style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }

  void _dialogoCuota(Map<String, dynamic> u) {
    String valorInicial = "";
    if (u['almacenamiento_maximo'] != null) {
      double gb = u['almacenamiento_maximo'] / (1024 * 1024 * 1024);
      valorInicial = gb % 1 == 0 ? gb.toInt().toString() : gb.toStringAsFixed(2);
    }

    final ctrl = TextEditingController(text: valorInicial);
    bool esIlimitado = (u['almacenamiento_maximo'] == null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text("Límite para ${u['nombre']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: Text("Sin límite (Espacio Disco)"),
                  value: esIlimitado,
                  onChanged: (val) {
                    setStateDialog(() {
                      esIlimitado = val!;
                      if (esIlimitado) ctrl.clear();
                    });
                  },
                ),
                TextField(
                  controller: ctrl,
                  enabled: true,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Límite en GB",
                    suffixText: "GB",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                     if (val.isNotEmpty && esIlimitado) setStateDialog(() => esIlimitado = false);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  int? bytesToSend;
                  if (!esIlimitado && ctrl.text.isNotEmpty) {
                    double gb = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
                    bytesToSend = (gb * 1024 * 1024 * 1024).toInt();
                  }
                  
                  String? error = await _api.cambiarCuota(widget.token, u['id'], bytesToSend);
                  if (error == null) {
                    // CASO ÉXITO (error es null)
                    if (mounted) {
                      Navigator.pop(ctx); // Cerrar diálogo
                      _cargar(); // Recargar datos
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Cuota actualizada correctamente"),
                          backgroundColor: Colors.green,
                        )
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error), // Aquí saldrá: "El usuario ya ocupa..."
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4), // Un poco más largo para leer
                        )
                      );
                    }
                  }
                },
                child: Text("Guardar"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Administración"), backgroundColor: Colors.indigo),
      body: _cargando 
        ? Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              // 1. TARJETA DE ESTADO DEL SERVIDOR (Arriba)
              _buildServerCard(),

              // 2. LISTA DE USUARIOS (Abajo)
              Expanded(
                child: ListView.builder(
                  itemCount: _usuarios.length,
                  itemBuilder: (ctx, i) {
                    final u = _usuarios[i];
                    int usado = u['espacio_usado'] ?? 0;
                    dynamic maximo = u['almacenamiento_maximo']; 
                    
                    double porcentaje = 0.0;
                    if (maximo != null && maximo > 0) {
                      porcentaje = usado / maximo;
                      if (porcentaje > 1) porcentaje = 1;
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: u['rol'] == 'ADMINISTRADOR' ? Colors.red : Colors.blue,
                          child: Icon(u['rol'] == 'ADMINISTRADOR' ? Icons.security : Icons.person, color: Colors.white),
                        ),
                        title: Text("${u['nombre']} ${u['apellidos']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Usado: ${_formatBytes(usado)} / ${_formatBytes(maximo)}"),
                            if (maximo != null)
                              LinearProgressIndicator(value: porcentaje, color: porcentaje > 0.9 ? Colors.red : Colors.blue),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit, color: Colors.grey[700]),
                          onPressed: () => _dialogoCuota(u),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}