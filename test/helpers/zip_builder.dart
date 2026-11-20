import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Membuat file ZIP kecil di [directory] untuk keperluan test.
File makeTestZip(
  Directory directory,
  String fileName,
  Map<String, List<int>> entries,
) {
  final archive = Archive();
  entries.forEach((name, bytes) {
    archive.addFile(ArchiveFile.bytes(name, bytes));
  });
  final data = ZipEncoder().encodeBytes(archive);
  directory.createSync(recursive: true);
  return File(p.join(directory.path, fileName))..writeAsBytesSync(data);
}
