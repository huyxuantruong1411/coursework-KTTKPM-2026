import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class MangaService {
  static final _dio = DioClient.instance;

  static Map<String, dynamic> _paginatedFallback([
    List<Map<String, dynamic>>? items,
  ]) {
    final list = items ?? <Map<String, dynamic>>[];
    return {
      'items': list,
      'total': list.length,
      'page': 1,
      'per_page': list.length,
      'total_pages': list.isEmpty ? 0 : 1,
    };
  }

  static Map<String, dynamic> _normalizePaginated(dynamic data) {
    if (data is List) {
      return _paginatedFallback(data.cast<Map<String, dynamic>>());
    }
    if (data is Map<String, dynamic>) {
      if (data['items'] is List) {
        return data;
      }
      if (data['manga'] is List) {
        return {
          ...data,
          'items': data['manga'],
          'total': data['total'] ?? (data['manga'] as List).length,
        };
      }
    }
    return _paginatedFallback();
  }

  static String _mangaIdOf(Map<String, dynamic> item) {
    return item['MangaId']?.toString() ??
        item['manga_id']?.toString() ??
        item['id']?.toString() ??
        '';
  }

  static bool _needsDetailEnrichment(Map<String, dynamic> item) {
    final hasCreator =
        item['creators'] is List ||
        item['Creators'] is List ||
        item['author'] != null ||
        item['Author'] != null ||
        item['author_name'] != null;
    final hasDescription =
        item['descriptions'] is List ||
        item['Descriptions'] is List ||
        item['description'] != null ||
        item['Description'] != null ||
        item['DescriptionEn'] != null;
    final hasCover =
        (item['cover_url'] ?? item['CoverUrl'] ?? item['coverUrl'])
            ?.toString()
            .isNotEmpty ==
        true;
    return !hasCreator || !hasDescription || !hasCover;
  }

  static Future<Map<String, dynamic>> _enrichItemWithDetail(
    Map<String, dynamic> item,
  ) async {
    final mangaId = _mangaIdOf(item);
    if (mangaId.isEmpty || !_needsDetailEnrichment(item)) return item;
    try {
      final detail = await getMangaDetail(mangaId);
      if (detail == null) return item;
      return {
        ...item,
        ...detail,
        'manga_id': item['manga_id'] ?? detail['MangaId'] ?? mangaId,
        'predicted_score': item['predicted_score'],
        'score': item['score'],
        'source': item['source'],
      };
    } catch (_) {
      return item;
    }
  }

  static Future<List<Map<String, dynamic>>> _enrichItemsWithDetails(
    List<Map<String, dynamic>> items,
  ) async {
    return Future.wait(items.map(_enrichItemWithDetail));
  }

  static Future<Map<String, dynamic>> _normalizeAndEnrichPaginated(
    dynamic data,
  ) async {
    final normalized = _normalizePaginated(data);
    final items = ((normalized['items'] ?? []) as List)
        .cast<Map<String, dynamic>>();
    return {...normalized, 'items': await _enrichItemsWithDetails(items)};
  }

  /// GET /mangas/?page=&limit=&sort=&status=&content_rating=&demographic=&year=
  static Future<Map<String, dynamic>> getMangaList({
    int page = 1,
    int limit = 20,
    String? sort,
    String? status,
    String? contentRating,
    String? demographic,
    int? year,
    // Kept for older call sites. Query/tag filters belong to searchManga.
    String? query,
    String? tag,
  }) async {
    if ((query != null && query.isNotEmpty) ||
        (tag != null && tag.isNotEmpty)) {
      return searchManga(
        query: query ?? '',
        page: page,
        limit: limit,
        sort: sort,
        status: status,
        contentRating: contentRating,
        demographic: demographic,
        yearFrom: year,
        yearTo: year,
        includeTags: tag != null && tag.isNotEmpty ? tag.split(',') : null,
      );
    }

    try {
      final params = <String, dynamic>{'page': page, 'limit': limit};
      if (sort != null) params['sort'] = sort;
      if (status != null) params['status'] = status;
      if (contentRating != null) params['content_rating'] = contentRating;
      if (demographic != null) params['demographic'] = demographic;
      if (year != null) params['year'] = year;

      final response = await _dio.get('/mangas/', queryParameters: params);
      return _normalizePaginated(response.data);
    } on DioException catch (e) {
      debugPrint('MangaService.getMangaList error: ${e.response?.data}');
      return _paginatedFallback();
    }
  }

  /// GET /mangas/{id}
  static Future<Map<String, dynamic>?> getMangaDetail(String mangaId) async {
    try {
      final response = await _dio.get('/mangas/$mangaId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint('MangaService.getMangaDetail error: ${e.response?.data}');
      return null;
    }
  }

  /// Rating/follow stats are returned inline by GET /mangas/{id}.
  static Future<Map<String, dynamic>> getMangaStats(String mangaId) async {
    final detail = await getMangaDetail(mangaId);
    final stats = detail?['stats'];
    return stats is Map<String, dynamic> ? stats : {};
  }

  /// GET /mangas/?sort=follows_desc&limit=
  static Future<List<Map<String, dynamic>>> getPopularManga({
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/mangas/',
        queryParameters: {'limit': limit, 'sort': 'follows_desc'},
      );
      return (_normalizePaginated(response.data)['items'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('MangaService.getPopularManga error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /mangas/latest-updates?limit=
  static Future<List<Map<String, dynamic>>> getRecentManga({
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/mangas/latest-updates',
        queryParameters: {'limit': limit},
      );
      return (_normalizePaginated(response.data)['items'] as List)
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('MangaService.getRecentManga error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /recommendations/for-me?top_n=
  static Future<List<Map<String, dynamic>>> getRecommendations({
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/recommendations/for-me',
        queryParameters: {'top_n': limit},
      );
      final data = response.data;
      if (data is List) {
        return _enrichItemsWithDetails(data.cast<Map<String, dynamic>>());
      }
      if (data is Map && data['recommendations'] is List) {
        return _enrichItemsWithDetails(
          (data['recommendations'] as List).cast<Map<String, dynamic>>(),
        );
      }
      if (data is Map && data['items'] is List) {
        return _enrichItemsWithDetails(
          (data['items'] as List).cast<Map<String, dynamic>>(),
        );
      }
      return [];
    } on DioException catch (e) {
      debugPrint('MangaService.getRecommendations error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /mangas/search for simple search, /mangas/advanced-search for filters.
  static Future<Map<String, dynamic>> searchManga({
    required String query,
    int page = 1,
    int limit = 20,
    List<String>? includeTags,
    List<String>? excludeTags,
    String? status,
    String? contentRating,
    String? demographic,
    int? yearFrom,
    int? yearTo,
    String? originalLang,
    String? sort,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (query.isNotEmpty) params['q'] = query;
    if (includeTags != null && includeTags.isNotEmpty) {
      params['include_tags'] = includeTags.join(',');
    }
    if (excludeTags != null && excludeTags.isNotEmpty) {
      params['exclude_tags'] = excludeTags.join(',');
    }
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (contentRating != null && contentRating.isNotEmpty) {
      params['content_rating'] = contentRating;
    }
    if (demographic != null && demographic.isNotEmpty) {
      params['demographic'] = demographic;
    }
    if (yearFrom != null) params['year_from'] = yearFrom;
    if (yearTo != null) params['year_to'] = yearTo;
    if (originalLang != null && originalLang.isNotEmpty) {
      params['original_lang'] = originalLang;
    }
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;

    final hasAdvancedFilters =
        (includeTags != null && includeTags.isNotEmpty) ||
        (excludeTags != null && excludeTags.isNotEmpty) ||
        status != null ||
        contentRating != null ||
        demographic != null ||
        yearFrom != null ||
        yearTo != null ||
        originalLang != null ||
        sort != null ||
        page > 1;

    if (!hasAdvancedFilters) {
      try {
        final response = await _dio.get(
          '/mangas/search',
          queryParameters: {'q': query, 'limit': limit},
        );
        return _normalizeAndEnrichPaginated(response.data);
      } on DioException catch (e) {
        debugPrint(
          'MangaService.searchManga simple error: ${e.response?.data}',
        );
      }
    }

    try {
      final response = await _dio.get(
        '/mangas/advanced-search',
        queryParameters: params,
      );
      return _normalizeAndEnrichPaginated(response.data);
    } on DioException catch (e) {
      debugPrint('MangaService.searchManga error: ${e.response?.data}');
      return _paginatedFallback();
    }
  }

  /// GET /tags/
  static Future<List<Map<String, dynamic>>> getTags() async {
    try {
      final response = await _dio.get('/tags/');
      final data = response.data;
      if (data is List) {
        final normalized = <Map<String, dynamic>>[];
        for (final entry in data) {
          if (entry is! Map) continue;
          if (entry['tags'] is List) {
            final group =
                entry['group_name']?.toString() ??
                entry['group']?.toString() ??
                'other';
            for (final tag in entry['tags'] as List) {
              if (tag is! Map) continue;
              normalized.add({
                'id': tag['TagId']?.toString() ?? tag['id']?.toString() ?? '',
                'name': tag['NameEn'] ?? tag['name'] ?? '',
                'group': tag['GroupName'] ?? tag['group'] ?? group,
              });
            }
          } else {
            normalized.add({
              'id': entry['TagId']?.toString() ?? entry['id']?.toString() ?? '',
              'name': entry['NameEn'] ?? entry['name'] ?? '',
              'group': entry['GroupName'] ?? entry['group'] ?? 'other',
            });
          }
        }
        return normalized
            .where((tag) => tag['id'].toString().isNotEmpty)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('MangaService.getTags error: ${e.response?.data}');
      return [];
    }
  }
}
