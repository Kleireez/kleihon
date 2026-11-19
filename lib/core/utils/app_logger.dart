import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Logger aplikasi. Di build release hanya mencatat warning ke atas.
final Logger appLogger = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true),
);