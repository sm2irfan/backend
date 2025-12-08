import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/image_upload/image_upload_page.dart';
import 'components/product/product_ui.dart'; // Import ProductUI instead of product.dart
import 'components/product/purchase_details_page.dart';
import 'components/auth/login_page.dart';
import 'data/local_database.dart';

// Define route names as constants for consistency
class AppRoutes {
  static const String home = '/';
  static const String products = '/products';
  static const String imageUpload = '/image_upload';
  static const String purchaseDetails = '/purchase_details';
  static const String login = '/login';
}

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress non-critical Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Only log critical errors, suppress keyboard and other framework warnings
    final isCritical =
        !details.exception.toString().contains('RawKeyDownEvent') &&
        !details.exception.toString().contains('keysPressed');

    if (isCritical) {
      FlutterError.presentError(details);
    }
  };

  // Initialize SQLite for desktop platforms
  LocalDatabase.initializeFfi();

  // Initialize Supabase with error handling for cached data
  try {
    await Supabase.initialize(
      url: 'https://lhytairgnojpzgbgjhod.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxoeXRhaXJnbm9qcHpnYmdqaG9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MDI4MjYsImV4cCI6MjA1NzA3ODgyNn0.uDxpy6lcB4STumSknuDmrjwZDuSekcY4i1A07nHCQdM',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    // Silently handle FormatException from corrupted cache
    if (!e.toString().contains('FormatException')) {
      rethrow;
    }
    // If initialization fails due to corrupted cache, retry
    try {
      await Supabase.initialize(
        url: 'https://lhytairgnojpzgbgjhod.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxoeXRhaXJnbm9qcHpnYmdqaG9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MDI4MjYsImV4cCI6MjA1NzA3ODgyNn0.uDxpy6lcB4STumSknuDmrjwZDuSekcY4i1A07nHCQdM',
      );
    } catch (retryError) {
      // Silently ignore if retry also fails
    }
  }

  runApp(AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely check for session without throwing errors
    bool isLoggedIn = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      isLoggedIn = session != null;
    } catch (e) {
      // If there's an error checking session, assume not logged in
      isLoggedIn = false;
    }

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
        AppRoutes.purchaseDetails: (context) => const PurchaseDetailsPage(),
        AppRoutes.login: (context) => const LoginPage(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.products:
            return MaterialPageRoute(builder: (_) => const ProductDashboard());
          case AppRoutes.imageUpload:
            return MaterialPageRoute(builder: (_) => const ImageUploadPage());
          case AppRoutes.purchaseDetails:
            return MaterialPageRoute(
              builder: (_) => const PurchaseDetailsPage(),
            );
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
