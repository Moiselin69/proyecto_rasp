import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class SelectorFotosPropio extends StatefulWidget {
  final int maxSelection;
  const SelectorFotosPropio({Key? key, this.maxSelection = 100}) : super(key: key);

  @override
  _SelectorFotosPropioState createState() => _SelectorFotosPropioState();
}

class _SelectorFotosPropioState extends State<SelectorFotosPropio> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _seleccionados = [];
  bool _cargando = true;
  bool _sinPermiso = false; // <--- NUEVA VARIABLE

  @override
  void initState() {
    super.initState();
    _cargarFotos();
  }

  Future<void> _cargarFotos() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    
    // CORRECCIÓN: En vez de cerrar (pop), marcamos que no hay permiso
    if (!ps.hasAccess && !ps.isAuth) {
      if (mounted) {
        setState(() {
          _sinPermiso = true;
          _cargando = false;
        });
      }
      return;
    }

    // CRÍTICO: Definir orden explícito
    final FilterOptionGroup optionGroup = FilterOptionGroup(
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
        filterOption: optionGroup, 
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> media = await albums[0].getAssetListRange(start: 0, end: 200);
        if (mounted) {
          setState(() {
            _assets = media;
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      print("Error cargando fotos: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar"),
        actions: [
          TextButton(
            onPressed: _seleccionados.isEmpty 
              ? null 
              : () => Navigator.pop(context, _seleccionados),
            child: Text(
              "Hecho (${_seleccionados.length})", 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: _seleccionados.isEmpty ? Colors.grey : Colors.blue
              )
            ),
          )
        ],
      ),
      body: _buildBody(), // Extraemos el body para limpiar el código
    );
  }

  Widget _buildBody() {
    // CASO 1: SIN PERMISO
    if (_sinPermiso) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Se requiere acceso a la galería"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                PhotoManager.openSetting(); // Abre los ajustes del móvil
              },
              child: const Text("Abrir Ajustes"),
            )
          ],
        ),
      );
    }

    // CASO 2: CARGANDO
    if (_cargando) return const Center(child: CircularProgressIndicator());

    // CASO 3: VACÍO
    if (_assets.isEmpty) return const Center(child: Text("No hay fotos"));

    // CASO 4: LISTA DE FOTOS
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final isSelected = _seleccionados.contains(asset);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _seleccionados.remove(asset);
              } else {
                if (_seleccionados.length < widget.maxSelection) {
                  _seleccionados.add(asset);
                }
              }
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(250),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(color: Colors.grey[200]);
                },
              ),
              
              if (asset.type == AssetType.video)
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.videocam, color: Colors.white, size: 20),
                  ),
                ),

              if (isSelected)
                Container(color: Colors.blue.withOpacity(0.4)),
              
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.black12,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: isSelected 
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : const SizedBox(width: 12, height: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}