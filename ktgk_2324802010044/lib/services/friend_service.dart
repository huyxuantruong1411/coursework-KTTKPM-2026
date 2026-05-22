import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class FriendService {
  static final _dio = DioClient.instance;

  /// GET /friends/ -> {friends: [...]}
  static Future<List<Map<String, dynamic>>> getAcceptedFriends() async {
    try {
      final response = await _dio.get('/friends/');
      final data = response.data as Map<String, dynamic>;
      return (data['friends'] as List? ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('FriendService.getAcceptedFriends error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /friends/requests -> {requests: [...]}
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await _dio.get('/friends/requests');
      final data = response.data as Map<String, dynamic>;
      return (data['requests'] as List? ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('FriendService.getPendingRequests error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /friends/sent -> {requests: [...]}
  static Future<List<Map<String, dynamic>>> getSentRequests() async {
    try {
      final response = await _dio.get('/friends/sent');
      final data = response.data;
      if (data is Map && data['requests'] is List) {
        return (data['requests'] as List).cast<Map<String, dynamic>>();
      }
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException catch (e) {
      debugPrint('FriendService.getSentRequests error: ${e.response?.data}');
      return [];
    }
  }

  /// Compatibility wrapper for older UI code.
  static Future<Map<String, List<Map<String, dynamic>>>> getFriends() async {
    final friends = await getAcceptedFriends();
    final requests = await getPendingRequests();
    final sent = await getSentRequests();
    return {
      'friends': friends,
      'pending_received': requests,
      'pending_sent': sent,
    };
  }

  /// POST /friends/request/{user_id}
  static Future<void> sendRequest(String targetUserId) async {
    try {
      await _dio.post('/friends/request/$targetUserId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to send request');
    }
  }

  /// POST /friends/accept/{user_id}
  static Future<void> acceptRequest(String userId) async {
    try {
      await _dio.post('/friends/accept/$userId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to accept');
    }
  }

  /// POST /friends/reject/{user_id}
  static Future<void> rejectRequest(String userId) async {
    try {
      await _dio.post('/friends/reject/$userId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to reject');
    }
  }

  /// POST /friends/block/{user_id}
  static Future<void> blockUser(String userId) async {
    try {
      await _dio.post('/friends/block/$userId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to block');
    }
  }

  static Future<void> removeFriend(String friendId) => blockUser(friendId);

  /// GET /friends/search?q=
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/friends/search',
        queryParameters: {'q': query},
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['users'] is List) {
        return (data['users'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('FriendService.searchUsers error: ${e.response?.data}');
      return [];
    }
  }
}
