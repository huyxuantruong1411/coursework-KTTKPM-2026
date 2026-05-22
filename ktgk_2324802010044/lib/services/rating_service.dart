import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class RatingService {
  static final _dio = DioClient.instance;

  /// Rating summary is provided inline by GET /mangas/{id}. Kept for callers
  /// that still expect this method to exist.
  static Future<Map<String, dynamic>> getRatingSummary(String mangaId) async {
    try {
      final response = await _dio.get('/mangas/$mangaId');
      final data = response.data as Map<String, dynamic>;
      final stats = data['stats'];
      return stats is Map<String, dynamic> ? stats : {};
    } on DioException catch (e) {
      debugPrint('RatingService.getRatingSummary error: ${e.response?.data}');
      return {};
    }
  }

  /// GET /ratings/manga/{manga_id}/my-rating
  static Future<int?> getMyRating(String mangaId) async {
    try {
      final response = await _dio.get('/ratings/manga/$mangaId/my-rating');
      final data = response.data as Map<String, dynamic>;
      final raw = data['score'] ?? data['Score'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        return null;
      }
      debugPrint('RatingService.getMyRating error: ${e.response?.data}');
      return null;
    }
  }

  /// POST /ratings/manga/{manga_id}/rate body: {Score}
  static Future<void> rateManga(String mangaId, int score) async {
    try {
      await _dio.post('/ratings/manga/$mangaId/rate', data: {'Score': score});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to rate');
    }
  }

  static Future<void> deleteRating(String mangaId) async {
    throw UnsupportedError('Backend does not support deleting ratings.');
  }
}
