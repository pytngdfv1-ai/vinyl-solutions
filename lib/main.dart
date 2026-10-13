import 'package:flutter/material.dart';

void main() {
  runApp(const VinylApp());
}

class VinylApp extends StatelessWidget {
  const VinylApp({super.key});

  @override
  Widget build(BuildContext context) {
    mainColor: Colors.deepPurple;
    return MaterialApp(
      title: 'Vinyl Solutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const LibraryScreen(),
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca de Vinilos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.album, size: 80, color: Colors.amberAccent),
            const SizedBox(height: 16),
            const Text(
              'Tu biblioteca está vacía',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa el buscador flotante para añadir música.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción de búsqueda flotante (Fase 3)
        },
        backgroundColor: Colors.amberAccent,
        child: const Icon(Icons.search, color: Colors.black),
      ),
    );
  }
}
