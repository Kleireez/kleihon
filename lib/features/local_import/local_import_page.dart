import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/utils/app_logger.dart';
import '../../data/local/cbz_extractor.dart';
import '../../data/local/local_providers.dart';
import '../../domain/entities/comic.dart';
import '../../shared/providers/library_revision_provider.dart';

/// SEMENTARA: daftar komik lokal (halaman 1) untuk memverifikasi impor.
/// Digantikan oleh katalog sungguhan di Phase 3.
final localComicsProvider = FutureProvider.autoDispose<List<Comic>>((
  ref,
) async {
  final result = await ref.watch(localComicSourceProvider).getLatest(1);
  return result.items;
});

class LocalImportPage extends ConsumerStatefulWidget {
  const LocalImportPage({super.key});

  @override
  ConsumerState<LocalImportPage> createState() => _LocalImportPageState();
}

class _LocalImportPageState extends ConsumerState<LocalImportPage> {
  bool _busy = false;

  Future<void> _import() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.pickFile();
    if (picked == null || !mounted) return;

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

    // Periksa isi arsip: berapa folder bergambar di dalamnya.
    setState(() => _busy = true);
    int groupCount;
    try {
      final groups = await ref.read(localLibraryProvider).inspectArchive(file);
      groupCount = groups.length;
    } on LocalImportException catch (e) {
      appLogger.w('Pemeriksaan arsip gagal: $e');
      messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
      if (mounted) setState(() => _busy = false);
      return;
    } catch (e, s) {
      appLogger.e('Pemeriksaan arsip gagal', error: e, stackTrace: s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat membaca arsip.')),
      );
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final existing = ref.read(localComicsProvider).value ?? const <Comic>[];
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
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final imported = await ref
          .read(localLibraryProvider)
          .importCbz(
            file: file,
            comicTitle: choice.title,
            comicRemoteId: choice.existingRemoteId,
            splitByFolder: choice.splitByFolder,
          );
      ref.invalidate(localComicsProvider);
      ref.read(libraryRevisionProvider.notifier).bump();
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comics = ref.watch(localComicsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perpustakaan lokal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: Text(_busy ? 'Memproses...' : 'Impor CBZ'),
      ),
      body: comics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gagal memuat daftar komik.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(localComicsProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada komik.\nImpor file CBZ atau ZIP berisi gambar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final comic = items[index];
              return ListTile(
                leading: _Cover(coverUrl: comic.coverUrl),
                title: Text(comic.title),
                onTap: () => context.push(
                  AppRoutes.comic(comic.sourceId, comic.remoteId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    const size = Size(44, 60);
    final url = coverUrl;
    if (url == null) {
      return const SizedBox(
        width: 44,
        height: 60,
        child: Icon(Icons.image_not_supported_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File.fromUri(Uri.parse(url)),
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const SizedBox(
          width: 44,
          height: 60,
          child: Icon(Icons.broken_image_outlined),
        ),
      ),
    );
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
  final List<Comic> existing;

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
