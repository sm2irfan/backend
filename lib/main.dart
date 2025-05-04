import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/image_upload/image_upload_page.dart';
import 'components/product/product.dart';
import 'components/auth/login_page.dart';
import 'data/local_database.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for desktop platforms
  LocalDatabase.initializeFfi();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://lhytairgnojpzgbgjhod.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxoeXRhaXJnbm9qcHpnYmdqaG9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MDI4MjYsImV4cCI6MjA1NzA3ODgyNn0.uDxpy6lcB4STumSknuDmrjwZDuSekcY4i1A07nHCQdM',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Remove "const" to avoid rebuild issues
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const ProductApp(),
        '/image-upload': (context) => const ImageUploadPage(),
      },
    );
  }
}
