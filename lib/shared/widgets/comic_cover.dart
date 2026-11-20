import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Sampul komik. Mendukung URI file:// (sumber lokal) dan http(s).
class ComicCover extends StatelessWidget {
  const ComicCover({super.key, required this.url, this.borderRadius = 8});

  final String? url;
  final double borderRadius;

  static const int _decodeWidth = 400;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.auto_stories_rounded, color: scheme.onSurfaceVariant),
      ),
    );
    final broken = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    final value = url;
    final uri = value == null ? null : Uri.tryParse(value);

    final Widget image;
    if (uri != null && uri.scheme == 'file') {
      image = Image.file(
        File.fromUri(uri),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: _decodeWidth,
        errorBuilder: (context, error, stack) => broken,
      );
    } else if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      image = Image.network(
        value!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: _decodeWidth,
        errorBuilder: (context, error, stack) => broken,
      );
    } else {
      image = placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }
}
