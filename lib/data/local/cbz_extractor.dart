import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/natural_compare.dart';

enum LocalImportError {
  notAnArchive,
  noImages,
  tooManyEntries,
  entryTooLarge,
  totalTooLarge,
  ioFailure,
}

class LocalImportException implements Exception {
  const LocalImportException(this.error, {this.debugMessage});

  final LocalImportError error;

  /// Hanya untuk log developer.
  final String? debugMessage;

  String get userMessage {
    switch (error) {
      case LocalImportError.notAnArchive:
        return 'File tidak dapat dibaca sebagai arsip CBZ/ZIP.';
      case LocalImportError.noImages:
        return 'Arsip tidak berisi gambar yang didukung (jpg, png, webp).';
      case LocalImportError.tooManyEntries:
        return 'Arsip berisi terlalu banyak halaman.';
      case LocalImportError.entryTooLarge:
        return 'Ada halaman dengan ukuran terlalu besar.';
      case LocalImportError.totalTooLarge:
        return 'Ukuran total arsip terlalu besar.';
      case LocalImportError.ioFailure:
        return 'Gagal menyimpan file. Periksa ruang penyimpanan.';
    }
  }

  @override
  String toString() => 'LocalImportException($error, $debugMessage)';
}

class CbzLimits {
  const CbzLimits({
    this.maxPages = 2000,
    this.maxPageBytes = 40 * 1024 * 1024,
    this.maxTotalBytes = 2 * 1024 * 1024 * 1024,
  });

  final int maxPages;
  final int maxPageBytes;
  final int maxTotalBytes;
}

class ExtractionResult {
  const ExtractionResult({
    required this.directory,
    required this.pages,
    required this.skippedEntries,
  });

  final Directory directory;

  /// Berkas halaman, sudah berurutan.
  final List<File> pages;
  final int skippedEntries;
}

/// Mengekstrak halaman gambar dari CBZ/ZIP ke folder tujuan.
/// Nama berkas hasil dibuat sendiri (0001.jpg, ...), bukan dari isi arsip.
class CbzExtractor {
  const CbzExtractor({this.limits = const CbzLimits()});

  static const Set<String> imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  final CbzLimits limits;

  /// [destination] tidak boleh sudah ada. Jika gagal, tidak ada yang tertinggal.
  Future<ExtractionResult> extract({
    required File source,
    required Directory destination,
  }) async {
    if (await destination.exists()) {
      throw ArgumentError.value(
        destination.path,
        'destination',
        'Folder tujuan sudah ada',
      );
    }

    final temp = Directory('${destination.path}.tmp');
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }

    InputFileStream? input;
    var finished = false;
    try {
      input = InputFileStream(source.path);
      final archive = _decode(input);
      if (archive.isEmpty) {
        throw const LocalImportException(
          LocalImportError.notAnArchive,
          debugMessage: 'Arsip kosong',
        );
      }

      final picked = _pickPages(archive);
      final pages = picked.pages;
      if (pages.isEmpty) {
        throw const LocalImportException(LocalImportError.noImages);
      }
      if (pages.length > limits.maxPages) {
        throw const LocalImportException(LocalImportError.tooManyEntries);
      }

      var declaredTotal = 0;
      for (final entry in pages) {
        if (entry.size > limits.maxPageBytes) {
          throw const LocalImportException(LocalImportError.entryTooLarge);
        }
        declaredTotal += entry.size;
        if (declaredTotal > limits.maxTotalBytes) {
          throw const LocalImportException(LocalImportError.totalTooLarge);
        }
      }

      await temp.create(recursive: true);
      final digits = pages.length.toString().length;
      final width = digits < 4 ? 4 : digits;
      final names = <String>[];
      var written = 0;

      for (var i = 0; i < pages.length; i++) {
        final entry = pages[i];
        final data = entry.readBytes();
        if (data == null) {
          throw LocalImportException(
            LocalImportError.notAnArchive,
            debugMessage: 'Entri tidak terbaca: ${entry.name}',
          );
        }
        // Cek ulang dengan ukuran sebenarnya, bukan hanya ukuran di header.
        if (data.length > limits.maxPageBytes) {
          throw const LocalImportException(LocalImportError.entryTooLarge);
        }
        written += data.length;
        if (written > limits.maxTotalBytes) {
          throw const LocalImportException(LocalImportError.totalTooLarge);
        }

        final ext = p.extension(entry.name).toLowerCase();
        final fileName = '${(i + 1).toString().padLeft(width, '0')}$ext';
        await File(p.join(temp.path, fileName)).writeAsBytes(data, flush: true);
        names.add(fileName);
      }

      await destination.parent.create(recursive: true);
      await temp.rename(destination.path);
      finished = true;

      return ExtractionResult(
        directory: destination,
        pages: [for (final name in names) File(p.join(destination.path, name))],
        skippedEntries: picked.skipped,
      );
    } on FileSystemException catch (e) {
      throw LocalImportException(
        LocalImportError.ioFailure,
        debugMessage: e.toString(),
      );
    } finally {
      await input?.close();
      if (!finished && await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  }

  Archive _decode(InputFileStream input) {
    try {
      return ZipDecoder().decodeStream(input, throwOnError: true);
    } catch (e) {
      throw LocalImportException(
        LocalImportError.notAnArchive,
        debugMessage: e.toString(),
      );
    }
  }

  ({List<ArchiveFile> pages, int skipped}) _pickPages(Archive archive) {
    final pages = <ArchiveFile>[];
    var skipped = 0;
    for (final entry in archive) {
      if (!entry.isFile ||
          entry.isSymbolicLink ||
          !_isAcceptablePage(entry.name)) {
        skipped++;
        continue;
      }
      pages.add(entry);
    }
    pages.sort((a, b) => naturalCompare(a.name, b.name));
    return (pages: pages, skipped: skipped);
  }

  bool _isAcceptablePage(String name) {
    final normalized = name.replaceAll('\\', '/');
    final segments = normalized.split('/');

    // Path absolut menghasilkan segmen pertama kosong.
    if (segments.first.isEmpty) return false;

    for (final segment in segments) {
      if (segment.isEmpty) continue;
      if (segment == '..' || segment == '__MACOSX' || segment.startsWith('.')) {
        return false;
      }
    }
    return imageExtensions.contains(p.extension(normalized).toLowerCase());
  }
}
