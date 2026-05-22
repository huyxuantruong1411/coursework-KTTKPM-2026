import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/manga.dart';

class MangaDexApi {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.mangadex.org'));

  // Tag cache to avoid repeated API calls
  static List<Map<String, dynamic>>? _cachedTags;

  // ---------- PARSE HELPERS ----------
  Manga _parseMangaItem(Map<String, dynamic> item) {
    final id = item['id'];
    final attrs = item['attributes'];
    final title =
        attrs['title']['en'] ?? attrs['title'].values.first ?? 'Unknown';
    final description =
        attrs['description'] != null && attrs['description'].isNotEmpty
        ? (attrs['description']['en'] ??
              attrs['description']['vi'] ??
              'Chưa có tóm tắt.')
        : 'Chưa có tóm tắt.';
    final status = attrs['status'] ?? 'Unknown';
    final demographic = attrs['publicationDemographic'] ?? '';
    final contentRating = attrs['contentRating'] ?? '';
    final year = attrs['year'] as int?;
    final originalLanguage = attrs['originalLanguage'] ?? '';
    final lastChapter = attrs['lastChapter'] as String?;
    final lastVolume = attrs['lastVolume'] as String?;

    // Alt titles
    List<String> altTitles = [];
    if (attrs['altTitles'] != null) {
      for (var alt in attrs['altTitles']) {
        if (alt is Map) {
          altTitles.addAll(alt.values.map((v) => v.toString()));
        }
      }
    }

    // Tags → genres + themes
    List<String> genres = [];
    List<String> themes = [];
    if (attrs['tags'] != null) {
      for (var tag in attrs['tags']) {
        final tagName = tag['attributes']?['name']?['en'];
        final group = tag['attributes']?['group'];
        if (tagName != null) {
          if (group == 'theme') {
            themes.add(tagName);
          } else {
            genres.add(tagName);
          }
        }
      }
    }

    // Relationships → author, artist, cover
    String coverFileName = '';
    String authorName = 'Đang cập nhật';
    String artistName = '';
    if (item['relationships'] != null) {
      for (var rel in item['relationships']) {
        if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
          coverFileName = rel['attributes']['fileName'] ?? '';
        } else if (rel['type'] == 'author' && rel['attributes'] != null) {
          authorName = rel['attributes']['name'] ?? 'Đang cập nhật';
        } else if (rel['type'] == 'artist' && rel['attributes'] != null) {
          artistName = rel['attributes']['name'] ?? '';
        }
      }
    }

    final coverUrl = coverFileName.isNotEmpty
        ? 'https://uploads.mangadex.org/covers/$id/$coverFileName.256.jpg'
        : 'https://via.placeholder.com/256';

