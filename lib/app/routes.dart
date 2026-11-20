/// Semua alamat rute di satu tempat, supaya tidak ada string yang tersebar.
abstract final class AppRoutes {
  static const home = '/home';
  static const explore = '/explore';
  static const library = '/library';
  static const history = '/history';
  static const settings = '/settings';

  static const comicPattern = '/comic/:sourceId/:comicId';
  static const coverPickerPattern = '/comic/:sourceId/:comicId/cover';
  static const readerPattern = '/reader/:sourceId/:chapterId';

  static String comic(String sourceId, String comicId) =>
      '/comic/${Uri.encodeComponent(sourceId)}/${Uri.encodeComponent(comicId)}';

  static String coverPicker(String sourceId, String comicId) =>
      '${comic(sourceId, comicId)}/cover';

  static String reader(String sourceId, String chapterId) =>
      '/reader/${Uri.encodeComponent(sourceId)}/${Uri.encodeComponent(chapterId)}';
}
