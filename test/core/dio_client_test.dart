import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/core/errors/app_exception.dart';
import 'package:kleihon/core/network/dio_client.dart';

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  Object? error,
}) {
  final request = RequestOptions(path: '/test');
  return DioException(
    requestOptions: request,
    type: type,
    error: error,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: request, statusCode: statusCode),
  );
}

void main() {
  group('mapDioException', () {
    test('semua jenis timeout menjadi timeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(mapDioException(_dioError(type)).type, AppErrorType.timeout);
      }
    });

    test('connectionError menjadi noInternet', () {
      final result = mapDioException(
        _dioError(DioExceptionType.connectionError),
      );
      expect(result.type, AppErrorType.noInternet);
    });

    test('SocketException menjadi noInternet', () {
      final result = mapDioException(
        _dioError(
          DioExceptionType.unknown,
          error: const SocketException('gagal'),
        ),
      );
      expect(result.type, AppErrorType.noInternet);
    });

    test('cancel menjadi cancelled', () {
      final result = mapDioException(_dioError(DioExceptionType.cancel));
      expect(result.type, AppErrorType.cancelled);
    });

    test('status HTTP dipetakan dengan benar', () {
      final cases = <int, AppErrorType>{
        401: AppErrorType.authRequired,
        403: AppErrorType.accessDenied,
        429: AppErrorType.accessDenied,
        404: AppErrorType.notFound,
        500: AppErrorType.server,
        503: AppErrorType.server,
        418: AppErrorType.unknown,
      };
      cases.forEach((code, expected) {
        final result = mapDioException(
          _dioError(DioExceptionType.badResponse, statusCode: code),
        );
        expect(result.type, expected, reason: 'status $code');
        expect(result.statusCode, code);
      });
    });

    test('error tak dikenal menjadi unknown', () {
      final result = mapDioException(_dioError(DioExceptionType.unknown));
      expect(result.type, AppErrorType.unknown);
    });
  });

  group('AppException', () {
    test('setiap jenis error punya pesan untuk pengguna', () {
      for (final type in AppErrorType.values) {
        final message = AppException(type).userMessage;
        expect(message, isNotEmpty, reason: '$type');
      }
    });

    test('pesan pengguna tidak membocorkan detail debug', () {
      const e = AppException(
        AppErrorType.server,
        debugMessage: 'RAHASIA-STACKTRACE',
      );
      expect(e.userMessage.contains('RAHASIA-STACKTRACE'), isFalse);
    });

    test('hanya error jaringan yang boleh di-retry', () {
      const retryable = {
        AppErrorType.noInternet,
        AppErrorType.timeout,
        AppErrorType.server,
      };
      for (final type in AppErrorType.values) {
        expect(
          AppException(type).isRetryable,
          retryable.contains(type),
          reason: '$type',
        );
      }
    });
  });
}