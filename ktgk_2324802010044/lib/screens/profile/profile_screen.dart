import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../friends/friends_screen.dart';
import '../admin/admin_screen.dart';
import 'edit_account_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

const _kOrange = Color(0xFFFF6740);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    try {
      final picker = ImagePicker();
      final imageFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (imageFile == null) return;
      if (!mounted) return;

      setState(() => _isUploading = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đang tải ảnh lên...')));

      await context.read<AuthProvider>().uploadAvatar(imageFile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật Avatar thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi upload: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateProfile() async {
    final auth = context.read<AuthProvider>();
    final newName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : null;
    final newBio = _bioController.text.trim().isNotEmpty
        ? _bioController.text.trim()
        : null;

    if (newName == null && newBio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất một thông tin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await auth.updateProfile(displayName: newName, bio: newBio);
      _nameController.clear();
      _bioController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final user = auth.user;
        final isAdmin = user?.role == 'admin';
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Hồ sơ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // ── Avatar ──────────────────────────────
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.grey[800],
                      backgroundImage:
                          (user?.avatar != null && user!.avatar!.isNotEmpty)
                          ? NetworkImage(user.avatar!)
                          : null,
                      child: (user?.avatar == null || user!.avatar!.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 56,
                              color: Colors.white54,
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: _isUploading ? null : _uploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isUploading
                              ? Colors.grey
                              : _kOrange,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Display name ────────────────────────
                Text(
                  user?.displayName ?? user?.username ?? 'Người dùng',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // ── @username ───────────────────────────
                if (user?.username != null)
                  Text(
                    '@${user!.username}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                const SizedBox(height: 2),
                // ── Admin badge ─────────────────────────
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kOrange.withValues(alpha: 0.5), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, color: _kOrange, size: 14),
                        SizedBox(width: 4),
                        Text('Quản trị viên', style: TextStyle(color: _kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  (user?.bio != null && user!.bio!.isNotEmpty)
                      ? user.bio!
                      : 'Chưa có tiểu sử',
                  style: TextStyle(
                    color: (user?.bio != null && user!.bio!.isNotEmpty)
                        ? Colors.white70
                        : Colors.white38,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Quick Action Buttons ─────────────────
                // Bạn bè
                _buildMenuButton(
                  icon: Icons.people_outline,
                  label: 'Bạn bè',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())),
                ),
                const SizedBox(height: 8),
                // Thống kê đọc truyện
                _buildMenuButton(
                  icon: Icons.bar_chart_rounded,
                  label: 'Thống kê đọc truyện',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                ),
                const SizedBox(height: 8),
                // Chỉnh sửa tài khoản
                _buildMenuButton(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Chỉnh sửa tài khoản',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditAccountScreen())),
                ),
                // Admin panel
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  _buildMenuButton(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Bảng quản trị',
                    color: _kOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                  ),
                ],

                const SizedBox(height: 20),
                // ── Update profile section ──────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cập nhật thông tin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bỏ trống ô nào sẽ giữ nguyên thông tin cũ.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tên hiển thị mới',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF3A3A3A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bioController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Tiểu sử',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF3A3A3A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Lưu Thay Đổi',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color ?? _kOrange),
        label: Text(
          label,
          style: TextStyle(
            color: color != null ? Colors.white : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color ?? _kOrange),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
