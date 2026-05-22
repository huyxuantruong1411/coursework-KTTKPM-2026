import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class ChatService {
  static final _dio = DioClient.instance;

  /// GET /chat/rooms -> {rooms: [...]}
  static Future<List<Map<String, dynamic>>> getRooms({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/chat/rooms',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['rooms'] is List) {
        return (data['rooms'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('ChatService.getRooms error: ${e.response?.data}');
      return [];
    }
  }

  /// PUT /chat/rooms/{room_id} body: {name}
  static Future<void> renameRoom(String roomId, String name) async {
    try {
      await _dio.put('/chat/rooms/$roomId', data: {'name': name});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to rename room');
    }
  }

  /// DELETE /chat/rooms/{room_id}
  static Future<void> deleteRoom(String roomId) async {
    try {
      await _dio.delete('/chat/rooms/$roomId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to delete room');
    }
  }

  /// DELETE /chat/rooms/{room_id}/members/me
  static Future<void> leaveRoom(String roomId) async {
    try {
      await _dio.delete('/chat/rooms/$roomId/members/me');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to leave room');
    }
  }

  /// GET /chat/rooms/{room_id}/members
  static Future<List<Map<String, dynamic>>> getMembers(String roomId) async {
    try {
      final response = await _dio.get('/chat/rooms/$roomId/members');
      final data = response.data;
      if (data is Map && data['members'] is List) {
        return (data['members'] as List).cast<Map<String, dynamic>>();
      }
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException catch (e) {
      debugPrint('ChatService.getMembers error: ${e.response?.data}');
      return [];
    }
  }

  /// POST /chat/rooms/{room_id}/members body: {user_id}
  static Future<void> addMember(String roomId, String userId) async {
    try {
      await _dio.post('/chat/rooms/$roomId/members', data: {'user_id': userId});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to add member');
    }
  }

  /// DELETE /chat/rooms/{room_id}/members/{user_id}
  static Future<void> removeMember(String roomId, String userId) async {
    try {
      await _dio.delete('/chat/rooms/$roomId/members/$userId');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to remove member');
    }
  }

  /// POST /chat/rooms body: {type, user_ids, name?}
  static Future<Map<String, dynamic>?> createRoom({
    String type = 'group',
    String? name,
    List<String>? userIds,
    // Backward-compatible aliases for old call sites.
    List<String>? memberIds,
    bool? isDirect,
  }) async {
    try {
      final resolvedType = isDirect == true ? 'direct' : type;
      final resolvedUserIds = userIds ?? memberIds ?? <String>[];
      final data = <String, dynamic>{
        'type': resolvedType,
        'user_ids': resolvedUserIds,
      };
      if (name != null && name.isNotEmpty) data['name'] = name;
      final response = await _dio.post('/chat/rooms', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to create room');
    }
  }

  /// GET /chat/rooms/{room_id}/messages?page=&limit=
  static Future<List<Map<String, dynamic>>> getMessages(
    String roomId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/chat/rooms/$roomId/messages',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['messages'] is List) {
        return (data['messages'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('ChatService.getMessages error: ${e.response?.data}');
      return [];
    }
  }

  /// POST /chat/rooms/{room_id}/messages body: {content, reply_to_id?}
  static Future<Map<String, dynamic>?> sendMessage(
    String roomId,
    String content, {
    String? replyToId,
  }) async {
    try {
      final data = <String, dynamic>{'content': content};
      if (replyToId != null) data['reply_to_id'] = replyToId;
      final response = await _dio.post(
        '/chat/rooms/$roomId/messages',
        data: data,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to send message');
    }
  }

  /// POST /chat/rooms/{room_id}/media multipart: file
  static Future<Map<String, dynamic>?> uploadMedia(
    String roomId,
    dynamic file,
  ) async {
    try {
      final dynamic pickedFile = file;
      final path = pickedFile.path?.toString() ?? '';
      final name = (pickedFile.name?.toString() ?? '').isNotEmpty
          ? pickedFile.name.toString()
          : path.split(RegExp(r'[\\/]')).last;

      final MultipartFile multipartFile;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: name.isNotEmpty ? name : 'image.jpg',
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          path,
          filename: name.isNotEmpty ? name : 'image.jpg',
        );
      }

      final formData = FormData.fromMap({'file': multipartFile});
      final response = await _dio.post(
        '/chat/rooms/$roomId/media',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('ChatService.uploadMedia error: ${e.response?.data}');
      return null;
    }
  }

  /// PUT /chat/messages/{message_id}/read
  static Future<void> markRead(String messageId) async {
    try {
      await _dio.put('/chat/messages/$messageId/read');
    } on DioException catch (e) {
      debugPrint('ChatService.markRead error: ${e.response?.data}');
    }
  }

  /// POST /chat/rooms/{room_id}/read
  static Future<void> markRoomRead(String roomId) async {
    try {
      await _dio.post('/chat/rooms/$roomId/read');
    } on DioException catch (e) {
      debugPrint('ChatService.markRoomRead error: ${e.response?.data}');
    }
  }
}
