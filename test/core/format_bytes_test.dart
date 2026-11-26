import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/utils/format_bytes.dart';

void main() {
  test('byte biasa tanpa desimal', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1023), '1023 B');
  });

  test('satu angka desimal dengan koma untuk nilai kecil', () {
    expect(formatBytes(1024), '1,0 KB');
    expect(formatBytes(1536), '1,5 KB');
    expect(formatBytes(3 * 1024 * 1024), '3,0 MB');
  });

  test('tanpa desimal untuk nilai 100 ke atas', () {
    expect(formatBytes(150 * 1024 * 1024), '150 MB');
  });

  test('gigabyte dan terabyte', () {
    expect(formatBytes((1.5 * 1024 * 1024 * 1024).round()), '1,5 GB');
    expect(formatBytes(2 * 1024 * 1024 * 1024 * 1024), '2,0 TB');
  });

  test('angka negatif dianggap nol', () {
    expect(formatBytes(-5), '0 B');
  });
}
