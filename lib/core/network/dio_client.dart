import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../utils/app_logger.dart';

class DioClient {
  DioClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? '',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 15),
          ),
        ) {
    dio.interceptors.add(_RetryInterceptor(dio));
    if (kDebugMode) {
      dio.interceptors.add(_LogInterceptor());
    }
  }

  final Dio dio;

  /// Request GET. Semua kegagalan diubah menjadi [AppException].
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

/// Mengubah [DioException] menjadi [AppException] yang aman untuk UI.
AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return AppException(AppErrorType.timeout, debugMessage: e.message);
    case DioExceptionType.cancel:
      return const AppException(AppErrorType.cancelled);
    case DioExceptionType.connectionError:
      return AppException(AppErrorType.noInternet, debugMessage: e.message);
    case DioExceptionType.badCertificate:
      return AppException(AppErrorType.unknown, debugMessage: e.message);
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      if (code == 401) {
        return AppException(AppErrorType.authRequired, statusCode: code);
      }
      if (code == 403 || code == 429) {
        return AppException(AppErrorType.accessDenied, statusCode: code);
      }
      if (code == 404) {
        return AppException(AppErrorType.notFound, statusCode: code);
      }
      if (code != null && code >= 500) {
        return AppException(AppErrorType.server, statusCode: code);
      }
      return AppException(AppErrorType.unknown, statusCode: code);
    case DioExceptionType.unknown:
      if (e.error is SocketException) {
        return AppException(AppErrorType.noInternet, debugMessage: e.message);
      }
      return AppException(AppErrorType.unknown, debugMessage: e.message);
  }
}

/// Retry terbatas: maksimal 2 kali, hanya untuk GET dan error jaringan.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const _maxRetries = 2;
  static const _retryKey = 'retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final attempt = (req.extra[_retryKey] as int?) ?? 0;

    if (req.method.toUpperCase() == 'GET' &&
        attempt < _maxRetries &&
        mapDioException(err).isRetryable) {
      req.extra[_retryKey] = attempt + 1;
      await Future<void>.delayed(Duration(seconds: attempt + 1));
      try {
        final response = await _dio.fetch<dynamic>(req);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    handler.next(err);
  }
}

/// Log request hanya saat debug. Header tidak dicatat agar token tidak bocor.
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    appLogger.d('HTTP ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    appLogger.d('HTTP ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    appLogger.w('HTTP error ${err.type} ${err.requestOptions.uri}');
    handler.next(err);
  }
}