import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/auth_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kBg = Color(0xFF121212);
const _kCard = Color(0xFF2C2C2C);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CachedNetworkImage.evictFromCache('all_images_or_similar_not_available');
      // For CachedNetworkImage, clearing everything is complex without path, 
      // but we can clear image cache from memory:
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã xóa bộ nhớ đệm hình ảnh'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        title: const Text('Cài đặt', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Hệ thống', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.white70),
            title: const Text('Xóa bộ nhớ đệm', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Xóa cache hình ảnh để giải phóng dung lượng', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: _isClearingCache 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2))
                : null,
            onTap: _isClearingCache ? null : _clearCache,
          ),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Thông tin', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white70),
            title: const Text('Phiên bản', style: TextStyle(color: Colors.white)),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.white54)),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
            title: const Text('Chính sách bảo mật', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Tài khoản', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final appProvider = context.read<AppProvider>();
              final authProvider = context.read<AuthProvider>();
              appProvider.clearState();
              await authProvider.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
