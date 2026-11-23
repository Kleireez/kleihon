import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/utils/format_date.dart';

void main() {
  test('format dd/MM/yyyy dengan nol di depan', () {
    expect(formatShortDate(DateTime(2026, 11, 5)), '05/11/2026');
    expect(formatShortDate(DateTime(2027, 1, 20)), '20/01/2027');
  });
  test('jam HH:mm dengan nol di depan', () {
    expect(formatTimeOfDay(DateTime(2026, 11, 5, 9, 7)), '09:07');
    expect(formatTimeOfDay(DateTime(2026, 11, 5, 23, 45)), '23:45');
  });
}
