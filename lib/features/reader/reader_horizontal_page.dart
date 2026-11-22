import 'package:material_ui/material_ui.dart';

import 'reader_page_image.dart';
import 'reader_settings.dart';

/// Satu halaman pada mode horizontal.
/// [PageFit.height]: seluruh halaman terlihat utuh di layar.
/// [PageFit.width]: halaman memenuhi lebar dan bisa digulir ke bawah.
class HorizontalPageImage extends StatelessWidget {
  const HorizontalPageImage({
    super.key,
    required this.url,
    required this.number,
    required this.width,
    required this.height,
    required this.decodeWidth,
    required this.fit,
    required this.onAspect,
    this.knownAspect,
    this.placeholderColor = const Color(0xFF101010),
    this.placeholderTextColor = const Color(0xFF6B6B6B),
  });

  final String url;
  final int number;
  final double width;
  final double height;
  final int decodeWidth;
  final PageFit fit;
  final double? knownAspect;
  final void Function(double aspect) onAspect;
  final Color placeholderColor;
  final Color placeholderTextColor;

  @override
  Widget build(BuildContext context) {
    if (fit == PageFit.height) {
      return ReaderPageImage(
        url: url,
        number: number,
        width: width,
        decodeWidth: decodeWidth,
        boxHeight: height,
        knownAspect: knownAspect,
        onAspect: onAspect,
        placeholderColor: placeholderColor,
        placeholderTextColor: placeholderTextColor,
      );
    }

    // Halaman yang lebih pendek dari layar diletakkan di tengah.
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Center(
          child: ReaderPageImage(
            url: url,
            number: number,
            width: width,
            decodeWidth: decodeWidth,
            knownAspect: knownAspect,
            onAspect: onAspect,
            placeholderColor: placeholderColor,
            placeholderTextColor: placeholderTextColor,
          ),
        ),
      ),
    );
  }
}
