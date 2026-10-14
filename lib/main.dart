import 'package:flutter/material.dart';

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
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: const ShelfScreen(),
    );
  }
}

class Album {
  final String title;
  final String artist;
  final String year;
  final Color spineColor;
  final List<String> tracks;

  Album({
    required this.title,
    required this.artist,
    required this.year,
    required this.spineColor,
    required this.tracks,
  });
}

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key});

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  final List<Album> albums = [
    Album(title: 'The Doors', artist: 'The Doors', year: '1967', spineColor: Colors.red.shade900, tracks: ['Break On Through', 'Light My Fire']),
    Album(title: 'Back in Black', artist: 'AC/DC', year: '1980', spineColor: Colors.grey.shade900, tracks: ['Hells Bells', 'Back in Black']),
    Album(title: 'Hunky Dory', artist: 'David Bowie', year: '1971', spineColor: Colors.amber.shade800, tracks: ['Changes', 'Life on Mars?']),
    Album(title: 'Pyromania', artist: 'Def Leppard', year: '1983', spineColor: Colors.blue.shade900, tracks: ['Rock! Rock!', 'Photograph']),
  ];

  Album? selectedAlbum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classic Rock Shelf'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // Menú flotante (Colección, Catálogo, Tocadiscos)
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Vista de Estantería 3D Estilo Lomo
          ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedAlbum = album;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  height: 45,
                  decoration: BoxDecoration(
                    color: album.spineColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 4),
                    ],
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        album.artist.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        album.title,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Detalle del Álbum Desplegado (Simulando la vista 3D frontal del disco)
          if (selectedAlbum != null)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tapa del disco simulada
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: selectedAlbum!.spineColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, blurRadius: 20, spreadRadius: 5)
                        ],
                      ),
                      child: Center(
                        child: Text(
                          selectedAlbum!.title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(selectedAlbum!.artist, style: const TextStyle(fontSize: 18, color: Colors.amberAccent)),
                    Text(selectedAlbum!.year, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    // Lista de Canciones / Tracks
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        itemCount: selectedAlbum!.tracks.length,
                        itemBuilder: (ctx, i) => ListTile(
                          dense: true,
                          title: Text(selectedAlbum!.tracks[i]),
                          trailing: const Icon(Icons.play_arrow, color: Colors.amberAccent),
                          onPressed: () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                      onPressed: () {
                        setState(() {
                          selectedAlbum = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cerrar Carátula'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Buscador flotante (Fase 3)
        },
        backgroundColor: Colors.amberAccent,
        child: const Icon(Icons.search, color: Colors.black),
      ),
    );
  }
}
