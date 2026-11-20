enum AppErrorType {
  noInternet,
  timeout,
  server,
  notFound,
  accessDenied,
  authRequired,
  parsing,
  image,
  cancelled,
  unknown,
}

class AppException implements Exception {
  const AppException(this.type, {this.statusCode, this.debugMessage});

  final AppErrorType type;
  final int? statusCode;

  /// Hanya untuk log developer. Jangan ditampilkan ke pengguna.
  final String? debugMessage;

  /// Pesan yang boleh ditampilkan ke pengguna.
  String get userMessage {
    switch (type) {
      case AppErrorType.noInternet:
        return 'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.';
      case AppErrorType.timeout:
        return 'Permintaan terlalu lama. Silakan coba lagi.';
      case AppErrorType.server:
        return 'Server sedang bermasalah. Coba lagi beberapa saat lagi.';
      case AppErrorType.notFound:
        return 'Data yang dicari tidak ditemukan.';
      case AppErrorType.accessDenied:
        return 'Akses ditolak oleh sumber.';
      case AppErrorType.authRequired:
        return 'Sumber ini membutuhkan login.';
      case AppErrorType.parsing:
        return 'Data dari sumber tidak dapat dibaca.';
      case AppErrorType.image:
        return 'Gambar gagal dimuat.';
      case AppErrorType.cancelled:
        return 'Permintaan dibatalkan.';
      case AppErrorType.unknown:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  /// Error yang masuk akal untuk dicoba ulang.
  bool get isRetryable =>
      type == AppErrorType.noInternet ||
      type == AppErrorType.timeout ||
      type == AppErrorType.server;

  @override
  String toString() =>
      'AppException($type, status: $statusCode, $debugMessage)';
}
