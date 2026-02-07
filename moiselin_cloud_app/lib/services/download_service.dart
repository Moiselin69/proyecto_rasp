import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  
  // Ahora devuelve un String? (null si falla, texto de la ruta si funciona)
  Future<String?> descargarYGuardar(String url, String nombreArchivo, String tipo, String token) async {
    try {
      // 1. GESTIÓN DE PERMISOS (Android 11+)
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.request().isGranted && 
            !await Permission.storage.request().isGranted) {
           await openAppSettings(); 
           return null; // Sin permisos no hacemos nada
        }
      }

      // 2. Preparar descarga
      final tempDir = await getTemporaryDirectory();
      final tempPath = "${tempDir.path}/$nombreArchivo";
      print("Descargando: $url");

      // 3. Configurar Dio para HTTPS (Certificados autofirmados)
      final dio = Dio();
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };

      // 4. Descargar
      await dio.download(
        url,
        tempPath,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      // 5. Guardar y devolver la RUTA
      String? resultado;

      if (tipo == "VIDEO") {
        bool ok = (await GallerySaver.saveVideo(tempPath, albumName: "Moiselin Cloud")) ?? false;
        if (ok) resultado = "Galería > Álbum 'Moiselin Cloud'";
      } 
      else if (tipo == "IMAGEN") {
        bool ok = (await GallerySaver.saveImage(tempPath, albumName: "Moiselin Cloud")) ?? false;
        if (ok) resultado = "Galería > Álbum 'Moiselin Cloud'";
      } 
      else {
        // Para archivos, devolvemos la ruta explícita
        String ruta = await _guardarEnDescargas(tempPath, nombreArchivo);
        if (ruta.isNotEmpty) resultado = ruta;
      }

      // Limpieza
      final fileTemp = File(tempPath);
      if (await fileTemp.exists()) await fileTemp.delete();

      return resultado;

    } catch (e) {
      print("Error en descarga: $e");
      return null;
    }
  }

  // Devuelve la ruta final como String
  Future<String> _guardarEnDescargas(String rutaOrigen, String nombreArchivo) async {
    try {
      Directory? carpetaDestino;
      if (Platform.isAndroid) {
        // Ruta pública de descargas
        carpetaDestino = Directory('/storage/emulated/0/Download/MoiselinCloud');
      } else {
        carpetaDestino = await getApplicationDocumentsDirectory();
      }
      
      if (!await carpetaDestino.exists()) {
        await carpetaDestino.create(recursive: true);
      }

      final rutaFinal = "${carpetaDestino.path}/$nombreArchivo";
      await File(rutaOrigen).copy(rutaFinal);
      
      return rutaFinal; // Devolvemos la ruta para mostrarla

    } catch (e) {
      print("Error moviendo archivo: $e");
      return "";
    }
  }
}