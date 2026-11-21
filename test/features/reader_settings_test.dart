import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/features/reader/reader_settings.dart';
import 'package:kleihon/features/reader/reader_settings_providers.dart';
import 'package:kleihon/features/reader/reader_settings_store.dart';

import '../helpers/fake_reader_services.dart';

/// HANYA UNTUK TEST: pemuatan selalu gagal.
class _FailingLoadStore implements ReaderSettingsStore {
  @override
  Future<ReaderSettings> load() async => throw StateError('gagal muat');

  @override
  Future<void> save(ReaderSettings settings) async {}
}

/// HANYA UNTUK TEST: penyimpanan selalu gagal.
class _FailingSaveStore implements ReaderSettingsStore {
  @override
  Future<ReaderSettings> load() async => ReaderSettings.defaults;

  @override
  Future<void> save(ReaderSettings settings) async =>
      throw StateError('gagal simpan');
}

ProviderContainer makeContainer(ReaderSettingsStore store) {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [readerSettingsStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  // Menjaga provider tetap hidup selama test.
  container.listen(readerSettingsProvider, (previous, next) {});
  return container;
}

void main() {
  group('ReaderSettings', () {
    test('nilai bawaan: latar hitam dan layar menyala', () {
      expect(ReaderSettings.defaults.background, ReaderBackground.black);
      expect(ReaderSettings.defaults.keepScreenOn, isTrue);
    });

    test('toJson dan fromJson saling membalik', () {
      for (final background in ReaderBackground.values) {
        for (final keep in [true, false]) {
          final original = ReaderSettings(
            background: background,
            keepScreenOn: keep,
          );
          expect(ReaderSettings.fromJson(original.toJson()), original);
        }
      }
    });

    test('data rusak atau asing memakai nilai bawaan', () {
      expect(ReaderSettings.fromJson(null), ReaderSettings.defaults);
      expect(ReaderSettings.fromJson('bukan map'), ReaderSettings.defaults);
      expect(
        ReaderSettings.fromJson(<String, Object?>{}),
        ReaderSettings.defaults,
      );
      expect(
        ReaderSettings.fromJson({'background': 'neon', 'keepScreenOn': 'ya'}),
        ReaderSettings.defaults,
      );
    });

    test('bagian yang valid tetap dipakai walau bagian lain rusak', () {
      final partial = ReaderSettings.fromJson({'background': 'white'});
      expect(partial.background, ReaderBackground.white);
      expect(partial.keepScreenOn, isTrue);

      final other = ReaderSettings.fromJson({
        'background': 'neon',
        'keepScreenOn': false,
      });
      expect(other.background, ReaderBackground.black);
      expect(other.keepScreenOn, isFalse);
    });

    test('copyWith hanya mengubah yang diminta', () {
      const base = ReaderSettings(
        background: ReaderBackground.sepia,
        keepScreenOn: false,
      );
      expect(
        base.copyWith(background: ReaderBackground.white).keepScreenOn,
        isFalse,
      );
      expect(
        base.copyWith(keepScreenOn: true).background,
        ReaderBackground.sepia,
      );
    });

    test('teks terbaca di atas semua warna latar', () {
      for (final background in ReaderBackground.values) {
        final gap =
            (background.color.computeLuminance() -
                    background.foreground.computeLuminance())
                .abs();
        expect(gap, greaterThan(0.4), reason: background.name);
      }
    });

    test('setiap warna latar punya label', () {
      for (final background in ReaderBackground.values) {
        expect(background.label, isNotEmpty);
      }
    });
  });

  group('ReaderSettingsController', () {
    test('memuat pengaturan tersimpan', () async {
      final container = makeContainer(
        InMemoryReaderSettingsStore(
          const ReaderSettings(
            background: ReaderBackground.sepia,
            keepScreenOn: false,
          ),
        ),
      );

      final loaded = await container.read(readerSettingsProvider.future);
      expect(loaded.background, ReaderBackground.sepia);
      expect(loaded.keepScreenOn, isFalse);
    });

    test('apply menerapkan langsung dan menyimpan', () async {
      final store = InMemoryReaderSettingsStore();
      final container = makeContainer(store);
      await container.read(readerSettingsProvider.future);

      await container
          .read(readerSettingsProvider.notifier)
          .apply(const ReaderSettings(background: ReaderBackground.white));

      expect(
        container.read(readerSettingsProvider).value?.background,
        ReaderBackground.white,
      );
      expect(store.saved.last.background, ReaderBackground.white);
    });

    test('gagal memuat memakai nilai bawaan', () async {
      final container = makeContainer(_FailingLoadStore());

      final loaded = await container.read(readerSettingsProvider.future);
      expect(loaded, ReaderSettings.defaults);
    });

    test('gagal menyimpan tidak membatalkan pengaturan yang dipakai', () async {
      final container = makeContainer(_FailingSaveStore());
      await container.read(readerSettingsProvider.future);

      await container
          .read(readerSettingsProvider.notifier)
          .apply(const ReaderSettings(background: ReaderBackground.dark));

      expect(
        container.read(readerSettingsProvider).value?.background,
        ReaderBackground.dark,
      );
    });
  });
}
