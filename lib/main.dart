import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tirrtagqlhqylwqwfosu.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpcnJ0YWdxbGhxeWx3cXdmb3N1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyODgzNTAsImV4cCI6MjA3Mzg2NDM1MH0.73J-P1qiao8oUYuyZ9nIw53DvXzyu3tFp6n_1qwIS3s',
  );

  runApp(const TenantApp());
}

class TenantApp extends StatelessWidget {
  const TenantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leverizaland Inc.',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}
