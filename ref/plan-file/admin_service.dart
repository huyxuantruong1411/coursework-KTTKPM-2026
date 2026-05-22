// lib/services/admin_service.dart
//
// Gọi tất cả endpoint /admin/* (yêu cầu role = 'admin').

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class AdminService {
  static final _dio = DioClient.instance;

  // ────────────────────────────────────────────
  //  QUẢN LÝ USER
  // ────────────────────────────────────────────

  /// Danh sách user với phân trang + tìm kiếm.
  /// GET /admin/users?page=&limit=&q=
  static Future<Map<String, dynamic>> listUsers({
    int page = 1,
    int limit = 20,
    String q = '',
  }) async {
    try {
      final response = await _dio.get(
        '/admin/users',
        queryParameters: {'page': page, 'limit': limit, if (q.isNotEmpty) 'q': q},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('AdminService.listUsers error: ${e.response?.data}');
      return {'items': [], 'total': 0, 'page': page, 'total_pages': 0};
    }
  }

  /// Khoá tài khoản user.
  /// POST /admin/users/{user_id}/ban
  static Future<bool> banUser(String userId) async {
    try {
      await _dio.post('/admin/users/$userId/ban');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.banUser error: ${e.response?.data}');
      return false;
    }
  }

  /// Mở khoá tài khoản user.
  /// POST /admin/users/{user_id}/unban
  static Future<bool> unbanUser(String userId) async {
    try {
      await _dio.post('/admin/users/$userId/unban');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.unbanUser error: ${e.response?.data}');
      return false;
    }
  }

  // ────────────────────────────────────────────
  //  QUẢN LÝ BÌNH LUẬN (BÁO CÁO)
  // ────────────────────────────────────────────

  /// Danh sách bình luận bị báo cáo.
  /// GET /admin/comments?page=&limit=&status=
  static Future<Map<String, dynamic>> listReportedComments({
    int page = 1,
    int limit = 20,
    String? status, // 'pending' | 'resolved' | 'ignored'
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'limit': limit};
      if (status != null) params['status'] = status;
      final response = await _dio.get('/admin/comments', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('AdminService.listReportedComments error: ${e.response?.data}');
      return {'items': [], 'total': 0, 'page': page, 'total_pages': 0};
    }
  }

  /// Xoá bình luận vi phạm (soft delete + resolve reports).
  /// POST /admin/comments/{comment_id}/delete
  static Future<bool> deleteComment(String commentId) async {
    try {
      await _dio.post('/admin/comments/$commentId/delete');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.deleteComment error: ${e.response?.data}');
      return false;
    }
  }

  /// Bỏ qua báo cáo (ignore).
  /// POST /admin/comments/{comment_id}/ignore
  static Future<bool> ignoreReports(String commentId) async {
    try {
      await _dio.post('/admin/comments/$commentId/ignore');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.ignoreReports error: ${e.response?.data}');
      return false;
    }
  }
}
