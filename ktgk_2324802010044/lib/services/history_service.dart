import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';
import '../models/reading_history.dart';

class HistoryService {
  static final _dio = DioClient.instance;

  /// POST /history/  body: {MangaId, ChapterId, LastPageRead}
  static Future<void> recordHistory({
    required String mangaId,
    required String chapterId,
    int lastPageRead = 0,
  }) async {
    try {
      await _dio.post(
        '/history/',
        data: {
          'MangaId': mangaId,
          'ChapterId': chapterId,
          'LastPageRead': lastPageRead,
        },
      );
    } on DioException catch (e) {
      debugPrint('HistoryService.recordHistory error: ${e.response?.data}');
    }
  }

  /// GET /history/?page=&limit=
  static Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/history/',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final rawItems =
            data['items'] as List? ?? data['histories'] as List? ?? [];
        return {
          'items': rawItems
              .map(
                (e) => ReadingHistoryItem.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
          'total': data['total'] ?? rawItems.length,
          'page': data['page'] ?? page,
        };
      }
      if (data is List) {
        return {
          'items': data
              .map(
                (e) => ReadingHistoryItem.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
          'total': data.length,
          'page': page,
        };
      }
      return {'items': <ReadingHistoryItem>[], 'total': 0, 'page': page};
    } on DioException catch (e) {
      debugPrint('HistoryService.getHistory error: ${e.response?.data}');
      return {'items': <ReadingHistoryItem>[], 'total': 0, 'page': page};
    }
  }

  /// GET /history/grouped?limit=
  ///
  /// Backend trả về:
  ///   { "groups": [ { "label": "Today", "items": [ {...HistoryEntry...} ] } ] }
  ///
  /// Hàm này trả về List<Map> với mỗi map có dạng:
  // ignore: unintended_html_in_doc_comment
  ///   { "label": String, "items": List<ReadingHistoryItem> }
  static Future<List<Map<String, dynamic>>> getGroupedHistory({
    int? limit,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (limit != null) params['limit'] = limit;

      final response = await _dio.get(
        '/history/grouped',
        queryParameters: params,
      );
      final data = response.data;

      List<dynamic> rawGroups = [];

      if (data is Map<String, dynamic>) {
        // { "groups": [...] }  ← cấu trúc backend hiện tại
        rawGroups = data['groups'] as List? ?? [];
      } else if (data is List) {
        // Nếu backend trả thẳng mảng groups
        rawGroups = data;
      }

      return rawGroups.map<Map<String, dynamic>>((g) {
        if (g is! Map<String, dynamic>) return {'label': '', 'items': []};

        final label = g['label']?.toString() ?? '';
        final rawItems = g['items'];
        final List<ReadingHistoryItem> parsedItems = [];

        if (rawItems is List) {
          for (final raw in rawItems) {
            if (raw is Map<String, dynamic>) {
              try {
                parsedItems.add(ReadingHistoryItem.fromJson(raw));
              } catch (e) {
                debugPrint('HistoryService: failed to parse item: $raw – $e');
              }
            }
          }
        }

        return {'label': label, 'items': parsedItems};
      }).toList();
    } on DioException catch (e) {
      debugPrint('HistoryService.getGroupedHistory error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /history/manga/{manga_id}/continue → {chapter_id, last_page}
  static Future<Map<String, dynamic>?> getContinueReading(
    String mangaId,
  ) async {
    try {
      final response = await _dio.get('/history/manga/$mangaId/continue');
      final data = response.data as Map<String, dynamic>?;
      if (data != null && data.containsKey('chapter_id')) {
        return data;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint(
        'HistoryService.getContinueReading error: ${e.response?.data}',
      );
      return null;
    }
  }
}
