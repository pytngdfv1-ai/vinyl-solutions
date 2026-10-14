import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VinylApp());
}

class VinylApp extends StatelessWidget {
  const VinylApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vinyl Solutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primarySwatch: Colors.amber,
      ),
      home: const ShelfScreen(),
    );
  }
}

class Album {
  String title;
  String artist;
  String year;
  Color spineColor;
  List<String> tracks;

  Album({
    required this.title,
    required this.artist,
    required this.year,
    required this.spineColor,
    required this.tracks,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'year': year,
        'spineColor': spineColor.value,
        'tracks': tracks,
      };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        title: json['title'],
        artist: json['artist'],
        year: json['year'],
        spineColor: Color(json['spineColor']),
        tracks: List<String>.from(json['tracks']),
      );
}

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key});

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  List<Album> library = [];
  Album? selectedAlbum;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('vinyl_library');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        library = decoded.map((item) => Album.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(library.map((e) => e.toJson()).toList());
    await prefs.setString('vinyl_library', encoded);
  }

  void _addSampleAlbum() {
    setState(() {
      library.add(Album(
        title: 'Back in Black',
        artist: 'AC/DC',
        year: '1980',
        spineColor: Colors.grey.shade900,
        tracks: ['Hells Bells', 'Back in Black', 'Shoot to Thrill'],
      ));
    });
    _saveLibrary();
  }

  void _exportBackup() {
    // Aquí puedes implementar la exportación del JSON a un archivo descargable
    final String jsonString = jsonEncode(library.map((e) => e.toJson()).toList());
    debugScaffold(jsonString);
  }

  void debugScaffold(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Respaldo generado en memoria')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vinyl Shelf (Vacía al iniciar)'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.backup),
            onPressed: _exportBackup,
            tooltip: 'Respaldar Biblioteca',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSampleAlbum,
            tooltip: 'Añadir Disco de Prueba',
          ),
        ],
      ),
      body: library.isEmpty
          ? const Center(
              child: Text(
                'Biblioteca vacía. Agrega discos con el buscador o botón (+).',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: library.length,
              itemBuilder: (context, index) {
                final album = library[index];
                return GestureDetector(
                  onTap: () => setState(() => selectedAlbum = album),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    height: 40,
                    decoration: BoxDecoration(
                      color: album.spineColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(album.artist, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(album.title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
