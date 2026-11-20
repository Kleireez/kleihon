/// Semua alamat rute di satu tempat, supaya tidak ada string yang tersebar.
abstract final class AppRoutes {
  static const home = '/home';
  static const explore = '/explore';
  static const library = '/library';
  static const history = '/history';
  static const settings = '/settings';
  static const localImport = '/import';

  static const comicPattern = '/comic/:sourceId/:comicId';
  static const readerPattern = '/reader/:sourceId/:chapterId';

  static String comic(String sourceId, String comicId) =>
      '/comic/${Uri.encodeComponent(sourceId)}/${Uri.encodeComponent(comicId)}';

  static String reader(String sourceId, String chapterId) =>
      '/reader/${Uri.encodeComponent(sourceId)}/${Uri.encodeComponent(chapterId)}';
}
