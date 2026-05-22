import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/friend_service.dart';
import '../chat/chat_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kCard = Color(0xFF2C2C2C);
const _kBg = Color(0xFF000000);

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingReceived = [];
  List<Map<String, dynamic>> _pendingSent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadFriends();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    final friends = await FriendService.getAcceptedFriends();
    final requests = await FriendService.getPendingRequests();
    final sent = await FriendService.getSentRequests();
    if (mounted) {
      setState(() {
        _friends = friends;
        _pendingReceived = requests;
        _pendingSent = sent;
        _loading = false;
      });
    }
  }

  Future<void> _openDirectChat(String friendId, String friendName) async {
    try {
      final result = await ChatService.createRoom(
        type: 'direct',
        userIds: [friendId],
      );
      if (!mounted) return;
      final roomId =
          result?['room_id']?.toString() ??
          result?['RoomId']?.toString() ??
          result?['id']?.toString() ??
          '';
      if (roomId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Khong the mo chat luc nay.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(roomId: roomId, roomName: friendName),
        ),
      );
      if (mounted) _loadFriends();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Khong the mo chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSearchDialog() {
    final ctrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          backgroundColor: _kCard,
          title: const Text(
            'Tim nguoi dung',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Nhap ten...',
                  prefixIcon: Icon(Icons.search, color: Colors.white38),
                ),
                onSubmitted: (q) async {
                  if (q.trim().isEmpty) return;
                  final r = await FriendService.searchUsers(q.trim());
                  setDialog(() => results = r);
                },
              ),
              const SizedBox(height: 8),
              ...results.map(
                (u) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[700],
                    radius: 16,
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white54,
                    ),
                  ),
                  title: Text(
                    (u['Username'] ?? u['username'] ?? '').toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.person_add,
                      color: _kOrange,
                      size: 20,
                    ),
                    onPressed: () async {
                      final userId =
                          u['UserId']?.toString() ??
                          u['user_id']?.toString() ??
                          '';
                      if (userId.isEmpty) return;
                      try {
                        await FriendService.sendRequest(userId);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Da gui loi moi!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadFriends();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Loi: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Dong',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: const Text(
          'Ban be',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: _kOrange),
            onPressed: _showSearchDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _kOrange,
          labelColor: _kOrange,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Ban be (${_friends.length})'),
            Tab(text: 'Da nhan (${_pendingReceived.length})'),
            Tab(text: 'Da gui (${_pendingSent.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildFriendList(),
                _buildPendingReceived(),
                _buildPendingSent(),
              ],
            ),
    );
  }

  Widget _buildFriendList() {
    if (_friends.isEmpty) {
      return const Center(
        child: Text('Chua co ban be', style: TextStyle(color: Colors.white38)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: _kOrange,
      child: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (ctx, i) {
          final f = _friends[i];
          final name = (f['Username'] ?? f['username'] ?? 'User').toString();
          final friendId =
              f['UserId']?.toString() ?? f['user_id']?.toString() ?? '';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[700],
              child: const Icon(Icons.person, color: Colors.white54),
            ),
            title: Text(name, style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: _kOrange,
                size: 20,
              ),
              onPressed: friendId.isEmpty
                  ? null
                  : () => _openDirectChat(friendId, name),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingReceived() {
    if (_pendingReceived.isEmpty) {
      return const Center(
        child: Text(
          'Khong co loi moi nao',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    return ListView.builder(
      itemCount: _pendingReceived.length,
      itemBuilder: (ctx, i) {
        final r = _pendingReceived[i];
        final name = (r['Username'] ?? r['username'] ?? 'User').toString();
        final userId =
            r['UserId']?.toString() ?? r['user_id']?.toString() ?? '';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[700],
            child: const Icon(Icons.person, color: Colors.white54),
          ),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
                onPressed: userId.isEmpty
                    ? null
                    : () async {
                        await FriendService.acceptRequest(userId);
                        _loadFriends();
                      },
              ),
              IconButton(
                icon: const Icon(
                  Icons.cancel,
                  color: Colors.redAccent,
                  size: 24,
                ),
                onPressed: userId.isEmpty
                    ? null
                    : () async {
                        await FriendService.rejectRequest(userId);
                        _loadFriends();
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingSent() {
    if (_pendingSent.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty_rounded,
                color: Colors.white24,
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'Chua co loi moi da gui.',
                style: TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: _kOrange,
      child: ListView.builder(
        itemCount: _pendingSent.length,
        itemBuilder: (ctx, i) {
          final r = _pendingSent[i];
          final name = (r['Username'] ?? r['username'] ?? 'User').toString();
          final requestedAt = (r['requested_at'] ?? '').toString();
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[700],
              child: const Icon(Icons.person, color: Colors.white54),
            ),
            title: Text(name, style: const TextStyle(color: Colors.white)),
            subtitle: requestedAt.isEmpty
                ? null
                : Text(
                    requestedAt,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
            trailing: const Icon(Icons.schedule, color: Colors.white38),
          );
        },
      ),
    );
  }
}
