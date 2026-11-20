import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/app_logger.dart';
import '../../data/local/cbz_extractor.dart';
import '../../data/local/local_library.dart';
import '../../data/local/local_providers.dart';
import '../../shared/providers/library_revision_provider.dart';

/// Alur impor CBZ: pilih file, periksa isinya, tanya judul, lalu impor.
/// Semua pesan ditampilkan lewat SnackBar.
Future<void> importLocalComic(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final library = ref.read(localLibraryProvider);
  final revision = ref.read(libraryRevisionProvider.notifier);

  final picked = await FilePicker.pickFile();
  if (picked == null || !context.mounted) return;

  final name = picked.name;
  final lower = name.toLowerCase();
  if (!lower.endsWith('.cbz') && !lower.endsWith('.zip')) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Pilih file berekstensi .cbz atau .zip.')),
    );
    return;
  }

  final path = picked.path;
  if (path == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('File tidak dapat dibaca.')),
    );
    return;
  }
  final file = File(path);

  final int groupCount;
  final List<LocalComicSummary> existing;
  try {
    final inspected = await _withProgress(
      context,
      'Membaca arsip...',
      () async {
        final groups = await library.inspectArchive(file);
        final comics = await library.listComics();
        return (groups.length, comics);
      },
    );
    groupCount = inspected.$1;
    existing = inspected.$2;
  } on LocalImportException catch (e) {
    appLogger.w('Pemeriksaan arsip gagal: $e');
    messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
    return;
  } catch (e, s) {
    appLogger.e('Pemeriksaan arsip gagal', error: e, stackTrace: s);
    messenger.showSnackBar(
      const SnackBar(content: Text('Terjadi kesalahan saat membaca arsip.')),
    );
    return;
  }
  if (!context.mounted) return;

  final choice = await showDialog<_ImportChoice>(
    context: context,
    builder: (_) => _ImportDialog(
      suggestedTitle: name.replaceFirst(
        RegExp(r'\.(cbz|zip)$', caseSensitive: false),
        '',
      ),
      existing: existing,
      groupCount: groupCount,
    ),
  );
  if (choice == null || !context.mounted) return;

  try {
    final imported = await _withProgress(
      context,
      'Mengimpor...',
      () => library.importCbz(
        file: file,
        comicTitle: choice.title,
        comicRemoteId: choice.existingRemoteId,
        splitByFolder: choice.splitByFolder,
      ),
    );
    revision.bump();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Berhasil: ${imported.chapters.length} chapter, '
          '${imported.pageCount} halaman.',
        ),
      ),
    );
  } on LocalImportException catch (e) {
    appLogger.w('Impor gagal: $e');
    messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
  } catch (e, s) {
    appLogger.e('Impor gagal', error: e, stackTrace: s);
    messenger.showSnackBar(
      const SnackBar(content: Text('Terjadi kesalahan saat mengimpor.')),
    );
  }
}

/// Menampilkan dialog progres selama [task] berjalan, lalu menutupnya.
Future<T> _withProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() task,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}

class _ImportChoice {
  const _ImportChoice({
    required this.title,
    this.existingRemoteId,
    this.splitByFolder = false,
  });

  final String title;
  final String? existingRemoteId;
  final bool splitByFolder;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({
    required this.suggestedTitle,
    required this.existing,
    required this.groupCount,
  });

  final String suggestedTitle;
  final List<LocalComicSummary> existing;

  /// Jumlah folder bergambar di dalam arsip.
  final int groupCount;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.suggestedTitle,
  );
  String? _existingRemoteId;
  bool _split = true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSplit => widget.groupCount > 1;

  bool get _canSubmit =>
      _existingRemoteId != null || _title.text.trim().isNotEmpty;

  void _submit() {
    final remoteId = _existingRemoteId;
    final split = _canSplit && _split;
    if (remoteId != null) {
      final comic = widget.existing.firstWhere((c) => c.remoteId == remoteId);
      Navigator.pop(
        context,
        _ImportChoice(
          title: comic.title,
          existingRemoteId: remoteId,
          splitByFolder: split,
        ),
      );
    } else {
      Navigator.pop(
        context,
        _ImportChoice(title: _title.text.trim(), splitByFolder: split),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Impor CBZ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.existing.isNotEmpty)
              DropdownButton<String?>(
                isExpanded: true,
                value: _existingRemoteId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Komik baru'),
                  ),
                  for (final comic in widget.existing)
                    DropdownMenuItem<String?>(
                      value: comic.remoteId,
                      child: Text(comic.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _existingRemoteId = value),
              ),
            if (_existingRemoteId == null)
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Judul komik'),
                onChanged: (_) => setState(() {}),
              ),
            if (_canSplit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _split,
                onChanged: (value) => setState(() => _split = value),
                title: Text('Pisahkan menjadi ${widget.groupCount} chapter'),
                subtitle: const Text('Satu chapter per folder di dalam arsip.'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Impor'),
        ),
      ],
    );
  }
}
