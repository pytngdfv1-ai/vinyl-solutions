import 'dart:io';

import 'package:flutter/material.dart';

import '../data/koofr_settings.dart';

/// Imagen de portada: URL de internet/Koofr o archivo local.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.fallback,
    this.cacheWidth,
  });

  final String url;
  final Widget fallback;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        // Las credenciales solo se envían a Koofr, nunca a terceros.
        headers: KoofrSettings.isKoofrUrl(url) ? KoofrSettings.activeHeaders : null,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, p) => p == null ? child : fallback,
      );
    }
    return Image.file(
      File(url.replaceFirst('file://', '')),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
