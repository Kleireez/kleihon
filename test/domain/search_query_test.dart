import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/domain/entities/search_query.dart';

void main() {
  group('normalizeSearchQuery', () {
    test('membuang spasi di tepi dan merapikan spasi di tengah', () {
      expect(normalizeSearchQuery('  solo   leveling  '), 'solo leveling');
      expect(normalizeSearchQuery('a\t b\n\nc'), 'a b c');
    });

    test('mempertahankan huruf besar-kecil', () {
      expect(normalizeSearchQuery('Solo LEVELING'), 'Solo LEVELING');
    });

    test('teks kosong atau hanya spasi menghasilkan kosong', () {
      expect(normalizeSearchQuery(''), '');
      expect(normalizeSearchQuery('   \n\t '), '');
    });

    test('dipotong pada panjang maksimal', () {
      final long = 'a' * (maxSearchQueryLength + 50);
      expect(normalizeSearchQuery(long).length, maxSearchQueryLength);
    });

    test('pemotongan tidak menyisakan spasi di ujung', () {
      final text = '${'a' * (maxSearchQueryLength - 1)} bbbb';
      final result = normalizeSearchQuery(text);
      expect(result, 'a' * (maxSearchQueryLength - 1));
      expect(result.endsWith(' '), isFalse);
    });
  });
}
