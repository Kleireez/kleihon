import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/features/reader/reader_math.dart';

import 'dart:ui';

import '../helpers/fake_comic_source.dart';

void main() {
  group('resolveChapterNeighbors', () {
    final chapters = [
      testChapter('s', 'k', 'c1'),
      testChapter('s', 'k', 'c2'),
      testChapter('s', 'k', 'c3'),
    ];

    test('chapter di tengah punya sebelum dan sesudah', () {
      final result = resolveChapterNeighbors(chapters, 'c2');
      expect(result.index, 1);
      expect(result.total, 3);
      expect(result.previous?.remoteId, 'c1');
      expect(result.current?.remoteId, 'c2');
      expect(result.next?.remoteId, 'c3');
      expect(result.found, isTrue);
    });

    test('chapter pertama tidak punya sebelumnya', () {
      final result = resolveChapterNeighbors(chapters, 'c1');
      expect(result.previous, isNull);
      expect(result.next?.remoteId, 'c2');
    });

    test('chapter terakhir tidak punya berikutnya', () {
      final result = resolveChapterNeighbors(chapters, 'c3');
      expect(result.previous?.remoteId, 'c2');
      expect(result.next, isNull);
    });

    test('chapter yang tidak ada ditandai tidak ditemukan', () {
      final result = resolveChapterNeighbors(chapters, 'hantu');
      expect(result.found, isFalse);
      expect(result.index, -1);
      expect(result.previous, isNull);
      expect(result.current, isNull);
      expect(result.next, isNull);
    });

    test('daftar kosong aman', () {
      final result = resolveChapterNeighbors(const [], 'c1');
      expect(result.found, isFalse);
      expect(result.total, 0);
    });
  });

  group('pageIndexAt', () {
    // Lebar 100, tinggi halaman 100, 200, 100 (batas bawah 100, 300, 400).
    double? aspectOf(int i) => const [1.0, 2.0, 1.0][i];

    int at(double offset) => pageIndexAt(
      offset: offset,
      viewportHeight: 100,
      pageWidth: 100,
      pageCount: 3,
      aspectOf: aspectOf,
    );

    test('mengikuti halaman di tengah layar', () {
      expect(at(0), 0);
      expect(at(100), 1);
      expect(at(250), 2);
    });

    test('offset negatif diperlakukan sebagai awal', () {
      expect(at(-50), 0);
    });

    test('melewati ujung mengembalikan halaman terakhir', () {
      expect(at(5000), 2);
    });

    test('halaman yang belum diketahui memakai tinggi bawaan', () {
      // Bawaan 1.4: tinggi 140 per halaman, batas bawah 140 dan 280.
      int unknown(double offset) => pageIndexAt(
        offset: offset,
        viewportHeight: 100,
        pageWidth: 100,
        pageCount: 2,
        aspectOf: (_) => null,
      );
      expect(unknown(0), 0);
      expect(unknown(100), 1);
    });

    test('tanpa halaman hasilnya 0', () {
      expect(
        pageIndexAt(
          offset: 10,
          viewportHeight: 100,
          pageWidth: 100,
          pageCount: 0,
          aspectOf: (_) => null,
        ),
        0,
      );
    });
    group('isCenterTap', () {
      const size = Size(100, 200);
      bool tap(double x, double y) =>
          isCenterTap(position: Offset(x, y), size: size);

      test('titik tengah terdeteksi', () {
        expect(tap(50, 100), isTrue);
      });

      test('tepi kiri dan kanan bukan zona tengah', () {
        expect(tap(5, 100), isFalse);
        expect(tap(95, 100), isFalse);
      });

      test('tepi atas dan bawah bukan zona tengah', () {
        expect(tap(50, 10), isFalse);
        expect(tap(50, 190), isFalse);
      });

      test('batas zona termasuk, sedikit di luarnya tidak', () {
        // Margin horizontal 20, vertikal 50.
        expect(tap(20, 50), isTrue);
        expect(tap(80, 150), isTrue);
        expect(tap(19, 100), isFalse);
        expect(tap(50, 49), isFalse);
      });
    });
  });
}
