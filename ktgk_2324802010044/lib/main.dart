// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_tab_screen.dart';
import 'screens/admin/admin_screen.dart';

// --- DESIGN TOKENS ---
const colorTextPrimary = Color(0xFFFFFFFF);
const colorTextSecondary = Color(0xFFFF6740); // MangaDex Orange
const colorSurfaceBase = Color(0xFF000000);
const colorSurfaceMuted = Color(0xFF2C2C2C);
const colorBorderDefault = Color(0xFFE5E7EB);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'MangaDex',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: colorSurfaceBase,
        colorScheme: const ColorScheme.dark(
          primary: colorTextSecondary,
          surface: colorSurfaceBase,
          onSurface: colorTextPrimary,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          baseTheme.textTheme,
        ).apply(bodyColor: colorTextPrimary, displayColor: colorTextPrimary),
        appBarTheme: const AppBarTheme(
          backgroundColor: colorSurfaceBase,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorTextSecondary,
            foregroundColor: colorTextPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorSurfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: colorTextSecondary, width: 1.5),
          ),
        ),
      ),
      home: const _AppEntry(),
    );
  }
}

/// Entry widget that initializes AuthProvider and routes accordingly
class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = context.read<AuthProvider>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF000000),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 64,
                    color: Color(0xFFFF6740),
                  ),
                  SizedBox(height: 16),
                  CircularProgressIndicator(color: Color(0xFFFF6740)),
                ],
              ),
            ),
          );
        }
        // Consumer creates a DEDICATED subscription to AuthProvider.
        // Every notifyListeners() call guarantees a rebuild of this builder.
        return Consumer<AuthProvider>(
          builder: (context, auth, child) {
            if (!auth.isAuthenticated) {
              return const AuthScreen();
            }
            if (auth.user?.role == 'admin') {
              return const AdminScreen();
            }
            return const MainTabScreen();
          },
        );
      },
    );
  }
}
