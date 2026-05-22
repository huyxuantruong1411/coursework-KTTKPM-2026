// lib/services/auth_service.dart
//
// ⚠️  LƯU FILE NÀY VÀO: lib/services/auth_service.dart
//
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

class AuthService {
  static final _dio = DioClient.instance;

  // ──────────────────────────────────────────────────────────
  //  ĐĂNG KÝ
  // ──────────────────────────────────────────────────────────

  static Future<String> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {'username': username, 'email': email, 'password': password},
      );
      return (response.data['message'] as String?) ?? 'Đăng ký thành công!';
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Đăng ký thất bại';
      throw Exception(
        detail is List
            ? detail.first['msg'] ?? 'Đăng ký thất bại'
            : detail.toString(),
      );
    }
  }

  // ──────────────────────────────────────────────────────────
  //  XÁC THỰC EMAIL
  // ──────────────────────────────────────────────────────────

  static Future<String> verifyEmail(String email, String otp) async {
    try {
      final response = await _dio.post(
        '/auth/verify-email',
        data: {'email': email, 'otp': otp},
      );
      return (response.data['message'] as String?) ?? 'Xác thực thành công!';
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ?? 'Mã OTP không hợp lệ hoặc đã hết hạn.',
      );
    }
  }

  static Future<String> resendVerifyEmail(String email) async {
    try {
      final response = await _dio.post(
        '/auth/resend-verify-email',
        data: {'email': email},
      );
      return (response.data['message'] as String?) ?? 'Đã gửi lại OTP.';
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Gửi lại OTP thất bại.');
    }
  }

  // ──────────────────────────────────────────────────────────
  //  ĐĂNG NHẬP
  // ──────────────────────────────────────────────────────────

  static Future<String> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: FormData.fromMap({'username': username, 'password': password}),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      final token = response.data['access_token'] as String;
      await TokenStorage.saveToken(token);
      return token;
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Đăng nhập thất bại';
      throw Exception(detail.toString());
    }
  }

  // ──────────────────────────────────────────────────────────
  //  PROFILE
  // ──────────────────────────────────────────────────────────

  static Future<UserModel> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      await TokenStorage.saveUserInfo(user.userId, user.username);
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await TokenStorage.clearToken();
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      throw Exception(
        e.response?.data?['detail'] ?? 'Không thể lấy thông tin người dùng.',
      );
    }
  }

  static Future<UserModel> updateMe({
    String? username,
    String? email,
    String? bio,
    String? displayName,
    String? newPassword,
    String? currentPassword,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (email != null) data['email'] = email;
      if (bio != null) data['bio'] = bio;
      if (displayName != null) data['display_name'] = displayName;
      if (newPassword != null) data['new_password'] = newPassword;
      if (currentPassword != null) data['current_password'] = currentPassword;

      final response = await _dio.put('/auth/me', data: data);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ?? 'Cập nhật hồ sơ thất bại.',
      );
    }
  }

  static Future<String?> uploadAvatar(dynamic file) async {
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
          filename: name.isNotEmpty ? name : 'avatar.jpg',
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          path,
          filename: name.isNotEmpty ? name : 'avatar.jpg',
        );
      }

      final formData = FormData.fromMap({'file': multipartFile});
      final response = await _dio.post(
        '/auth/me/avatar',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data['avatar_url'] as String?;
    } on DioException catch (e) {
      debugPrint('Avatar upload error: ${e.response?.data}');
      throw Exception(
        e.response?.data?['detail'] ?? 'Upload ảnh đại diện thất bại.',
      );
    }
  }

  // ──────────────────────────────────────────────────────────
  //  OTP – QUÊN MẬT KHẨU
  // ──────────────────────────────────────────────────────────

  static Future<String> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return (response.data['message'] as String?) ?? 'Đã gửi OTP.';
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Gửi OTP thất bại.');
    }
  }

  static Future<String> verifyResetOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        '/auth/verify-reset-otp',
        data: {'email': email, 'otp': otp},
      );
      return (response.data['message'] as String?) ?? 'OTP hợp lệ.';
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ?? 'Mã OTP không hợp lệ hoặc đã hết hạn.',
      );
    }
  }

  static Future<String> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await _dio.post(
        '/auth/reset-password',
        data: {'email': email, 'otp': otp, 'new_password': newPassword},
      );
      return (response.data['message'] as String?) ??
          'Đổi mật khẩu thành công.';
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Đổi mật khẩu thất bại.');
    }
  }
}
