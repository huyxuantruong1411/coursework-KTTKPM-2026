import 'package:flutter/material.dart';
import 'explore/explore_screen.dart';
import 'explore/search_screen.dart';
import 'history/history_screen.dart';
import 'library/library_screen.dart';
import 'chat/chat_screen.dart';
import 'profile/profile_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final _pages = [
    const ExploreScreen(),
    const SearchScreen(),
    const HistoryScreen(),
    const LibraryScreen(),
    const ChatRoomsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF2C2C2C),
        indicatorColor: const Color(0xFFFF6740).withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Color(0xFFFF6740)),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: Color(0xFFFF6740)),
            label: 'Tìm kiếm',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFFFF6740)),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark, color: Color(0xFFFF6740)),
            label: 'Thư viện',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFFFF6740)),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFFFF6740)),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
