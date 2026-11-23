String _two(int value) => value.toString().padLeft(2, '0');

/// Tanggal singkat dd/MM/yyyy dalam waktu lokal.
String formatShortDate(DateTime date) {
  final local = date.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

/// Jam HH:mm dalam waktu lokal.
String formatTimeOfDay(DateTime date) {
  final local = date.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}
