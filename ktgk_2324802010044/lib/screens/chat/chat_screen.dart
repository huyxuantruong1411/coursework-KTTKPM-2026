import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants.dart';
import '../../core/token_storage.dart';
import '../../services/chat_service.dart';
import '../../services/friend_service.dart';
import '../auth/auth_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kCard = Color(0xFF2C2C2C);
const _kBg = Color(0xFF000000);

String _valueOf(
  Map<String, dynamic> data,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return fallback;
}

String _userNameOf(Map<String, dynamic> user) {
  return _valueOf(user, const [
    'display_name',
    'DisplayName',
    'username',
    'Username',
    'email',
    'Email',
  ], 'User');
}

String _userIdOf(Map<String, dynamic> user) {
  return _valueOf(user, const ['user_id', 'UserId', 'id', 'Id']);
}

String _avatarOf(Map<String, dynamic> data) {
  return _valueOf(data, const [
    'avatar_url',
    'AvatarUrl',
    'avatar',
    'Avatar',
    'sender_avatar',
    'SenderAvatar',
  ]);
}

bool _boolOf(dynamic value) {
  if (value is bool) return value;
  if (value == null) return false;
  return value.toString().toLowerCase() == 'true';
}

class _NewChatResult {
  const _NewChatResult.direct(this.userId, this.title)
    : type = 'direct',
      name = null,
      userIds = const [];

  const _NewChatResult.group(this.name, this.userIds)
    : type = 'group',
      userId = null,
      title = null;

  final String type;
  final String? userId;
  final String? title;
  final String? name;
  final List<String> userIds;
}

