// lib/services/admin_service.dart
//
// Gọi tất cả endpoint /admin/* (yêu cầu role = 'admin').

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class AdminService {
  static final _dio = DioClient.instance;

  // ── Dashboard ────────────────────────────────────────────────────

  /// GET /admin/dashboard?start_date=&end_date=
  /// Trả về: new_users_by_date, reading_activity_by_date, top_manga, totals, date_range
  static Future<Map<String, dynamic>> getDashboard({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;
      final response = await _dio.get(
        '/admin/dashboard',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('AdminService.getDashboard error: ${e.response?.data}');
      return {};
    }
  }

  // ── Manage Users ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listUsers({
    int page = 1,
    int limit = 20,
    String q = '',
  }) async {
    try {
      final response = await _dio.get(
        '/admin/users',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (q.isNotEmpty) 'q': q,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('AdminService.listUsers error: ${e.response?.data}');
      return {'items': [], 'total': 0, 'page': page, 'total_pages': 0};
    }
  }

  static Future<bool> banUser(String userId) async {
    try {
      await _dio.post('/admin/users/$userId/ban');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.banUser error: ${e.response?.data}');
      return false;
    }
  }

  static Future<bool> unbanUser(String userId) async {
    try {
      await _dio.post('/admin/users/$userId/unban');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.unbanUser error: ${e.response?.data}');
      return false;
    }
  }

  // ── Manage Comments ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> listReportedComments({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'limit': limit};
      if (status != null) params['status'] = status;
      final response = await _dio.get(
        '/admin/comments',
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        'AdminService.listReportedComments error: ${e.response?.data}',
      );
      return {'items': [], 'total': 0, 'page': page, 'total_pages': 0};
    }
  }

  static Future<bool> deleteComment(String commentId) async {
    try {
      await _dio.post('/admin/comments/$commentId/delete');
      return true;
    } on DioException catch (e) {
      debugPrint('AdminService.deleteComment error: ${e.response?.data}');
      return false;
    }
  }

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
