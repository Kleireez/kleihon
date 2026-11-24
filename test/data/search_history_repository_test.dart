import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/data/database/app_database.dart';
import 'package:kleihon/data/repositories/search_history_repository_impl.dart';

void main() {
  late AppDatabase database;
  late SearchHistoryRepositoryImpl repository;

  Future<List<String>> recent({int limit = 10}) =>
      repository.watchRecent(limit: limit).first;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SearchHistoryRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('terbaru di atas', () async {
    await repository.add('alpha');
    await repository.add('beta');
    await repository.add('gamma');

    expect(await recent(), ['gamma', 'beta', 'alpha']);
  });

  test(
    'kata kunci sama tanpa peduli huruf dipindah ke atas dengan tulisan baru',
    () async {
      await repository.add('Alpha');
      await repository.add('beta');
      await repository.add('ALPHA');

      expect(await recent(), ['ALPHA', 'beta']);
      expect(
        await database.select(database.searchHistoryEntries).get(),
        hasLength(2),
      );
    },
  );

  test('kata kunci dirapikan dan yang kosong diabaikan', () async {
    await repository.add('  solo   leveling ');
    await repository.add('');
    await repository.add('   ');

    expect(await recent(), ['solo leveling']);
  });

  test('batas tampilan mengikuti limit', () async {
    for (var i = 0; i < 5; i++) {
      await repository.add('kata $i');
    }

    expect(await recent(limit: 3), ['kata 4', 'kata 3', 'kata 2']);
  });

  test('jumlah tersimpan dibatasi dan yang terlama dibuang', () async {
    final limited = SearchHistoryRepositoryImpl(database, maxEntries: 3);
    for (var i = 0; i < 5; i++) {
      await limited.add('kata $i');
    }

    final rows = await database.select(database.searchHistoryEntries).get();
    expect(rows, hasLength(3));
    expect(await limited.watchRecent(limit: 10).first, [
      'kata 4',
      'kata 3',
      'kata 2',
    ]);
  });

  test('hapus satu tidak peka huruf, dan yang tidak ada tidak error', () async {
    await repository.add('Alpha');
    await repository.add('beta');

    await repository.remove('alpha');
    expect(await recent(), ['beta']);

    await repository.remove('hantu');
    await repository.remove('   ');
    expect(await recent(), ['beta']);
  });

  test('hapus semua', () async {
    await repository.add('alpha');
    await repository.add('beta');

    await repository.clearAll();

    expect(await recent(), isEmpty);
  });

  test('watchRecent memancarkan perubahan', () async {
    final emissions = <List<String>>[];
    final subscription = repository.watchRecent().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await repository.add('alpha');
    await pumpEventQueue();
    expect(emissions.last, ['alpha']);

    await repository.remove('alpha');
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await subscription.cancel();
  });
}