// ============= CHAT ROOMS LIST =============
class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    if (mounted) setState(() => _loading = true);
    final rooms = await ChatService.getRooms();
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: const Text(
          'Tin nhan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Tai lai',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kOrange,
        onPressed: _createNewRoom,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _rooms.isEmpty
          ? const Center(
              child: Text(
                'Chua co cuoc tro chuyen nao',
                style: TextStyle(color: Colors.white38),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRooms,
              color: _kOrange,
              child: ListView.builder(
                itemCount: _rooms.length,
                itemBuilder: (ctx, i) => _buildRoomTile(_rooms[i]),
              ),
            ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final name = _valueOf(room, const ['Name', 'name'], 'Chat Room');
    final roomId = _valueOf(room, const ['RoomId', 'room_id', 'id']);
    final type = _valueOf(room, const ['Type', 'type'], 'group');
    final avatarUrl = _avatarOf(room);
    final lastMsgText = _extractLastMessageText(
      room['LastMessage'] ?? room['last_message'],
    );
    final unreadRaw = room['UnreadCount'] ?? room['unread_count'] ?? 0;
    final unread = unreadRaw is int
        ? unreadRaw
        : int.tryParse(unreadRaw.toString()) ?? 0;
    final otherMember = _otherMember(room);
    final isOnline = _boolOf(otherMember?['is_online']);

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: _kOrange.withValues(alpha: 0.2),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Icon(
                    type == 'group'
                        ? Icons.groups_2_outlined
                        : Icons.person_outline,
                    color: _kOrange,
                  )
                : null,
          ),
          if (type == 'direct')
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.greenAccent : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBg, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        lastMsgText.isNotEmpty ? lastMsgText : 'Chua co tin nhan',
        style: TextStyle(
          color: lastMsgText.isNotEmpty ? Colors.white38 : Colors.white24,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unread > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: _kOrange,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: roomId.isEmpty ? null : () => _openRoom(roomId, name),
      onLongPress: roomId.isEmpty ? null : () => _showRoomOptions(room),
    );
  }

  Map<String, dynamic>? _otherMember(Map<String, dynamic> room) {
    final members = room['members'];
    if (members is! List) return null;
    for (final item in members) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      if (item is Map) {
        return item.cast<String, dynamic>();
      }
    }
    return null;
  }

  String _extractLastMessageText(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      final type = (raw['type'] ?? raw['message_type'] ?? '').toString();
      final content = (raw['content'] ?? raw['Content'] ?? '').toString();
      if (type == 'image') return '[Image]';
      return content;
    }
    return raw.toString();
  }

  Future<void> _openRoom(String roomId, String roomName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, roomName: roomName),
      ),
    );
    if (mounted) _loadRooms();
  }

  Future<void> _createNewRoom() async {
    final result = await showModalBottomSheet<_NewChatResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _NewChatSheet(),
    );
    if (result == null) return;

    try {
      if (result.type == 'direct') {
        final created = await ChatService.createRoom(
          type: 'direct',
          userIds: [result.userId!],
        );
        final roomId = _valueOf(created ?? {}, const [
          'room_id',
          'RoomId',
          'id',
        ]);
        if (roomId.isNotEmpty && mounted) {
          await _openRoom(roomId, result.title ?? 'Chat');
        }
      } else {
        final created = await ChatService.createRoom(
          type: 'group',
          name: result.name,
          userIds: result.userIds,
        );
        final roomId = _valueOf(created ?? {}, const [
          'room_id',
          'RoomId',
          'id',
        ]);
        await _loadRooms();
        if (roomId.isNotEmpty && mounted) {
          await _openRoom(roomId, result.name ?? 'Group chat');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khong the tao chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRoomOptions(Map<String, dynamic> room) {
    final roomId = _valueOf(room, const ['RoomId', 'room_id', 'id']);
    final roomName = _valueOf(room, const ['Name', 'name'], 'Chat Room');
    final type = _valueOf(room, const ['Type', 'type'], 'group');

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'group')
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                title: const Text(
                  'Doi ten phong',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameRoom(roomId, roomName);
                },
              ),
            ListTile(
              leading: const Icon(Icons.group_outlined, color: Colors.white70),
              title: const Text(
                'Thanh vien',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showMembers(roomId, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text(
                'Roi phong',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLeaveRoom(roomId);
              },
            ),
            if (type == 'group')
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Xoa phong',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteRoom(roomId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameRoom(String roomId, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text(
          'Doi ten phong',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Ten phong...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Luu'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == currentName) return;
    await ChatService.renameRoom(roomId, name);
    await _loadRooms();
  }

  Future<void> _confirmLeaveRoom(String roomId) async {
    final ok = await _confirm('Roi phong chat nay?');
    if (ok != true) return;
    await ChatService.leaveRoom(roomId);
    await _loadRooms();
  }

  Future<void> _confirmDeleteRoom(String roomId) async {
    final ok = await _confirm('Xoa phong chat nay?');
    if (ok != true) return;
    await ChatService.deleteRoom(roomId);
    await _loadRooms();
  }

  Future<bool?> _confirm(String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Dong y'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMembers(String roomId, String roomType) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _RoomMembersSheet(roomId: roomId, roomType: roomType),
    );
    if (mounted) _loadRooms();
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _directCtrl = TextEditingController();
  final _groupSearchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  List<Map<String, dynamic>> _directResults = [];
  List<Map<String, dynamic>> _groupResults = [];
  final Map<String, Map<String, dynamic>> _selected = {};
  bool _searchingDirect = false;
  bool _searchingGroup = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _directCtrl.dispose();
    _groupSearchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchDirect() async {
    final query = _directCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searchingDirect = true);
    final results = await FriendService.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _directResults = results;
      _searchingDirect = false;
    });
  }

  Future<void> _searchGroup() async {
    final query = _groupSearchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searchingGroup = true);
    final results = await FriendService.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _groupResults = results;
      _searchingGroup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tin nhan moi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                indicatorColor: _kOrange,
                labelColor: _kOrange,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(text: 'Truc tiep'),
                  Tab(text: 'Nhom'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [_buildDirectTab(), _buildGroupTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _SearchField(
            controller: _directCtrl,
            hintText: 'Tim username...',
            isLoading: _searchingDirect,
            onSearch: _searchDirect,
          ),
        ),
        Expanded(
          child: _directResults.isEmpty
              ? const Center(
                  child: Text(
                    'Tim user de bat dau chat',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: _directResults.length,
                  itemBuilder: (ctx, i) {
                    final user = _directResults[i];
                    final userId = _userIdOf(user);
                    final name = _userNameOf(user);
                    return ListTile(
                      leading: _UserAvatar(user: user),
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _valueOf(user, const ['username', 'Username'], ''),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chat_bubble_outline,
                        color: _kOrange,
                      ),
                      onTap: userId.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              _NewChatResult.direct(userId, name),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _groupNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Ten nhom...',
              prefixIcon: Icon(Icons.groups_2_outlined, color: Colors.white38),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _SearchField(
            controller: _groupSearchCtrl,
            hintText: 'Them thanh vien...',
            isLoading: _searchingGroup,
            onSearch: _searchGroup,
          ),
        ),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _selected.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    label: Text(_userNameOf(entry.value)),
                    onDeleted: () =>
                        setState(() => _selected.remove(entry.key)),
                  ),
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _groupResults.length,
            itemBuilder: (ctx, i) {
              final user = _groupResults[i];
              final userId = _userIdOf(user);
              final selected = _selected.containsKey(userId);
              return ListTile(
                leading: _UserAvatar(user: user),
                title: Text(
                  _userNameOf(user),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  icon: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected ? Colors.greenAccent : _kOrange,
                  ),
                  onPressed: userId.isEmpty
                      ? null
                      : () {
                          setState(() {
                            if (selected) {
                              _selected.remove(userId);
                            } else {
                              _selected[userId] = user;
                            }
                          });
                        },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final name = _groupNameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  context,
                  _NewChatResult.group(name, _selected.keys.toList()),
                );
              },
              icon: const Icon(Icons.group_add),
              label: const Text('Tao nhom'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomMembersSheet extends StatefulWidget {
  const _RoomMembersSheet({required this.roomId, required this.roomType});

  final String roomId;
  final String roomType;

  @override
  State<_RoomMembersSheet> createState() => _RoomMembersSheetState();
}

class _RoomMembersSheetState extends State<_RoomMembersSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final members = await ChatService.getMembers(widget.roomId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final results = await FriendService.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _add(String userId) async {
    await ChatService.addMember(widget.roomId, userId);
    await _loadMembers();
  }

  Future<void> _remove(String userId) async {
    await ChatService.removeMember(widget.roomId, userId);
    await _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Thanh vien',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.roomType == 'group')
              Padding(
                padding: const EdgeInsets.all(16),
                child: _SearchField(
                  controller: _searchCtrl,
                  hintText: 'Tim user de them...',
                  isLoading: _searching,
                  onSearch: _search,
                ),
              ),
            if (_results.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final user = _results[i];
                    final userId = _userIdOf(user);
                    final already = _members.any((m) => _userIdOf(m) == userId);
                    return ListTile(
                      dense: true,
                      leading: _UserAvatar(user: user, radius: 16),
                      title: Text(
                        _userNameOf(user),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          already ? Icons.check : Icons.add,
                          color: already ? Colors.greenAccent : _kOrange,
                        ),
                        onPressed: already || userId.isEmpty
                            ? null
                            : () => _add(userId),
                      ),
                    );
                  },
                ),
              ),
            const Divider(color: Colors.white12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kOrange),
                    )
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (ctx, i) {
                        final member = _members[i];
                        final userId = _userIdOf(member);
                        return ListTile(
                          leading: _UserAvatar(user: member),
                          title: Text(
                            _userNameOf(member),
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            _boolOf(member['is_online']) ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          trailing: widget.roomType == 'group'
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: userId.isEmpty
                                      ? null
                                      : () => _remove(userId),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.isLoading,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isLoading;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, color: Colors.white38),
        suffixIcon: IconButton(
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: _kOrange,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.arrow_forward, color: _kOrange),
          onPressed: isLoading ? null : onSearch,
        ),
      ),
      onSubmitted: (_) => onSearch(),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, this.radius = 20});

  final Map<String, dynamic> user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarOf(user);
    final name = _userNameOf(user);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _kOrange.withValues(alpha: 0.2),
      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
      child: avatar.isEmpty
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: _kOrange,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

