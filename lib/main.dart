import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'components/image_upload/image_upload_page.dart';
import 'components/product/product_ui.dart'; // Import ProductUI instead of product.dart
import 'components/product/product.dart';
import 'components/product/purchase_details_page.dart';
import 'components/product/mobile_product_view.dart';
import 'components/auth/login_page.dart';
import 'components/auth/auth_service.dart';
import 'data/local_database.dart';

// Define route names as constants for consistency
class AppRoutes {
  static const String home = '/';
  static const String products = '/products';
  static const String imageUpload = '/image_upload';
  static const String purchaseDetails = '/purchase_details';
  static const String login = '/login';
  static const String mobileProducts = '/mobile_products';
}

void main() async {
  // Wrap everything in a zone to catch all errors
  runZonedGuarded(
    () async {
      // Ensure Flutter is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Suppress non-critical Flutter framework errors and FormatExceptions
      FlutterError.onError = (FlutterErrorDetails details) {
        // Suppress FormatException, keyboard errors, and other non-critical warnings
        final exception = details.exception.toString();
        final isNonCritical =
            exception.contains('RawKeyDownEvent') ||
            exception.contains('keysPressed') ||
            exception.contains('FormatException') ||
            exception.contains('Null check operator');

        if (!isNonCritical) {
          FlutterError.presentError(details);
        }
      };

      // Replace the red error screen with a blank widget
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Container(
          color: Colors.white,
          child: Center(child: CircularProgressIndicator()),
        );
      };

      // Initialize SQLite for desktop platforms
      LocalDatabase.initializeFfi();

      // Initialize Supabase with localStorage disabled to prevent FormatException
      try {
        await Supabase.initialize(
          url: 'https://lhytairgnojpzgbgjhod.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxoeXRhaXJnbm9qcHpnYmdqaG9kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MDI4MjYsImV4cCI6MjA1NzA3ODgyNn0.uDxpy6lcB4STumSknuDmrjwZDuSekcY4i1A07nHCQdM',
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
          storageOptions: const StorageClientOptions(retryAttempts: 3),
        );
      } catch (e) {
        // Silently handle any initialization errors including FormatException
        // The app will work with limited functionality
      }

      runApp(const AppRoot());
    },
    (error, stack) {
      // Catch all uncaught errors including FormatException
      // Silently ignore to prevent app crash
    },
  );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isLoading = true; // Start loading while checking session
  bool _isAuthenticated = false; // Default to not authenticated

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    print('[AUTH] Starting authentication check...');
    try {
      final authService = AuthService();
      print('[AUTH] Calling checkAndRestoreSession...');
      final hasValidSession = await authService
          .checkAndRestoreSession()
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              print('[AUTH] Session check timed out after 4 seconds');
              return false;
            },
          );
      print('[AUTH] Session check result: $hasValidSession');
      if (!mounted) {
        print('[AUTH] Widget not mounted, skipping setState');
        return;
      }
      setState(() {
        _isAuthenticated = hasValidSession;
        _isLoading = false;
      });
      print(
        '[AUTH] State updated - isAuthenticated: $hasValidSession, isLoading: false',
      );
    } catch (e, stackTrace) {
      print('[AUTH] Error during authentication check: $e');
      print('[AUTH] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
      print(
        '[AUTH] State updated after error - isAuthenticated: false, isLoading: false',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[BUILD] Building AppRoot - isLoading: $_isLoading, isAuthenticated: $_isAuthenticated',
    );
    try {
      if (_isLoading) {
        print('[BUILD] Showing loading screen');
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }

      print(
        '[BUILD] Showing main app with initialRoute: ${_isAuthenticated ? AppRoutes.mobileProducts : AppRoutes.login}',
      );
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
        // Use home instead of initialRoute to avoid route initialization issues
        home: _isAuthenticated
            ? BlocProvider(
                create: (context) => ProductBloc(
                  ProductRepository(),
                )..add(LoadPaginatedProducts(page: 1, pageSize: 20)),
                child: const MobileProductView(),
              )
            : const LoginPage(),
        routes: {
          AppRoutes.products: (context) => const ProductDashboard(),
          AppRoutes.imageUpload: (context) => const ImageUploadPage(),
          AppRoutes.purchaseDetails: (context) => const PurchaseDetailsPage(),
          AppRoutes.login: (context) => const LoginPage(),
          AppRoutes.mobileProducts: (context) => BlocProvider(
                create: (context) => ProductBloc(
                  ProductRepository(),
                )..add(LoadPaginatedProducts(page: 1, pageSize: 20)),
                child: const MobileProductView(),
              ),
        },
        onGenerateRoute: (settings) {
          try {
            switch (settings.name) {
              case AppRoutes.products:
              case AppRoutes.home:
                return MaterialPageRoute(
                  builder: (_) => const ProductDashboard(),
                );
              case AppRoutes.imageUpload:
                return MaterialPageRoute(
                  builder: (_) => const ImageUploadPage(),
                );
              case AppRoutes.purchaseDetails:
                return MaterialPageRoute(
                  builder: (_) => const PurchaseDetailsPage(),
                );
              case AppRoutes.mobileProducts:
                return MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (context) => ProductBloc(
                      ProductRepository(),
                    )..add(LoadPaginatedProducts(page: 1, pageSize: 20)),
                    child: const MobileProductView(),
                  ),
                );
              case AppRoutes.login:
                return MaterialPageRoute(builder: (_) => const LoginPage());
              default:
                // If not authenticated, always route to login for unknown routes
                if (!_isAuthenticated) {
                  return MaterialPageRoute(builder: (_) => const LoginPage());
                }
                return MaterialPageRoute(
                  builder: (_) => const ProductDashboard(),
                );
            }
          } catch (e) {
            // If any error occurs, route to login
            return MaterialPageRoute(builder: (_) => const LoginPage());
          }
        },
        onUnknownRoute: (_) {
          // If not authenticated, route to login, otherwise to products
          try {
            if (!_isAuthenticated) {
              return MaterialPageRoute(builder: (_) => const LoginPage());
            }
            return MaterialPageRoute(builder: (_) => const ProductDashboard());
          } catch (e) {
            return MaterialPageRoute(builder: (_) => const LoginPage());
          }
        },
      );
    } catch (e) {
      // If MaterialApp build fails, show a simple loading screen
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Loading...'),
              ],
            ),
          ),
        ),
      );
    }
  }
}
