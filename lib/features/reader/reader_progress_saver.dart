import 'dart:async';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/reading_progress_repository.dart';

/// Keadaan reader yang perlu disimpan.
typedef ReaderSnapshot = ({
  int pageIndex,
  double scrollOffset,
  int pageCount,
  List<double?> aspects,
});

/// Menyimpan progres baca dengan jeda (debounce), dan seketika lewat [flush].
class ReaderProgressSaver {
  ReaderProgressSaver({
    required this.repository,
    required this.sourceId,
    required this.comicRemoteId,
    required this.chapterRemoteId,
    required this.snapshot,
    this.onSaved,
    this.debounce = const Duration(milliseconds: 800),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReadingProgressRepository repository;
  final String sourceId;
  final String comicRemoteId;
  final String chapterRemoteId;

  /// Mengambil keadaan reader saat ini. Null jika belum siap.
  final ReaderSnapshot? Function() snapshot;

  /// Dipanggil setelah progres berhasil disimpan. Kegagalan di dalamnya
  /// tidak mengganggu pembacaan.
  final Future<void> Function(ReadingProgress saved)? onSaved;

  final Duration debounce;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _dirty = false;

  /// Menandai ada perubahan dan menyimpannya setelah [debounce].
  void schedule() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Menyimpan segera jika ada perubahan. Bagian sinkron (membaca
  /// [snapshot]) berjalan sebelum await pertama, jadi aman dipanggil dari
  /// dispose() sebelum controller dibuang.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) return;
    _dirty = false;

    final current = snapshot();
    if (current == null) return;

    final progress = ReadingProgress(
      sourceId: sourceId,
      comicRemoteId: comicRemoteId,
      chapterRemoteId: chapterRemoteId,
      pageIndex: current.pageIndex,
      pageCount: current.pageCount,
      scrollOffset: current.scrollOffset,
      aspects: current.aspects,
      updatedAt: _clock(),
    );

    try {
      await repository.saveProgress(progress);
    } catch (e, stack) {
      // Progres adalah fitur pelengkap: kegagalan tidak boleh mengganggu baca.
      appLogger.w('Gagal menyimpan progres baca', error: e, stackTrace: stack);
      return;
    }

    try {
      await onSaved?.call(progress);
    } catch (e, stack) {
      appLogger.w('Gagal memperbarui status baca', error: e, stackTrace: stack);
    }
  }
}
