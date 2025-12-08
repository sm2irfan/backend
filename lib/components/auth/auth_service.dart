import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/local_database.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  AuthResult({required this.success, this.errorMessage, this.user});

  factory AuthResult.success(User user) {
    return AuthResult(success: true, user: user);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(success: false, errorMessage: message);
  }
}

class AuthService {
  SupabaseClient get _supabase => Supabase.instance.client;
  final _localDb = LocalDatabase();

  // Check if Supabase is properly initialized
  bool get _isSupabaseAvailable {
    try {
      return Supabase.instance.isInitialized;
    } catch (e) {
      return false;
    }
  }

  // Sign in with email/username and password
  Future<AuthResult> signIn(String email, String password) async {
    try {
      // Check if Supabase is initialized
      if (!_isSupabaseAvailable) {
        return AuthResult.failure(
          'Authentication service is not available. Please restart the app.',
        );
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (response.user != null && response.session != null) {
        // Save session token to local database
        await _saveSessionToken(response.session!);
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.failure(
          'Login failed. Please check your credentials.',
        );
      }
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    // Clear saved session token
    await _clearSessionToken();
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      return AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Failed to reset password. Please try again.');
    }
  }

  // Save session token to local database
  Future<void> _saveSessionToken(Session session) async {
    await _localDb.setConfigValue('access_token', session.accessToken);
    await _localDb.setConfigValue('refresh_token', session.refreshToken ?? '');
    await _localDb.setConfigValue(
      'expires_at',
      session.expiresAt?.toString() ?? '',
    );
  }

  // Clear saved session token
  Future<void> _clearSessionToken() async {
    await _localDb.setConfigValue('access_token', '');
    await _localDb.setConfigValue('refresh_token', '');
    await _localDb.setConfigValue('expires_at', '');
  }

  // Check for valid saved session and restore it
  Future<bool> checkAndRestoreSession() async {
    print('[AUTH_SERVICE] Starting checkAndRestoreSession');
    try {
      // Check if Supabase is initialized
      if (!_isSupabaseAvailable) {
        print('[AUTH_SERVICE] Supabase not available');
        return false;
      }
      print('[AUTH_SERVICE] Supabase is available');

      // First check if Supabase already has a session
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        print('[AUTH_SERVICE] Found existing Supabase session');
        return true;
      }
      print('[AUTH_SERVICE] No existing Supabase session');

      // Try to restore from local database
      print('[AUTH_SERVICE] Fetching tokens from local database...');
      final accessToken = await _localDb.getConfigValue('access_token');
      final refreshToken = await _localDb.getConfigValue('refresh_token');
      final expiresAtStr = await _localDb.getConfigValue('expires_at');
      print(
        '[AUTH_SERVICE] Access token exists: ${accessToken != null && accessToken.isNotEmpty}',
      );
      print(
        '[AUTH_SERVICE] Refresh token exists: ${refreshToken != null && refreshToken.isNotEmpty}',
      );

      if (accessToken == null || accessToken.isEmpty) {
        print('[AUTH_SERVICE] No saved access token found');
        return false;
      }

      // Check if token is expired
      if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
        final expiresAt = int.tryParse(expiresAtStr);
        if (expiresAt != null) {
          final expiryTime = DateTime.fromMillisecondsSinceEpoch(
            expiresAt * 1000,
          );
          print(
            '[AUTH_SERVICE] Token expiry: $expiryTime, Now: ${DateTime.now()}',
          );
          if (DateTime.now().isAfter(expiryTime)) {
            print('[AUTH_SERVICE] Token expired, attempting refresh...');
            // Token expired, try to refresh
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final response = await _supabase.auth.refreshSession(
                  refreshToken,
                );
                if (response.session != null) {
                  print('[AUTH_SERVICE] Token refresh successful');
                  await _saveSessionToken(response.session!);
                  return true;
                }
              } catch (e) {
                print('[AUTH_SERVICE] Token refresh failed: $e');
                // Refresh failed, clear tokens
                await _clearSessionToken();
                return false;
              }
            }
            print('[AUTH_SERVICE] No refresh token available');
            return false;
          }
        }
      }

      // Prefer refresh token-based restoration
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          print('[AUTH_SERVICE] Attempting setSession with refresh token...');
          final response = await _supabase.auth
              .setSession(refreshToken)
              .timeout(const Duration(seconds: 4));
          if (response.session != null) {
            print('[AUTH_SERVICE] setSession successful');
            await _saveSessionToken(response.session!);
            return true;
          }
        } catch (e) {
          print('[AUTH_SERVICE] setSession failed: $e');
          // ignore and try access token path
        }
      }

      // Fallback: attempt recovery with access token
      try {
        print('[AUTH_SERVICE] Attempting recoverSession with access token...');
        await _supabase.auth
            .recoverSession(accessToken)
            .timeout(const Duration(seconds: 4));
        final hasUser = _supabase.auth.currentUser != null;
        print('[AUTH_SERVICE] recoverSession result: $hasUser');
        return hasUser;
      } catch (e) {
        print('[AUTH_SERVICE] recoverSession failed: $e');
        // Session recovery failed, clear tokens
        await _clearSessionToken();
        return false;
      }
    } on FormatException catch (e) {
      print('[AUTH_SERVICE] FormatException: $e');
      // Handle corrupted token data
      await _clearSessionToken();
      return false;
    } catch (e) {
      print('[AUTH_SERVICE] Unexpected error: $e');
      // Handle any other errors
      return false;
    }
  }
}
