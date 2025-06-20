import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/image_upload/image_upload_page.dart';
import 'components/product/product_ui.dart'; // Import ProductUI instead of product.dart
import 'components/auth/login_page.dart';
import 'data/local_database.dart';

// Define route names as constants for consistency
class AppRoutes {
  static const String home = '/';
  static const String products = '/products';
  static const String imageUpload = '/image_upload';
  static const String login = '/login';
}

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

  runApp(AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final bool isLoggedIn = session != null;

    return MaterialApp(
      title: 'Product Management App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 1,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
      ),
      debugShowCheckedModeBanner: false,
      // Set initialRoute based on login state
      initialRoute: isLoggedIn ? AppRoutes.products : AppRoutes.login,
      routes: {
        AppRoutes.home: (context) => const ProductDashboard(),
        AppRoutes.products: (context) => const ProductDashboard(),
        AppRoutes.imageUpload: (context) => const ImageUploadPage(),
        AppRoutes.login: (context) => const LoginPage(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.products:
            return MaterialPageRoute(builder: (_) => const ProductDashboard());
          case AppRoutes.imageUpload:
            return MaterialPageRoute(builder: (_) => const ImageUploadPage());
          default:
            return MaterialPageRoute(builder: (_) => const ProductDashboard());
        }
      },
      onUnknownRoute: (_) {
        return MaterialPageRoute(builder: (_) => const ProductDashboard());
      },
    );
  }
}
