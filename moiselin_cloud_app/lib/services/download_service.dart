import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  
  Future<bool> descargarYGuardar(String url, String nombreArchivo, String tipo, String token) async {
    try {
      // 1. Pedir permisos generales (Importante para Android 9 o inferior)
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      // 2. Ruta temporal de descarga (Descargamos aquí primero siempre)
      final tempDir = await getTemporaryDirectory();
      final tempPath = "${tempDir.path}/$nombreArchivo";

      // 3. Descargar usando DIO con tu Token
      print("Iniciando descarga de: $url");
      await Dio().download(
        url,
        tempPath,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      // 4. Mover el archivo a su destino final según el tipo
      bool exito = false;

      if (tipo == "VIDEO") {
        exito = (await GallerySaver.saveVideo(tempPath, albumName: "Moiselin Cloud")) ?? false;
      } 
      else if (tipo == "IMAGEN") {
        exito = (await GallerySaver.saveImage(tempPath, albumName: "Moiselin Cloud")) ?? false;
      } 
      else {
        // --- AQUÍ ESTÁ LA MAGIA PARA AUDIO Y ARCHIVOS ---
        exito = await _guardarEnDescargas(tempPath, nombreArchivo);
      }

      // 5. Limpieza: Borrar el archivo temporal
      final fileTemp = File(tempPath);
      if (await fileTemp.exists()) {
        await fileTemp.delete();
      }

      return exito;

    } catch (e) {
      print("Error en descarga: $e");
      return false;
    }
  }

  // Función auxiliar para mover archivos a la carpeta pública
  Future<bool> _guardarEnDescargas(String rutaOrigen, String nombreArchivo) async {
    try {
      Directory? carpetaDestino;

      if (Platform.isAndroid) {
        // En Android, guardamos en /storage/emulated/0/Download/MoiselinCloud
        carpetaDestino = Directory('/storage/emulated/0/Download/MoiselinCloud');
      } else {
        // En iOS, guardamos en la carpeta de Documentos de la App
        carpetaDestino = await getApplicationDocumentsDirectory();
      }

      // Crear carpeta si no existe
      if (!await carpetaDestino.exists()) {
        await carpetaDestino.create(recursive: true);
      }

      final rutaFinal = "${carpetaDestino.path}/$nombreArchivo";
      
      // Copiar el archivo
      await File(rutaOrigen).copy(rutaFinal);
      print("Archivo guardado en: $rutaFinal");
      return true;

    } catch (e) {
      print("Error guardando archivo genérico: $e");
      return false;
    }
  }
}