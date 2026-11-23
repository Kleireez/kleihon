import '../../domain/entities/reading_status.dart';
import '../../domain/usecases/library_logic.dart';

extension ReadingStatusLabel on ReadingStatus {
  String get label => switch (this) {
    ReadingStatus.unread => 'Belum dibaca',
    ReadingStatus.reading => 'Sedang dibaca',
    ReadingStatus.completed => 'Selesai',
  };
}

extension LibraryCategoryLabel on LibraryCategory {
  String get label => switch (this) {
    LibraryCategory.all => 'Semua',
    LibraryCategory.reading => 'Sedang dibaca',
    LibraryCategory.unread => 'Belum dibaca',
    LibraryCategory.completed => 'Selesai',
    LibraryCategory.following => 'Diikuti',
  };
}

extension LibrarySortLabel on LibrarySort {
  String get label => switch (this) {
    LibrarySort.recent => 'Terbaru dibaca',
    LibrarySort.title => 'Judul A-Z',
  };
}
