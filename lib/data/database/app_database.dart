import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Comics,
    Chapters,
    Bookmarks,
    ReadingProgressEntries,
    ReadingHistoryEntries,
    Downloads,
    SearchHistoryEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Untuk test (misalnya database in-memory).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Versi 2: progres baca menyimpan jumlah halaman dan rasio tinggi
        // halaman, supaya posisi bisa dipulihkan dengan tepat.
        await migrator.addColumn(
          readingProgressEntries,
          readingProgressEntries.pageCount,
        );
        await migrator.addColumn(
          readingProgressEntries,
          readingProgressEntries.aspectsJson,
        );
      }
    },
    beforeOpen: (details) async {
      // Wajib agar relasi antar tabel ditegakkan.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kleihon.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
