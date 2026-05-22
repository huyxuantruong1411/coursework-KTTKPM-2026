import 'package:flutter/foundation.dart';

class AppConstants {
  // Backend API
  static String get backendBaseUrl {
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    return 'http://10.0.2.2:8000/api/v1';
  }

  // WebSocket
  static String get wsBaseUrl {
    if (kIsWeb) return 'ws://localhost:8000/ws';
    return 'ws://10.0.2.2:8000/ws';
  }

  // MangaDex (fallback)
  static const String mangadexBaseUrl = 'https://api.mangadex.org';
  static const String mangadexCoverCdn = 'https://uploads.mangadex.org/covers';

  // Storage keys
  static const String tokenKey = 'backend_jwt_token';
  static const String userIdKey = 'backend_user_id';
  static const String usernameKey = 'backend_username';
}
