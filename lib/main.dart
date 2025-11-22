import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tirrtagqlhqylwqwfosu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpcnJ0YWdxbGhxeWx3cXdmb3N1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyODgzNTAsImV4cCI6MjA3Mzg2NDM1MH0.73J-P1qiao8oUYuyZ9nIw53DvXzyu3tFp6n_1qwIS3s',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const TenantApp(),
    ),
  );
}

class TenantApp extends StatefulWidget {
  const TenantApp({super.key});

  @override
  State<TenantApp> createState() => _TenantAppState();
}

class _TenantAppState extends State<TenantApp> {
  final client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = client.auth.currentSession;
      if (session == null) {
        await client.auth.signInAnonymously();
        debugPrint('✅ Anonymous session created (test mode)');
      } else {
        debugPrint('🔁 Restored session for user: ${session.user.id}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    // ✅ Define Custom Light Scheme for better chart colors
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00529B),
        brightness: Brightness.light,
        // Override generated colors for more vibrancy
        primaryContainer: const Color(0xFF00529B).withOpacity(0.8), 
        errorContainer: Colors.red.shade100,
        onErrorContainer: Colors.red.shade900,
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.08), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    // ✅ Define Dark Theme with soft shadows
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00529B),
        brightness: Brightness.dark,
        // Override for vibrancy in dark mode too
        primaryContainer: const Color(0xFF3F9FFF), 
        errorContainer: Colors.red.shade900.withOpacity(0.5),
        onErrorContainer: Colors.red.shade100,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.4),
        color: const Color(0xFF1E1E1E), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leverizaland Inc.',
      themeMode: themeService.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const HomePage(),
    );
  }
}
