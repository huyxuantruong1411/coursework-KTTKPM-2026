import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';
import '../models/manga_list.dart';

class ListService {
  static final _dio = DioClient.instance;

  /// GET /lists/?manga_id={id} → trả {my_lists: [...], followed_lists: [...]}
  static Future<Map<String, List<MangaListBrief>>> getMyLists({
    String? mangaId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (mangaId != null) params['manga_id'] = mangaId;

      final response = await _dio.get('/lists/', queryParameters: params);
      final data = response.data as Map<String, dynamic>;

      final myListsJson = data['my_lists'] as List? ?? [];
      final followedListsJson = data['followed_lists'] as List? ?? [];

      return {
        'my_lists': myListsJson
            .map((e) => MangaListBrief.fromJson(e as Map<String, dynamic>))
            .toList(),
        'followed_lists': followedListsJson
            .map((e) => MangaListBrief.fromJson(e as Map<String, dynamic>))
            .toList(),
      };
    } on DioException catch (e) {
      debugPrint('ListService.getMyLists error: ${e.response?.data}');
      return {'my_lists': [], 'followed_lists': []};
    }
  }

  /// POST /lists/  body: {Name, Description?, Visibility}
  static Future<Map<String, dynamic>> createList(
    String name, {
    String? description,
    String visibility = 'private',
  }) async {
    try {
      final response = await _dio.post(
        '/lists/',
        data: {
          'Name': name,
          'Description': description,
          'Visibility': visibility,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create list');
    }
  }

  /// PUT /lists/{id}  body: {Name?, Description?, Visibility?}
  static Future<void> updateList(
    String listId, {
    String? name,
    String? description,
    String? visibility,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['Name'] = name;
      if (description != null) data['Description'] = description;
      if (visibility != null) data['Visibility'] = visibility;

      await _dio.put('/lists/$listId', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to update list');
    }
  }

  /// DELETE /lists/{id}
  static Future<void> deleteList(String listId) async {
    try {
      await _dio.delete('/lists/$listId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete list');
    }
  }

  /// GET /lists/{id} → ListDetailResponse
  static Future<MangaListDetail> getListDetail(String listId) async {
    try {
      final response = await _dio.get('/lists/$listId');
      return MangaListDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ?? 'Failed to get list detail',
      );
    }
  }

  /// POST /lists/{id}/items?manga_id={mangaId}
  static Future<void> addItem(String listId, String mangaId) async {
    try {
      await _dio.post(
        '/lists/$listId/items',
        queryParameters: {'manga_id': mangaId},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to add item');
    }
  }

  /// DELETE /lists/{id}/items/{mangaId}
  static Future<void> removeItem(String listId, String mangaId) async {
    try {
      await _dio.delete('/lists/$listId/items/$mangaId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to remove item');
    }
  }

  /// POST /lists/{id}/follow
  static Future<void> followList(String listId) async {
    try {
      await _dio.post('/lists/$listId/follow');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to follow list');
    }
  }

  /// DELETE /lists/{id}/follow
  static Future<void> unfollowList(String listId) async {
    try {
      await _dio.delete('/lists/$listId/follow');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to unfollow list');
    }
  }

  /// GET /lists/public?page=&q=&sort=
  static Future<Map<String, dynamic>> getPublicLists({
    int page = 1,
    int limit = 12,
    String? query,
    String sort = 'updated_desc',
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'limit': limit,
        'sort': sort,
      };
      if (query != null && query.isNotEmpty) params['q'] = query;

      final response = await _dio.get('/lists/public', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      if (data['items'] is List) return data;
      if (data['lists'] is List) {
        return {
          ...data,
          'items': data['lists'],
          'total': data['total'] ?? (data['lists'] as List).length,
        };
      }
      return {'items': [], 'total': 0};
    } on DioException catch (e) {
      debugPrint('ListService.getPublicLists error: ${e.response?.data}');
      return {'items': [], 'total': 0};
    }
  }
}
