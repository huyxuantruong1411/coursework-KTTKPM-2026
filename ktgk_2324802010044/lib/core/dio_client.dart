import 'package:dio/dio.dart';
import 'constants.dart';
import 'token_storage.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Future<void> Function()? onUnauthorized;
  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.backendBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // JWT Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Token expired hoặc invalid → clear
            await TokenStorage.clearToken();
            await onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );

    return dio;
  }

  // MangaDex Dio (không cần auth)
  static final Dio mangadex = Dio(
    BaseOptions(
      baseUrl: AppConstants.mangadexBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}
