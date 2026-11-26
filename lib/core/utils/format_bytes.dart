/// Ukuran berkas yang mudah dibaca, dengan koma desimal: "512 B", "1,5 KB",
/// "150 MB". Angka negatif dianggap 0.
String formatBytes(int bytes) {
  final safe = bytes < 0 ? 0 : bytes;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];

  var value = safe.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }

  if (unit == 0) return '$safe B';
  final text = value.toStringAsFixed(value >= 100 ? 0 : 1).replaceAll('.', ',');
  return '$text ${units[unit]}';
}
