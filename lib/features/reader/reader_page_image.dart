import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Satu halaman reader. Mendukung URI file:// dan http(s). Gambar didekode
/// sesuai lebar layar dan tingginya dilaporkan lewat [onAspect].
class ReaderPageImage extends StatefulWidget {
  const ReaderPageImage({
    super.key,
    required this.url,
    required this.number,
    required this.width,
    required this.decodeWidth,
    required this.onAspect,
    this.knownAspect,
  });

  final String url;

  /// Nomor halaman mulai dari 1, untuk pesan.
  final int number;

  /// Lebar layar (piksel logis).
  final double width;

  /// Lebar dekode (piksel fisik).
  final int decodeWidth;

  /// Tinggi dibagi lebar jika sudah pernah diketahui.
  final double? knownAspect;

  final void Function(double aspect) onAspect;

  @override
  State<ReaderPageImage> createState() => _ReaderPageImageState();
}

class _ReaderPageImageState extends State<ReaderPageImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  Object? _error;

  ImageProvider? _provider() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return null;
    final ImageProvider base;
    if (uri.scheme == 'file') {
      base = FileImage(File.fromUri(uri));
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      base = NetworkImage(widget.url);
    } else {
      return null;
    }
    return ResizeImage(base, width: widget.decodeWidth);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.decodeWidth != widget.decodeWidth) {
      _resolve(force: true);
    }
  }

  void _resolve({bool force = false}) {
    final provider = _provider();
    if (provider == null) {
      _error ??= 'Alamat gambar tidak valid';
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (!force && stream.key == _stream?.key) return;

    _stopListening();
    _stream = stream;
    _listener = ImageStreamListener(_onImage, onError: _onError);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
      _error = null;
    });
    widget.onAspect(info.image.height / info.image.width);
  }

  void _onError(Object error, StackTrace? stack) {
    if (!mounted) return;
    setState(() => _error = error);
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
  }

  Future<void> _retry() async {
    final provider = _provider();
    setState(() => _error = null);
    if (provider != null) await provider.evict();
    if (mounted) _resolve(force: true);
  }

  @override
  void dispose() {
    _stopListening();
    _info?.dispose();
    _info = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info != null) {
      return RawImage(
        image: info.image,
        scale: info.scale,
        width: double.infinity,
        fit: BoxFit.fitWidth,
      );
    }

    if (_error != null) {
      return Container(
        height: widget.width * 0.7,
        color: const Color(0xFF1B1B1B),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 8),
            Text('Halaman ${widget.number} gagal dimuat'),
            TextButton(onPressed: _retry, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    // Tanpa animasi: tinggi perkiraan sampai gambar termuat.
    return Container(
      height: widget.width * (widget.knownAspect ?? 1.4),
      color: const Color(0xFF101010),
      alignment: Alignment.center,
      child: Text(
        'Halaman ${widget.number}',
        style: const TextStyle(color: Color(0xFF6B6B6B)),
      ),
    );
  }
}
