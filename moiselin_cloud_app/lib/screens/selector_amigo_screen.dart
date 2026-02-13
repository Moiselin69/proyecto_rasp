import 'dart:async'; // Para el Debounce
import 'package:flutter/material.dart';
import '../services/persona_api.dart';
import '../models/persona.dart';

class SelectorAmigoScreen extends StatefulWidget {
  final String token;
  const SelectorAmigoScreen({Key? key, required this.token}) : super(key: key);

  @override
  _SelectorAmigoScreenState createState() => _SelectorAmigoScreenState();
}

class _SelectorAmigoScreenState extends State<SelectorAmigoScreen> {
  final PersonaApiService _personaApi = PersonaApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Listas de datos
  List<Persona> _amigos = [];         
  List<Persona> _resultados = [];     
  
  // Estados de carga
  bool _cargandoInicial = true;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _cargarAmigosIniciales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _cargarAmigosIniciales() async {
    try {
      final lista = await _personaApi.obtenerAmigosConfirmados(widget.token);
      if (mounted) {
        setState(() {
          _amigos = lista;
          _cargandoInicial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoInicial = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Si borran el texto, limpiamos resultados y mostramos amigos de nuevo
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }

    setState(() => _buscando = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final resultadosJson = await _personaApi.buscarPersonas(query);
        final personas = resultadosJson.map((json) => Persona.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _resultados = personas;
            _buscando = false;
          });
        }
      } catch (e) {
        print("Error buscando: $e");
        if (mounted) setState(() => _buscando = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool modoBusqueda = _searchController.text.isNotEmpty;
    final List<Persona> listaMostrada = modoBusqueda ? _resultados : _amigos;

    return Scaffold(
      backgroundColor: Colors.white, // Fondo general blanco
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar blanca
        elevation: 0, // Sin sombra para que se vea plano y limpio
        // Botón de atrás en negro porque el fondo es blanco
        leading: const BackButton(color: Colors.black87), 
        
        // --- AQUÍ ESTÁ EL CAMBIO DE DISEÑO ---
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[200], // Color de fondo gris suave (estilo Google)
            borderRadius: BorderRadius.circular(30), // Bordes totalmente redondeados
          ),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            style: const TextStyle(color: Colors.black87), // Texto negro
            cursorColor: Colors.blue,
            textAlignVertical: TextAlignVertical.center, // Centra el texto verticalmente
            decoration: InputDecoration(
              hintText: "Buscar personas...",
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: InputBorder.none, // Quitamos la línea de abajo fea
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]), // Lupa gris
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              
              // El botón de borrar "X" ahora está dentro de la barra
              suffixIcon: _searchController.text.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.cancel, size: 20, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged("");
                    },
                  ) 
                : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
      ),
      body: Column(
        children: [
          // Barra de carga fina pegada al AppBar
          if (modoBusqueda && _buscando)
            const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.white),
            
          Expanded(
            child: _cargandoInicial 
              ? const Center(child: CircularProgressIndicator()) 
              : listaMostrada.isEmpty
                  ? _buildEmptyState(modoBusqueda)
                  : ListView.separated( // Usamos separated para poner líneas finas entre items
                      itemCount: listaMostrada.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 70),
                      itemBuilder: (ctx, i) {
                        final persona = listaMostrada[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: modoBusqueda ? Colors.blue[100] : Colors.indigo[100],
                            child: Text(
                              persona.iniciales, 
                              style: TextStyle(
                                color: modoBusqueda ? Colors.blue[900] : Colors.indigo[900], 
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ),
                          title: Text(
                            persona.nombreCompleto,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            "@${persona.nickname ?? 'sin_nick'}",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Enviar", 
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                          ),
                          onTap: () {
                            // Retornamos el ID seleccionado
                            Navigator.pop(context, persona.id);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool buscando) {
    if (buscando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text("Buscando usuarios...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          if (_amigos.isEmpty)
            const Text("No tienes amigos agregados.", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 5),
          Text(
            "Usa la barra superior para buscar", 
            style: TextStyle(color: Colors.blue[300], fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}