    return Manga(
      id: id,
      title: title,
      coverUrl: coverUrl,
      description: description,
      author: authorName,
      artist: artistName,
      status: status,
      genres: genres,
      themes: themes,
      demographic: demographic,
      contentRating: contentRating,
      year: year,
      altTitles: altTitles,
      originalLanguage: originalLanguage,
      lastChapter: lastChapter,
      lastVolume: lastVolume,
    );
  }

  // ---------- GET ALL TAGS ----------
  /// Fetches all manga tags from MangaDex API.
  /// Returns a list of maps with: id, name, group (genre/theme/format/content)
  /// Results are cached after the first call.
  Future<List<Map<String, dynamic>>> getTags() async {
    if (_cachedTags != null) return _cachedTags!;
    try {
      final response = await _dio.get('/manga/tag');
      final data = response.data['data'] as List;
      _cachedTags = data.map((tag) {
        return {
          'id': tag['id'] as String,
          'name': tag['attributes']['name']['en'] ?? tag['attributes']['name'].values.first ?? '',
          'group': tag['attributes']['group'] ?? '',
        };
      }).toList();
      // Sort by group then name
      _cachedTags!.sort((a, b) {
        final g = (a['group'] as String).compareTo(b['group'] as String);
        if (g != 0) return g;
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      return _cachedTags!;
    } catch (e) {
      debugPrint('API Tags Error: $e');
      return [];
    }
  }

  // ---------- SEARCH MANGA (ENHANCED) ----------
  Future<List<Manga>> searchManga({
    String query = '',
    List<String>? includedTags,
    List<String>? excludedTags,
    String? sortBy,
    String sortOrder = 'desc',
    List<String>? contentRating,
    List<String>? publicationDemographic,
    List<String>? status,
    int? year,
    List<String>? originalLanguage,
    bool? hasAvailableChapters,
    List<String>? availableTranslatedLanguage,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Map<String, dynamic> params = {
        'includes[]': ['cover_art', 'author', 'artist'],
        'limit': limit,
        'offset': offset,
      };

      if (query.isNotEmpty) params['title'] = query;

      if (includedTags != null && includedTags.isNotEmpty) {
        params['includedTags[]'] = includedTags;
      }
      if (excludedTags != null && excludedTags.isNotEmpty) {
        params['excludedTags[]'] = excludedTags;
      }

      // Sort
      if (sortBy != null && sortBy.isNotEmpty) {
        params['order[$sortBy]'] = sortOrder;
      }

      // Content rating filter
      if (contentRating != null && contentRating.isNotEmpty) {
        params['contentRating[]'] = contentRating;
      } else {
        // Default: show safe + suggestive
        params['contentRating[]'] = ['safe', 'suggestive', 'erotica'];
      }

      // Demographic
      if (publicationDemographic != null && publicationDemographic.isNotEmpty) {
        params['publicationDemographic[]'] = publicationDemographic;
      }

      // Publication status
      if (status != null && status.isNotEmpty) {
        params['status[]'] = status;
      }

      // Year
      if (year != null) {
        params['year'] = year;
      }

      // Original language
      if (originalLanguage != null && originalLanguage.isNotEmpty) {
        params['originalLanguage[]'] = originalLanguage;
      }

      // Has available chapters
      if (hasAvailableChapters != null) {
        params['hasAvailableChapters'] = hasAvailableChapters ? 'true' : 'false';
      }

      // Available translated language
      if (availableTranslatedLanguage != null && availableTranslatedLanguage.isNotEmpty) {
        params['availableTranslatedLanguage[]'] = availableTranslatedLanguage;
      }

      final response = await _dio.get('/manga', queryParameters: params);
      final data = response.data['data'] as List;
      return data.map((item) => _parseMangaItem(item)).toList();
    } catch (e) {
      debugPrint('API Manga Error: $e');
      return [];
    }
  }

  // ---------- GET SINGLE MANGA DETAIL ----------
  Future<Manga?> getMangaDetail(String mangaId) async {
    try {
      final response = await _dio.get(
        '/manga/$mangaId',
        queryParameters: {
          'includes[]': ['cover_art', 'author', 'artist'],
        },
      );
      return _parseMangaItem(response.data['data']);
    } catch (e) {
      debugPrint('API Manga Detail Error: $e');
      return null;
    }
  }

  // ---------- GET MANGA CHAPTERS (enhanced) ----------
  Future<List<Map<String, dynamic>>> getMangaChapters(
    String mangaId, {
    int limit = 100,
    int offset = 0,
    String orderDirection = 'asc',
    List<String> languages = const ['en', 'vi'],
  }) async {
    try {
      final response = await _dio.get(
        '/manga/$mangaId/feed',
        queryParameters: {
          'translatedLanguage[]': languages,
          'order[chapter]': orderDirection,
          'limit': limit,
          'offset': offset,
          'includes[]': ['scanlation_group'],
        },
      );
      final data = response.data['data'] as List;
      return data.map((item) {
        // Extract scanlation group
        String groupName = '';
        if (item['relationships'] != null) {
          for (var rel in item['relationships']) {
            if (rel['type'] == 'scanlation_group' &&
                rel['attributes'] != null) {
              groupName = rel['attributes']['name'] ?? '';
            }
          }
        }
        return {
          'id': item['id'],
          'chapter': item['attributes']['chapter'] ?? 'Oneshot',
          'title': item['attributes']['title'] ?? '',
          'volume': item['attributes']['volume'] ?? '',
          'pages': item['attributes']['pages'] ?? 0,
          'language': item['attributes']['translatedLanguage'] ?? '',
          'publishAt': item['attributes']['publishAt'] ?? '',
          'group': groupName,
        };
      }).toList();
    } catch (e) {
      debugPrint('API Chapters Error: $e');
      return [];
    }
  }

  // ---------- GET MANGA COVER ART ----------
  Future<List<Map<String, dynamic>>> getMangaCovers(String mangaId) async {
    try {
      final response = await _dio.get(
        '/cover',
        queryParameters: {
          'manga[]': [mangaId],
          'limit': 50,
          'order[volume]': 'asc',
        },
      );
      final data = response.data['data'] as List;
      return data.map((item) {
        final fileName = item['attributes']['fileName'] ?? '';
        return {
          'id': item['id'],
          'fileName': fileName,
          'volume': item['attributes']['volume'] ?? '',
          'description': item['attributes']['description'] ?? '',
          'url': fileName.isNotEmpty
              ? 'https://uploads.mangadex.org/covers/$mangaId/$fileName'
              : '',
          'urlSmall': fileName.isNotEmpty
              ? 'https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg'
              : '',
        };
      }).toList();
    } catch (e) {
      debugPrint('API Covers Error: $e');
      return [];
    }
  }

  // ---------- GET CHAPTER PAGES ----------
  Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final response = await _dio.get('/at-home/server/$chapterId');
      final baseUrl = response.data['baseUrl'];
      final hash = response.data['chapter']['hash'];
      final data = response.data['chapter']['data'] as List;
      return data.map((filename) => '$baseUrl/data/$hash/$filename').toList();
    } catch (e) {
      debugPrint('API Pages Error: $e');
      return [];
    }
  }

  // ---------- GET CHAPTER PAGES (data-saver quality) ----------
  Future<List<String>> getChapterPagesSaver(String chapterId) async {
    try {
      final response = await _dio.get('/at-home/server/$chapterId');
      final baseUrl = response.data['baseUrl'];
      final hash = response.data['chapter']['hash'];
      final data = response.data['chapter']['dataSaver'] as List;
      return data
          .map((filename) => '$baseUrl/data-saver/$hash/$filename')
          .toList();
    } catch (e) {
      debugPrint('API Pages Saver Error: $e');
      return [];
    }
  }
}
