import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moiselin_cloud_app/services/api_service.dart';

class BackupService {
  static Future<bool> procesarCopiaSeguridad() async {
    // 1. Pedir permiso de galería si no se tiene
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return false;

    // 2. Obtener la fecha de la última sincronización
    final prefs = await SharedPreferences.getInstance();
    final int? lastTimestamp = prefs.getInt('last_sync_timestamp');

    // 3. Buscar fotos nuevas desde ese timestamp
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(onlyAll: true);
    if (albums.isEmpty) return true;

    List<AssetEntity> assets = await albums[0].getAssetListRange(start: 0, end: 50);
    
    for (var asset in assets) {
      final int assetTimestamp = asset.createDateTime.millisecondsSinceEpoch;
      
      // Si la foto es más nueva que nuestra última subida
      if (lastTimestamp == null || assetTimestamp > lastTimestamp) {
        final file = await asset.file;
        if (file != null) {
          // 4. Subir usando tu ApiService existente
          // Nota: Debes asegurarte de tener el token guardado encriptado o en SharedPreferences
          bool exito = await ApiService().subirRecursoAutomatico(file, asset.type.name);
          
          if (exito) {
            await prefs.setInt('last_sync_timestamp', assetTimestamp);
          }
        }
      }
    }
    return true;
  }
}