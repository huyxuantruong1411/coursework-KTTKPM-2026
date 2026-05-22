class Chapter {
  final String id;
  final String title;
  final String chapter;
  final String volume;
  final String language;
  final String group;
  final int pages;
  final DateTime? publishAt;
  final DateTime? createdAt;
  final String? externalUrl;

  Chapter({
    required this.id,
    this.title = '',
    this.chapter = '',
    this.volume = '',
    this.language = 'en',
    this.group = 'Unknown',
    this.pages = 0,
    this.publishAt,
    this.createdAt,
    this.externalUrl,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['ChapterId']?.toString() ?? json['chapter_id']?.toString() ?? json['id']?.toString() ?? '',
      title: (json['Title'] ?? json['title'] ?? '').toString(),
      chapter: (json['ChapterNumber'] ?? json['chapter_number'] ?? json['chapter'] ?? '').toString(),
      volume: (json['Volume'] ?? json['volume'] ?? '').toString(),
      language: (json['TranslatedLang'] ?? json['translated_lang'] ?? json['Language'] ?? json['language'] ?? 'en').toString(),
      group: (json['ScanlationGroup'] ?? json['scanlation_group'] ?? json['group'] ?? 'Unknown').toString(),
      pages: json['Pages'] is int
          ? json['Pages']
          : json['pages'] is int
              ? json['pages']
              : int.tryParse((json['Pages'] ?? json['pages'] ?? '0').toString()) ?? 0,
      publishAt: json['PublishAt'] != null 
          ? DateTime.tryParse(json['PublishAt'].toString())
          : json['publish_at'] != null 
              ? DateTime.tryParse(json['publish_at'].toString())
              : null,
      createdAt: json['CreatedAt'] != null 
          ? DateTime.tryParse(json['CreatedAt'].toString())
          : json['created_at'] != null 
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      externalUrl: json['ExternalUrl']?.toString() ?? json['external_url']?.toString(),
    );
  }
}
