import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'recurso_api.dart';

// 1. AÑADIMOS EL ESTADO 'conflict'
enum UploadStatus { pending, uploading, completed, error, conflict }

class UploadTask {
  final String id;
  final File file;
  final String tipo;
  double progress;
  UploadStatus status;
  String? errorMessage;
  int? idAlbumDestino;
  bool reemplazar; // Nuevo campo para saber si estamos reintentando

  UploadTask({
    required this.file,
    required this.tipo,
    this.idAlbumDestino,
    this.progress = 0.0,
    this.status = UploadStatus.pending,
    this.reemplazar = false,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString() + path.basename(file.path);
}

class UploadManager extends ChangeNotifier {
  static final UploadManager _instance = UploadManager._internal();
  factory UploadManager() => _instance;
  UploadManager._internal();

  final RecursoApiService _apiService = RecursoApiService();
  List<UploadTask> _tasks = [];
  List<UploadTask> get tasks => _tasks;
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  void addFiles(List<File> files, int? idAlbum) {
    for (var file in files) {
      _tasks.add(UploadTask(
        file: file,
        tipo: _determinarTipo(file),
        idAlbumDestino: idAlbum,
      ));
    }
    notifyListeners();
    _processQueue();
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  // 2. NUEVA FUNCIÓN PARA RESOLVER CONFLICTO
  void resolveConflict(String taskId, bool replace) {
    int index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      if (replace) {
        // Si quiere reemplazar, marcamos flag y ponemos en pendiente para que se reintente
        _tasks[index].reemplazar = true;
        _tasks[index].status = UploadStatus.pending;
        _processQueue(); // Reactivamos la cola
      } else {
        // Si no quiere, borramos la tarea
        removeTask(taskId);
      }
      notifyListeners();
    }
  }

  String _determinarTipo(File archivo) {
    String extension = path.extension(archivo.path).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(extension)) return 'IMAGEN';
    if (['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) return 'VIDEO';
    if (['.mp3', '.wav', '.m4a'].contains(extension)) return 'AUDIO';
    return 'ARCHIVO';
  }

  Future<void> _processQueue() async {
    if (_isUploading) return;
    _isUploading = true;
    notifyListeners();

    int simultaneos = 3;

    while (_tasks.any((t) => t.status == UploadStatus.pending)) {
      var pendientes = _tasks.where((t) => t.status == UploadStatus.pending).take(simultaneos).toList();
      if (pendientes.isEmpty) break;

      for (var task in pendientes) task.status = UploadStatus.uploading;
      notifyListeners();

      await Future.wait(pendientes.map((task) => _uploadSingleFile(task)));
    }

    _isUploading = false;
    notifyListeners();
  }

  Future<void> _uploadSingleFile(UploadTask task) async {
    String? resultado = await _apiService.subirPorChunks(
      task.file,
      task.tipo,
      idAlbum: task.idAlbumDestino,
      reemplazar: task.reemplazar, // Pasamos el flag
      onProgress: (percent) {
        task.progress = percent;
        notifyListeners();
      },
    );

    // 3. DETECCIÓN DE CONFLICTO
    if (resultado == "DUPLICADO") {
      task.status = UploadStatus.conflict; // Estado especial
      task.errorMessage = "Ya existe un archivo con este nombre.";
    } else if (resultado != null && 
       !resultado.startsWith("Error") && 
       !resultado.startsWith("Excepción") && 
       !resultado.startsWith("No hay sesión")) {
      task.status = UploadStatus.completed;
      task.progress = 1.0;
    } else {
      task.status = UploadStatus.error;
      task.errorMessage = resultado ?? "Error desconocido";
    }
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == UploadStatus.completed);
    notifyListeners();
  }
}