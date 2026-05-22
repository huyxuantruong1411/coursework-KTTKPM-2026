import 'package:flutter/foundation.dart';

class AnalyticsService {
  static Future<void> logScreenView(String screenName) async {
    if (kDebugMode) {
      print('[Analytics] Viewed screen: $screenName');
    }
    // In production, this would send data to Firebase Analytics or custom backend
  }

  static Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    if (kDebugMode) {
      print('[Analytics] Event: $eventName, params: $parameters');
    }
  }
}
