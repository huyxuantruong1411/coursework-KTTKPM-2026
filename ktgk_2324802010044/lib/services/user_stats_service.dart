// lib/services/user_stats_service.dart
//
// Gọi endpoint GET /analytics/user-stats để lấy thống kê đọc truyện cá nhân.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class UserStatsService {
  static final _dio = DioClient.instance;

  /// Lấy thống kê đọc truyện toàn diện của user hiện tại.
  ///
  /// Trả về:
  ///   total_manga      – số bộ manga đã đọc (unique)
  ///   total_chapters   – số chapter đã đọc (unique)
  ///   total_sessions   – tổng số lần mở đọc
  ///   total_pages      – tổng số trang đã đọc (ước tính)
  ///   total_ratings    – số lượng đánh giá đã cho
  ///   avg_rating       – điểm đánh giá trung bình (nullable)
  ///   daily_activity   – [{date, count}] 30 ngày gần nhất (cũ → mới)
  ///   genre_distribution  – [{name, count}] top 10 thể loại
  ///   theme_distribution  – [{name, count}] top 10 chủ đề
  ///   recent_manga     – [{manga_id, title}] 5 manga đọc gần nhất
  static Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final response = await _dio.get('/analytics/user-stats');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('UserStatsService.getUserStats error: ${e.response?.data}');
      return null;
    }
  }
}
