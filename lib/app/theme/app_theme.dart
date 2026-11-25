import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFFB58ACB);
  static const Color background = Color(0xFF15131C);
  static const Color lightBackground = Color(0xFFFBF8FD);

  // Tema sementara. Desain final dikerjakan di Phase 8.
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}
