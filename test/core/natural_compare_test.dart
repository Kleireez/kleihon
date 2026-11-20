import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/utils/natural_compare.dart';

void main() {
  test('angka diurutkan secara numerik, bukan per huruf', () {
    final names = ['ch10.jpg', 'ch2.jpg', 'ch1.jpg', 'ch11.jpg'];
    names.sort(naturalCompare);
    expect(names, ['ch1.jpg', 'ch2.jpg', 'ch10.jpg', 'ch11.jpg']);
  });

  test('tidak peka huruf besar-kecil', () {
    final names = ['B2.jpg', 'a10.jpg', 'A2.jpg'];
    names.sort(naturalCompare);
    expect(names, ['A2.jpg', 'a10.jpg', 'B2.jpg']);
  });

  test('nama yang sama dianggap sama', () {
    expect(naturalCompare('a1.jpg', 'a1.jpg'), 0);
  });
}
