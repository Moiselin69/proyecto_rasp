import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  
  Future<String?> descargarYGuardar(String url, String nombreArchivo, String tipo, String token, {String? rutaPersonalizada}) async {
    try {
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.request().isGranted && 
            !await Permission.storage.request().isGranted) {
           await openAppSettings(); 
           return null;
        }
      }
      final tempDir = await getTemporaryDirectory();
      final tempPath = "${tempDir.path}/$nombreArchivo";
      final dio = Dio();
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
      await dio.download(
        url,
        tempPath,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      String? resultado;
      if (rutaPersonalizada != null) {
        final rutaFinal = "$rutaPersonalizada/$nombreArchivo";
        await File(tempPath).copy(rutaFinal);
        resultado = rutaPersonalizada; // Devolvemos la ruta elegida
      }
      else {
        if (tipo == "VIDEO") {
          bool ok = (await GallerySaver.saveVideo(tempPath, albumName: "Moiselin Cloud")) ?? false;
          if (ok) resultado = "Galería > Álbum 'Moiselin Cloud'";
        } 
        else if (tipo == "IMAGEN") {
          bool ok = (await GallerySaver.saveImage(tempPath, albumName: "Moiselin Cloud")) ?? false;
          if (ok) resultado = "Galería > Álbum 'Moiselin Cloud'";
        } 
        else {
          String ruta = await _guardarEnDescargas(tempPath, nombreArchivo);
          if (ruta.isNotEmpty) resultado = ruta;
        }
      }
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