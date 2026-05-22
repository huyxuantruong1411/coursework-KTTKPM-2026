import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/dio_client.dart';
import '../models/manga.dart';
import 'manga_service.dart';
import 'mangadex_api.dart';

class RecommendationService {
  static final _dio = DioClient.instance;

  static Future<List<Manga>> getSimilarManga(
    String mangaId, {
    int limit = 12,
  }) async {
    try {
      final response = await _dio.get(
        '/recommendations/manga/$mangaId/similar',
        queryParameters: {'limit': limit},
      );
      final recommendations = _extractRecommendations(response.data);
      final resolved = await _resolveRecommendations(
        recommendations,
        limit: limit,
      );
      if (resolved.isNotEmpty) return resolved;
    } on DioException catch (e) {
      debugPrint(
        'RecommendationService.getSimilarManga error: ${e.response?.data}',
      );
    }

    return _fetchMangaDexRecommendations(mangaId, limit: limit);
  }

  static List<Map<String, dynamic>> _extractRecommendations(dynamic data) {
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map && data['recommendations'] is List) {
      return (data['recommendations'] as List).cast<Map<String, dynamic>>();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static String _idOf(Map<String, dynamic> item) {
    return item['MangaId']?.toString() ??
        item['manga_id']?.toString() ??
        item['id']?.toString() ??
        '';
  }

  static Map<String, dynamic> _inlineMangaJson(Map<String, dynamic> item) {
    return {
      'MangaId': _idOf(item),
      'TitleEn': item['TitleEn'] ?? item['title'] ?? item['Title'],
      'cover_url': item['cover_url'] ?? item['CoverUrl'] ?? item['coverUrl'],
      'Status': item['Status'] ?? item['status'],
      'Year': item['Year'] ?? item['year'],
      'ContentRating': item['ContentRating'] ?? item['content_rating'],
      'stats': item['stats'],
    };
  }

  static Future<List<Manga>> _resolveRecommendations(
    List<Map<String, dynamic>> items, {
    required int limit,
  }) async {
    final mangas = <Manga>[];
    final seen = <String>{};
    final mangadex = MangaDexApi();

    for (final item in items) {
      if (mangas.length >= limit) break;
      final id = _idOf(item);
      if (id.isEmpty || !seen.add(id)) continue;

      final inline = _inlineMangaJson(item);
      final inlineTitle = inline['TitleEn']?.toString() ?? '';
      final inlineCover = inline['cover_url']?.toString() ?? '';
      if (inlineTitle.isNotEmpty && inlineCover.isNotEmpty) {
        mangas.add(Manga.fromJson(inline));
        continue;
      }

      final backendDetail = await MangaService.getMangaDetail(id);
      if (backendDetail != null) {
        mangas.add(Manga.fromJson(backendDetail));
        continue;
      }

      final mangadexDetail = await mangadex.getMangaDetail(id);
      if (mangadexDetail != null) mangas.add(mangadexDetail);
    }

    return mangas;
  }

  static Future<List<Manga>> _fetchMangaDexRecommendations(
    String mangaId, {
    required int limit,
  }) async {
    try {
      final response = await DioClient.mangadex.get(
        '/manga/$mangaId/recommendation',
        queryParameters: {
          'order[score]': 'desc',
          'contentRating[]': ['safe', 'suggestive', 'erotica'],
        },
      );
      final data = response.data['data'] as List? ?? [];
      final ids = <String>[];
      for (final entry in data) {
        if (entry is! Map) continue;
        final relationships = entry['relationships'] as List? ?? [];
        for (final rel in relationships) {
          if (rel is Map && rel['type'] == 'manga' && rel['id'] != mangaId) {
            final id = rel['id']?.toString() ?? '';
            if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
            break;
          }
        }
        if (ids.length >= limit) break;
      }

      final mangadex = MangaDexApi();
      final mangas = <Manga>[];
      for (final id in ids) {
        final manga = await mangadex.getMangaDetail(id);
        if (manga != null) mangas.add(manga);
      }
      return mangas;
    } catch (e) {
      debugPrint('RecommendationService MangaDex fallback error: $e');
      return [];
    }
  }
}
