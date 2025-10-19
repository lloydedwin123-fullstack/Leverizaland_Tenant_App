import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase (no AuthOptions in v2.10+)
  await Supabase.initialize(
    url: 'https://tirrtagqlhqylwqwfosu.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpcnJ0YWdxbGhxeWx3cXdmb3N1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyODgzNTAsImV4cCI6MjA3Mzg2NDM1MH0.73J-P1qiao8oUYuyZ9nIw53DvXzyu3tFp6n_1qwIS3s',
  );

  runApp(const TenantApp());
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

    // ✅ Ensure session *after* app mounts (avoids blank screen on web)
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leverizaland Inc.',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}
