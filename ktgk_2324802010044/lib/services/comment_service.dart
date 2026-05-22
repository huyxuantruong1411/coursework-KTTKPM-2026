import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class CommentService {
  static final _dio = DioClient.instance;

  /// GET /comments/manga/{manga_id}/comments?page=&limit=
  static Future<Map<String, dynamic>> getComments(
    String mangaId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/comments/manga/$mangaId/comments',
        queryParameters: {'page': page, 'limit': limit},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('CommentService.getComments error: ${e.response?.data}');
      return {'items': [], 'total': 0};
    }
  }

  /// POST /comments/manga/{manga_id}/comments body: {Content, IsSpoiler, ChapterId?}
  static Future<Map<String, dynamic>?> postComment(
    String mangaId,
    String content, {
    bool isSpoiler = false,
    String? chapterId,
  }) async {
    try {
      final data = <String, dynamic>{
        'Content': content,
        'IsSpoiler': isSpoiler,
      };
      if (chapterId != null) data['ChapterId'] = chapterId;
      final response = await _dio.post('/comments/manga/$mangaId/comments', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to post comment');
    }
  }

  /// PUT /comments/{comment_id} body: {Content}
  static Future<void> updateComment(String commentId, String content) async {
    try {
      await _dio.put('/comments/$commentId', data: {'Content': content});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update comment');
    }
  }

  /// DELETE /comments/{comment_id}
  static Future<void> deleteComment(String commentId) async {
    try {
      await _dio.delete('/comments/$commentId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete comment');
    }
  }

  static Future<Map<String, dynamic>> likeComment(String commentId) async {
    try {
      final response = await _dio.post('/comments/$commentId/like');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to like comment');
    }
  }

  static Future<Map<String, dynamic>> dislikeComment(String commentId) async {
    try {
      final response = await _dio.post('/comments/$commentId/dislike');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to dislike comment');
    }
  }

  static Future<void> reportComment(String commentId, String reason) async {
    try {
      await _dio.post('/comments/$commentId/report', data: {'Reason': reason});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to report comment');
    }
  }
}
