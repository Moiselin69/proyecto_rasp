import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
// --- IMPORTANTE: Añade estos dos imports para que funcione tu selector ---
import 'package:photo_manager/photo_manager.dart';
import '../widgets/selector_fotos_propio.dart';
// ------------------------------------------------------------------------
import '../services/upload_manager.dart';

class UploadProgressScreen extends StatefulWidget {
  final int? currentAlbumId; // Para saber dónde añadir más fotos

  const UploadProgressScreen({Key? key, this.currentAlbumId}) : super(key: key);

  @override
  _UploadProgressScreenState createState() => _UploadProgressScreenState();
}

class _UploadProgressScreenState extends State<UploadProgressScreen> {
  final UploadManager _manager = UploadManager();

  // --- NUEVA LÓGICA: MENÚ DE OPCIONES (Sin carpeta) ---
  void _mostrarOpcionesAddMas() {
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
            const Text("Añadir más a la cola", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Opción 1: TU WIDGET PROPIO (Fotos/Videos)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.photo_library, color: Colors.blue)
              ),
              title: const Text("Fotos y Vídeos"),
              subtitle: const Text("Galería (Tu selector)"),
              onTap: () {
                Navigator.pop(ctx);
                _addDesdeGaleria();
              }
            ),
            
            const SizedBox(height: 10),
            
            // Opción 2: ARCHIVOS (File Picker)
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
                _addDesdeArchivos();
              }
            ),
            const SizedBox(height: 20)
          ]
        )
      )
    );
  }

  // --- FUNCIÓN 1: AÑADIR DESDE TU WIDGET ---
  Future<void> _addDesdeGaleria() async {
    // 1. Abrir tu selector personalizado
    final List<AssetEntity>? assets = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => const SelectorFotosPropio(maxSelection: 100), 
        fullscreenDialog: true
      )
    );
    
    if (assets == null || assets.isEmpty) return;

    // 2. Feedback visual rápido
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Procesando ${assets.length} archivos..."))
      );
    }

    // 3. Convertir AssetEntity a File
    List<File> archivosParaSubir = [];
    for (var asset in assets) {
      File? file = await asset.file;
      if (file != null) {
        archivosParaSubir.add(file);
      }
    }

    // 4. Añadir a la cola del manager
    if (archivosParaSubir.isNotEmpty) {
      _manager.addFiles(archivosParaSubir, widget.currentAlbumId);
    }
  }

  // --- FUNCIÓN 2: AÑADIR DESDE ARCHIVOS ---
  Future<void> _addDesdeArchivos() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      List<File> files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();
      
      if (files.isNotEmpty) {
        _manager.addFiles(files, widget.currentAlbumId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final tasks = _manager.tasks;

        return Scaffold(
          appBar: AppBar(
            title: Text("Subiendo ${tasks.length} archivos"),
            actions: [
              if (!_manager.isUploading && tasks.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () => _manager.clearCompleted(),
                  tooltip: "Limpiar completados",
                )
            ],
          ),
          body: Column(
            children: [
              // Barra de estado general
              if (_manager.isUploading)
                const LinearProgressIndicator(backgroundColor: Colors.blue, minHeight: 4),
              
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text("No hay subidas activas"))
                    : ListView.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          // Mostrar los más nuevos arriba
                          final task = tasks[tasks.length - 1 - index]; 
                          return _buildTaskItem(task);
                        },
                      ),
              ),
            ],
          ),
          // AQUÍ CONECTAMOS EL NUEVO MENÚ
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _mostrarOpcionesAddMas, // <--- CAMBIO AQUÍ
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text("Añadir más"),
            backgroundColor: Colors.blue,
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(UploadTask task) {
    Color statusColor;
    String statusText;

    switch (task.status) {
      case UploadStatus.pending:
        statusColor = Colors.grey;
        statusText = "Pendiente";
        break;
      case UploadStatus.uploading:
        statusColor = Colors.blue;
        statusText = "Subiendo ${(task.progress * 100).toStringAsFixed(0)}%";
        break;
      case UploadStatus.completed:
        statusColor = Colors.green;
        statusText = "Subido con éxito";
        break;
      case UploadStatus.error:
        statusColor = Colors.red;
        statusText = task.errorMessage ?? "Error";
        break;
      case UploadStatus.conflict: // NUEVO CASO
        statusColor = Colors.orange;
        statusText = "Archivo duplicado. ¿Reemplazar?";
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: task.status == UploadStatus.completed 
              ? Border.all(color: Colors.green, width: 2) 
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: task.tipo == 'IMAGEN'
            ? Image.file(task.file, fit: BoxFit.cover)
            : Icon(
                task.tipo == 'VIDEO' ? Icons.videocam : Icons.insert_drive_file,
                color: Colors.grey.shade600,
              ),
      ),
      title: Text(
        path.basename(task.file.path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: task.status == UploadStatus.conflict ? FontWeight.bold : FontWeight.normal)),
          
          if (task.status == UploadStatus.uploading)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: LinearProgressIndicator(
                value: task.progress,
                color: Colors.blue,
                backgroundColor: Colors.blue.shade100,
              ),
            ),
            
          if (task.status == UploadStatus.error)
            Text(
              task.errorMessage ?? "",
              style: const TextStyle(color: Colors.red, fontSize: 10),
              maxLines: 2,
            )
        ],
      ),
      
      // --- BOTONES DINÁMICOS SEGÚN ESTADO ---
      trailing: task.status == UploadStatus.conflict 
      ? Row( // SI HAY CONFLICTO: MOSTRAR SI/NO
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _manager.resolveConflict(task.id, true),
              style: TextButton.styleFrom(foregroundColor: Colors.blue, padding: EdgeInsets.zero, minimumSize: const Size(40, 30)),
              child: const Text("SÍ", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _manager.resolveConflict(task.id, false),
              style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(40, 30)),
              child: const Text("NO"),
            ),
          ],
        )
      : Row( // CASO NORMAL: CHECK O CRUZ
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.status == UploadStatus.completed)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            if (task.status == UploadStatus.error)
              const Icon(Icons.error, color: Colors.red, size: 20),
              
            const SizedBox(width: 8),
            
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _manager.removeTask(task.id),
              tooltip: "Quitar de la lista",
            ),
          ],
        ),
    );
  }
}