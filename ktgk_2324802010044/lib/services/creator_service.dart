import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class CreatorService {
  static final _dio = DioClient.instance;

  /// GET /creators/{id}
  static Future<Map<String, dynamic>?> getCreatorDetail(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/creators/$id',
        queryParameters: {'page': page, 'limit': limit},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(e.response?.data?['detail'] ?? 'Failed to load creator detail');
    }
  }

  /// Creator manga are returned inside GET /creators/{id}.
  static Future<List<Map<String, dynamic>>> getCreatorMangas(
    String id, {
    int page = 1,
    int limit = 20,
  }) async {
    final detail = await getCreatorDetail(id, page: page, limit: limit);
    final mangas = detail?['mangas'];
    if (mangas is Map && mangas['items'] is List) {
      return (mangas['items'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
