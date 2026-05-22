// lib/providers/auth_provider.dart  (CẬP NHẬT)
//
// Thêm hỗ trợ: username, email, newPassword, currentPassword
// vào phương thức updateProfile().

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
    }
  }

  // ────────────────────────────────────────────
  //  ĐĂNG NHẬP
  // ────────────────────────────────────────────

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await AuthService.login(username, password);
      _user = await AuthService.getMe();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ────────────────────────────────────────────
  //  ĐĂNG XUẤT
  // ────────────────────────────────────────────

  Future<void> logout() async {
    await TokenStorage.clearToken();
    _user = null;
    notifyListeners();
  }

  // ────────────────────────────────────────────
  //  CẬP NHẬT HỒ SƠ (tất cả các trường)
  //
  //  Hỗ trợ:
  //    displayName, bio        → profile_screen
  //    username, email         → edit_account_screen
  //    newPassword, currentPassword → edit_account_screen
  // ────────────────────────────────────────────

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? username,
    String? email,
    String? newPassword,
    String? currentPassword,
  }) async {
    final updatedUser = await AuthService.updateMe(
      displayName: displayName,
      bio: bio,
      username: username,
      email: email,
      newPassword: newPassword,
      currentPassword: currentPassword,
    );
    _user = updatedUser;
    notifyListeners();
  }

  // ────────────────────────────────────────────
  //  UPLOAD AVATAR
  // ────────────────────────────────────────────

  Future<void> uploadAvatar(dynamic file) async {
    final avatarUrl = await AuthService.uploadAvatar(file);
    if (avatarUrl != null && _user != null) {
      _user = UserModel(
        userId: _user!.userId,
        username: _user!.username,
        email: _user!.email,
        displayName: _user!.displayName,
        avatar: avatarUrl,
        bio: _user!.bio,
        role: _user!.role,
        isLocked: _user!.isLocked,
        createdAt: _user!.createdAt,
        updatedAt: _user!.updatedAt,
      );
      notifyListeners();
    }
    // Refresh from server to get latest presigned URL
    try {
      _user = await AuthService.getMe();
      notifyListeners();
    } catch (_) {}
  }

  // ────────────────────────────────────────────
  //  REFRESH USER INFO
  // ────────────────────────────────────────────

  Future<void> refreshUser() async {
    try {
      _user = await AuthService.getMe();
      notifyListeners();
    } catch (_) {}
  }
}