// ============= SINGLE CHAT SCREEN =============
class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _uploadingImage = false;
  bool _wsConnected = false;
  bool _closingWs = false;
  WebSocketChannel? _ws;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  int _reconnectAttempts = 0;
  String? _myUserId;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await TokenStorage.getUserId();
    _myUsername = await TokenStorage.getUsername();
    if (_myUserId == null || _myUserId!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      });
      return;
    }
    await _loadMessages();
    _connectWs();
    _startPolling();
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _loading = true);
    final messages = await ChatService.getMessages(widget.roomId);
    if (!mounted) return;
    setState(() {
      _messages = messages.map(_normalizeMessage).toList();
      _loading = false;
    });
    ChatService.markRoomRead(widget.roomId);
    _scrollToBottom();
  }

  void _connectWs() async {
    _reconnectTimer?.cancel();
    final token = await TokenStorage.getToken();
    if (!mounted || token == null || token.isEmpty) return;

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(
          '${AppConstants.wsBaseUrl}/chat/${widget.roomId}?token=$token',
        ),
      );
      _ws = channel;
      _wsConnected = true;
      _reconnectAttempts = 0;

      channel.stream.listen(
        (data) {
          if (!mounted) return;
          _wsConnected = true;
          try {
            final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
            _handleWsMessage(msg);
          } catch (_) {}
        },
        onError: (_) {
          _wsConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _wsConnected = false;
          if (!_closingWs) _scheduleReconnect();
        },
      );
    } catch (e) {
      _wsConnected = false;
      debugPrint('WebSocket connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted || _closingWs) return;
    _reconnectTimer?.cancel();
    final seconds = (2 << _reconnectAttempts.clamp(0, 4));
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _connectWs);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || _wsConnected) return;
      final recent = await ChatService.getMessages(
        widget.roomId,
        page: 1,
        limit: 30,
      );
      for (final msg in recent) {
        _appendMessage(msg);
      }
      ChatService.markRoomRead(widget.roomId);
    });
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    final eventType = msg['type']?.toString();
    if (eventType != null && eventType != 'message') return;
    final roomId = _valueOf(msg, const ['room_id', 'RoomId']);
    if (roomId.isNotEmpty && roomId != widget.roomId) return;
    _appendMessage(msg);
    ChatService.markRoomRead(widget.roomId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _closingWs = true;
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _ws?.sink.close();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    try {
      final result = await ChatService.sendMessage(widget.roomId, text);
      final localMessage = <String, dynamic>{
        ...?result,
        'room_id': widget.roomId,
        'sender_id': _myUserId,
        'sender_username': _myUsername,
        'content': text,
        'message_type': 'text',
        'is_own': true,
      };
      if (mounted) _appendMessage(localMessage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loi gui tin: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_uploadingImage) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      setState(() => _uploadingImage = true);

      final result = await ChatService.uploadMedia(widget.roomId, image);
      final mediaUrl = result?['media_url']?.toString() ?? '';
      if (mediaUrl.isEmpty) {
        throw Exception('Khong nhan duoc URL anh tu server');
      }

      final localMessage = <String, dynamic>{
        ...?result,
        'room_id': widget.roomId,
        'sender_id': _myUserId,
        'sender_username': _myUsername,
        'content': '[Image]',
        'message_type': 'image',
        'media_url': mediaUrl,
        'is_own': true,
      };
      if (mounted) _appendMessage(localMessage);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loi gui anh: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _messageIdOf(Map<String, dynamic> msg) {
    return _valueOf(msg, const ['message_id', 'MessageId', 'id', 'Id']);
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> msg) {
    final normalized = Map<String, dynamic>.from(msg);
    final rawType = _valueOf(normalized, const ['type']);
    normalized['message_type'] = _valueOf(normalized, const [
      'message_type',
      'MessageType',
    ], rawType == 'image' ? 'image' : 'text');
    normalized['content'] =
        normalized['content'] ?? normalized['Content'] ?? '';
    normalized['media_url'] =
        normalized['media_url'] ?? normalized['MediaUrl'] ?? '';
    normalized['sender_id'] = _valueOf(normalized, const [
      'sender_id',
      'SenderId',
    ]);
    normalized['sender_username'] = _valueOf(normalized, const [
      'sender_display_name',
      'SenderDisplayName',
      'sender_username',
      'SenderUsername',
    ], 'User');
    return normalized;
  }

  void _appendMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final normalized = _normalizeMessage(msg);
    final id = _messageIdOf(normalized);
    final duplicate =
        id.isNotEmpty && _messages.any((m) => _messageIdOf(m) == id);
    if (duplicate) return;
    setState(() => _messages.add(normalized));
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: Text(
          widget.roomName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMsg(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMsg(Map<String, dynamic> msg) {
    final senderId = _valueOf(msg, const ['SenderId', 'sender_id']);
    final content = msg['Content'] ?? msg['content'] ?? '';
    final senderName = _valueOf(msg, const [
      'sender_display_name',
      'SenderDisplayName',
      'SenderUsername',
      'sender_username',
    ], 'User');
    final isMe = msg['is_own'] == true || senderId == _myUserId;
    final mediaUrl = _valueOf(msg, const ['media_url', 'MediaUrl']);
    final messageType = _valueOf(msg, const [
      'message_type',
      'MessageType',
    ], 'text');
    final imageWidth = MediaQuery.of(context).size.width * 0.55;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(messageType == 'image' ? 8 : 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? _kOrange : _kCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    color: _kOrange.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (messageType == 'image' && mediaUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _openImageViewer(mediaUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    width: imageWidth,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        _imagePlaceholder(imageWidth),
                    errorWidget: (context, url, error) =>
                        _imageError(imageWidth),
                  ),
                ),
              )
            else if (messageType == 'image')
              _imageError(imageWidth)
            else
              Text(
                content.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(double width) {
    return Container(
      width: width,
      height: 150,
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2),
      ),
    );
  }

  Widget _imageError(double width) {
    return Container(
      width: width,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white38, size: 36),
          SizedBox(height: 4),
          Text(
            'Khong tai duoc anh',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Gui anh',
            icon: _uploadingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _kOrange,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.image_outlined, color: Colors.white54),
            onPressed: _uploadingImage ? null : _pickAndSendImage,
          ),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nhap tin nhan...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: _kCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: _kOrange),
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  void _openImageViewer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ChatImageViewer(imageUrl: url)),
    );
  }
}

class _ChatImageViewer extends StatefulWidget {
  const _ChatImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  State<_ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<_ChatImageViewer> {
  bool _sharing = false;

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final response = await Dio().get<List<int>>(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? <int>[]);
      if (bytes.isEmpty) throw Exception('Khong tai duoc anh');
      await Share.shareXFiles([
        XFile.fromData(bytes, name: 'chat_image.jpg', mimeType: 'image/jpeg'),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khong the tai anh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Tai anh',
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _kOrange,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _sharing ? null : _shareImage,
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(widget.imageUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      ),
    );
  }
}
