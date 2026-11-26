import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/constants/app_info.dart';

void main() {
  test('versi di app_info sama dengan pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+?)(?:\+(\S+))?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'baris version: tidak ditemukan');
    expect(match!.group(1), appVersion);
    expect(match.group(2), appBuild);
  });

  test('nama aplikasi terisi', () {
    expect(appName, isNotEmpty);
  });
}
