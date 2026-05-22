class ReadingHistoryItem {
  final String historyId;
  final String mangaId;
  final String chapterId;
  final int? lastPageRead;
  final DateTime? readAt;
  final String? mangaTitle;
  final String? chapterNumber;
  final String? coverUrl;

  ReadingHistoryItem({
    required this.historyId,
    required this.mangaId,
    required this.chapterId,
    this.lastPageRead,
    this.readAt,
    this.mangaTitle,
    this.chapterNumber,
    this.coverUrl,
  });

  factory ReadingHistoryItem.fromJson(Map<String, dynamic> json) {
    return ReadingHistoryItem(
      historyId: json['HistoryId']?.toString() ?? json['history_id']?.toString() ?? '',
      mangaId: json['MangaId']?.toString() ?? json['manga_id']?.toString() ?? '',
      chapterId: json['ChapterId']?.toString() ?? json['chapter_id']?.toString() ?? '',
      lastPageRead: json['LastPageRead'] ?? json['last_page_read'] ?? json['last_page'],
      readAt: json['ReadAt'] != null
          ? DateTime.tryParse(json['ReadAt'])
          : json['read_at'] != null
              ? DateTime.tryParse(json['read_at'])
              : null,
      mangaTitle: json['MangaTitle'] ?? json['manga_title'],
      chapterNumber: json['ChapterNumber'] ?? json['chapter_number'],
      coverUrl: json['CoverUrl'] ?? json['cover_url'],
    );
  }
}
