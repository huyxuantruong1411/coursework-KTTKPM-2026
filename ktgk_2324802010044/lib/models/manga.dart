class Manga {
  final String id;
  final String title;
  final String coverUrl;
  final String description;
  final String author;
  final String artist;
  final String status;
  final List<String> genres;
  final List<String> themes;
  final String demographic;
  final String contentRating;
  final int? year;
  final List<String> altTitles;
  final String originalLanguage;
  final String? lastChapter;
  final String? lastVolume;
  final List<Map<String, dynamic>> creators;
  final String? coverFileName;

  // Backend stats.
  final int views;
  final int follows;
  final double rating;

  Manga({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.description = 'No description available.',
    this.author = 'Unknown',
    this.artist = '',
    this.status = 'Unknown',
    this.genres = const [],
    this.themes = const [],
    this.demographic = '',
    this.contentRating = '',
    this.year,
    this.altTitles = const [],
    this.originalLanguage = '',
    this.lastChapter,
    this.lastVolume,
    this.creators = const [],
    this.coverFileName,
    this.views = 0,
    this.follows = 0,
    this.rating = 0.0,
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    final creators = _normalizeCreators(json['creators'] ?? json['Creators']);
    final stats = _asMap(json['stats'] ?? json['Stats']);
    final tags = _asList(json['tags'] ?? json['Tags']);

    return Manga(
      id: _string(json['MangaId'] ?? json['manga_id'] ?? json['id']),
      title: _string(
        json['TitleEn'] ?? json['title'] ?? json['Title'],
        fallback: 'Unknown',
      ),
      coverUrl: _normalizeCoverUrl(
        json['cover_url'] ?? json['CoverUrl'] ?? json['coverUrl'],
      ),
      description: _extractDescription(json),
      author: _extractCreatorByRole(
        creators,
        'author',
        fallback: _string(
          json['Author'] ??
              json['author'] ??
              json['author_name'] ??
              json['AuthorName'],
          fallback: creators.isNotEmpty
              ? creators.first['name'].toString()
              : 'Unknown',
        ),
      ),
      artist: _extractCreatorByRole(
        creators,
        'artist',
        fallback: _string(
          json['Artist'] ??
              json['artist'] ??
              json['artist_name'] ??
              json['ArtistName'],
        ),
      ),
      status: _string(json['Status'] ?? json['status'], fallback: 'Unknown'),
      genres: _extractTagsByGroup(
        tags,
        'genre',
        fallback: _stringList(json['Genres'] ?? json['genres']),
      ),
      themes: _extractTagsByGroup(
        tags,
        'theme',
        fallback: _stringList(json['Themes'] ?? json['themes']),
      ),
      demographic: _string(
        json['PublicationDemographic'] ??
            json['publication_demographic'] ??
            json['Demographic'] ??
            json['demographic'],
      ),
      contentRating: _string(json['ContentRating'] ?? json['content_rating']),
      year: _intOrNull(json['Year'] ?? json['year']),
      altTitles: _extractAltTitles(json),
      originalLanguage: _string(
        json['OriginalLanguage'] ?? json['original_language'],
      ),
      lastChapter: _nullableString(json['LastChapter'] ?? json['last_chapter']),
      lastVolume: _nullableString(json['LastVolume'] ?? json['last_volume']),
      creators: creators,
      coverFileName: _nullableString(json['cover_file_name'] ?? json['CoverFileName']),
      views: _int(json['Views'] ?? json['views']),
      follows: _int(
        stats['Follows'] ??
            stats['follows'] ??
            json['Follows'] ??
            json['follows'],
      ),
      rating: _double(
        stats['AverageRating'] ??
            stats['average_rating'] ??
            json['Rating'] ??
            json['rating'],
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const [];
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString();
    return str.isEmpty ? fallback : str;
  }

  static String _normalizeCoverUrl(dynamic value) {
    final raw = _string(value);
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    return 'https://placehold.co/256x360/2C2C2C/FF6740/png?text=No+Cover';
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _double(dynamic value, {double fallback = 0.0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map) {
            return _string(
              item['NameEn'] ??
                  item['name'] ??
                  item['title'] ??
                  item['AltTitle'],
            );
          }
          return _string(item);
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _extractDescription(Map<String, dynamic> json) {
    final direct = _string(
      json['DescriptionEn'] ?? json['description'] ?? json['Description'],
    );
    if (direct.isNotEmpty) return direct;

    final descriptions = _asList(json['descriptions'] ?? json['Descriptions']);
    Map? english;
    for (final item in descriptions) {
      if (item is Map &&
          _string(item['LangCode'] ?? item['lang']).toLowerCase() == 'en') {
        english = item;
        break;
      }
    }
    final selected = english ?? descriptions.whereType<Map>().firstOrNull;
    final text = _string(selected?['Description'] ?? selected?['description']);
    return text.isNotEmpty ? text : 'No description available.';
  }

  static List<String> _extractAltTitles(Map<String, dynamic> json) {
    final raw = json['alt_titles'] ?? json['AltTitles'] ?? json['altTitles'];
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is Map) {
            return _string(
              item['AltTitle'] ?? item['alt_title'] ?? item['title'],
            );
          }
          return _string(item);
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _normalizeCreators(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          return {
            'id': _string(
              item['id'] ?? item['CreatorId'] ?? item['creator_id'],
            ),
            'name': _string(item['name'] ?? item['Name']),
            'role': _string(
              item['role'] ?? item['Type'] ?? item['type'],
            ).toLowerCase(),
          };
        })
        .where((item) => item['name'].toString().isNotEmpty)
        .toList();
  }

  static String _extractCreatorByRole(
    List<Map<String, dynamic>> creators,
    String role, {
    String fallback = '',
  }) {
    for (final creator in creators) {
      if (creator['role'] == role && creator['name'].toString().isNotEmpty) {
        return creator['name'].toString();
      }
    }
    return fallback;
  }

  static List<String> _extractTagsByGroup(
    List<dynamic> tags,
    String group, {
    List<String> fallback = const [],
  }) {
    final values = tags
        .whereType<Map>()
        .where((tag) {
          return _string(
                tag['GroupName'] ?? tag['group'] ?? tag['group_name'],
              ).toLowerCase() ==
              group;
        })
        .map((tag) => _string(tag['NameEn'] ?? tag['name']))
        .where((name) => name.isNotEmpty)
        .toList();
    return values.isNotEmpty ? values : fallback;
  }
}
