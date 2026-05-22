// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../core/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  // ────────────────────────────────────────────
  //  Khởi tạo khi app mở
  // ────────────────────────────────────────────

  Future<void> initialize() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) return;
    try {
      _user = await AuthService.getMe();
      notifyListeners();
    } catch (_) {
      await TokenStorage.clearToken();
      _user = null;
    }
  }

  // ────────────────────────────────────────────
  //  ĐĂNG NHẬP
  // ────────────────────────────────────────────

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.login(username, password);
      final me = await AuthService.getMe();
      _user = me;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ────────────────────────────────────────────
  //  ĐĂNG KÝ – gửi OTP, chưa đăng nhập ngay
  // ────────────────────────────────────────────

  Future<String> register(
    String username,
    String email,
    String password,
  ) async {
    _setLoading(true);
    try {
      final message = await AuthService.register(username, email, password);
      _setLoading(false);
      return message;
    } catch (e) {
      _error = _clean(e);
      _setLoading(false);
      rethrow;
    }
  }

  // ────────────────────────────────────────────
  //  XÁC THỰC EMAIL
  // ────────────────────────────────────────────

  Future<bool> verifyEmail(String email, String otp) async {
    _setLoading(true);
    try {
      await AuthService.verifyEmail(email, otp);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _clean(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resendVerifyEmail(String email) async {
    _setLoading(true);
    try {
      await AuthService.resendVerifyEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _clean(e);
      _setLoading(false);
      return false;
    }
  }

  // ────────────────────────────────────────────
  //  QUÊN MẬT KHẨU
  // ────────────────────────────────────────────

  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    try {
      await AuthService.forgotPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _clean(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyResetOtp(String email, String otp) async {
    _setLoading(true);
    try {
      await AuthService.verifyResetOtp(email, otp);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _clean(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    _setLoading(true);
    try {
      await AuthService.resetPassword(email, otp, newPassword);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _clean(e);
      _setLoading(false);
      return false;
    }
  }

  // ────────────────────────────────────────────
  //  PROFILE
  // ────────────────────────────────────────────

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? username,
    String? email,
    String? newPassword,
    String? currentPassword,
  }) async {
    try {
      _user = await AuthService.updateMe(
        displayName: displayName,
        bio: bio,
        username: username,
        email: email,
        newPassword: newPassword,
        currentPassword: currentPassword,
      );
      notifyListeners();
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> uploadAvatar(dynamic file) async {
    try {
      final avatarUrl = await AuthService.uploadAvatar(file);
      _user = await AuthService.getMe();
      notifyListeners();
      return avatarUrl;
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      rethrow;
    }
  }

  // ────────────────────────────────────────────
  //  ĐĂNG XUẤT
  // ────────────────────────────────────────────

  Future<void> logout() async {
    await TokenStorage.clearToken();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ────────────────────────────────────────────
  //  Helpers
  // ────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
