import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/product/product.dart';
import 'dart:developer' as developer;
// Add these imports for desktop support
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

// Create a custom exception for SQLite availability issues
class SqliteNotAvailableException implements Exception {
  final String message;
  SqliteNotAvailableException(this.message);

  @override
  String toString() => message;
}

class LocalDatabase {
  static Database? _database;
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  // Flag to track if SQLite is available
  static bool _sqliteAvailable = true;
  // Flag to prevent multiple initialization attempts
  static bool _initializationAttempted = false;

  // Singleton pattern to ensure only one instance exists
  static final LocalDatabase _instance = LocalDatabase._internal();

  factory LocalDatabase() {
    return _instance;
  }

  LocalDatabase._internal();

  // Initialize sqflite_ffi for desktop platforms with proper error handling
  static Future<bool> initializeFfi() async {
    // Skip if we've already attempted initialization
    if (_initializationAttempted) return _sqliteAvailable;

    _initializationAttempted = true;

    try {
      // Only use FFI for desktop platforms
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Initialize FFI
        sqfliteFfiInit();

        // Important: Set the database factory IMMEDIATELY after initialization
        // This fixes the "databaseFactory not initialized" error
        databaseFactory = databaseFactoryFfi;
        developer.log('Set database factory to FFI implementation');

        // On Linux, check if SQLite is installed
        if (Platform.isLinux) {
          try {
            // Test if we can open a database
            final dbTest = await databaseFactory.openDatabase(':memory:');
            await dbTest.close();
            developer.log('SQLite library test successful');
            _sqliteAvailable = true;
          } catch (e) {
            developer.log('SQLite library test failed: $e');
            _sqliteAvailable = false;

            // Provide detailed installation instructions for different Linux distributions
            developer.log('''
SQLite library not found. Please install it using one of the following commands:

For Ubuntu/Debian:
  sudo apt-get update && sudo apt-get install -y libsqlite3-dev

For Fedora:
  sudo dnf install -y sqlite-devel

For Arch Linux:
  sudo pacman -S sqlite

Then restart the application.
''');

            return false;
          }
        }

        developer.log(
          'Successfully initialized SQLite FFI for desktop platform',
        );
        return true;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, SQLite is natively supported
        _sqliteAvailable = true;
        developer.log('Running on mobile, using native SQLite');
        return true;
      }
    } catch (e) {
      developer.log('Failed to initialize SQLite: $e');
      _sqliteAvailable = false;
      return false;
    }

    return _sqliteAvailable;
  }

  // Get a database instance with fallback for when SQLite is unavailable
  Future<Database> get database async {
    // First check if SQLite is available and initialize it
    bool initialized = await initializeFfi();
    if (!initialized) {
      throw SqliteNotAvailableException(
        'SQLite library is not available. ${Platform.isLinux ? 'Please install it with: sudo apt-get install -y libsqlite3-dev' : 'Please ensure SQLite is properly installed.'}',
      );
    }

    if (_database != null) return _database!;

    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      developer.log('Error initializing database: $e');
      _sqliteAvailable = false;
      throw SqliteNotAvailableException('Failed to initialize SQLite: $e');
    }
  }

  // Initialize the database with better error handling
  Future<Database> _initDatabase() async {
    try {
      final String path = await getDatabasesPath();
      final String dbPath = join(path, 'product_database.db');

      developer.log('Initializing SQLite database at $dbPath');

      return await openDatabase(dbPath, version: 1, onCreate: _createDatabase);
    } catch (e) {
      developer.log('Error initializing database: $e');
      rethrow;
    }
  }

  // Create tables in the database
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS all_products(
        id INTEGER PRIMARY KEY,
        created_at TEXT,
        name TEXT NOT NULL,
        uprices TEXT NOT NULL,
        image TEXT,
        discount INTEGER,
        description TEXT,
        category_1 TEXT,
        category_2 TEXT,
        popular_product INTEGER NOT NULL,
        matching_words TEXT
      )
    ''');
  }

  // Check if all_products table exists
  Future<bool> doesProductTableExist() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='all_products'",
      );
      return result.isNotEmpty;
    } catch (e) {
      developer.log('Error checking if table exists: $e');
      return false;
    }
  }

  // Check if SQLite is available
  static Future<bool> isSqliteAvailable() async {
    if (_initializationAttempted) return _sqliteAvailable;

    return await initializeFfi();
  }

  // Simulate database operations when SQLite is not available
  Future<Map<String, dynamic>> simulateSyncOperation() async {
    // Fake operation for when SQLite is not available
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    return {
      'success': false,
      'message':
          'SQLite library not available on this system. ${Platform.isLinux ? 'Please install SQLite development libraries with:\n'
                  '  sudo apt-get update && sudo apt-get install -y libsqlite3-dev' : 'Please ensure SQLite is properly installed.'}',
      'count': 0,
      'sqlite_missing': true,
    };
  }

  // Safe version of syncProductsFromSupabase that checks SQLite availability first
  Future<Map<String, dynamic>> syncProductsFromSupabase() async {
    if (!await isSqliteAvailable()) {
      return simulateSyncOperation();
    }

    try {
      final db = await database;
      // Begin transaction
      await db.transaction((txn) async {
        // Clear existing data if any
        await txn.execute('DELETE FROM all_products');

        // Fetch all products from Supabase
        final response = await _supabaseClient.from('all_products').select();

        developer.log('Fetched ${response.length} products from Supabase');

        // Insert each product into SQLite
        int successCount = 0;
        int failCount = 0;

        for (var item in response) {
          try {
            // Convert bool to int for SQLite
            final popularProductInt = item['popular_product'] == true ? 1 : 0;

            await txn.insert('all_products', {
              'id': item['id'],
              'created_at':
                  item['created_at'] ?? DateTime.now().toIso8601String(),
              'name': item['name'] ?? 'Unnamed Product',
              'uprices': item['uprices']?.toString() ?? '0',
              'image': item['image'],
              'discount': item['discount'],
              'description': item['description'],
              'category_1': item['category_1'],
              'category_2': item['category_2'],
              'popular_product': popularProductInt,
              'matching_words': item['matching_words'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            successCount++;
          } catch (e) {
            developer.log('Error inserting product: $e');
            failCount++;
          }
        }

        developer.log(
          'Sync completed: $successCount products inserted, $failCount failed',
        );
      });

      // Get count of records after transaction
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM all_products',
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;

      return {
        'success': true,
        'message': 'Synced $count products from Supabase to SQLite',
        'count': count,
      };
    } catch (e) {
      developer.log('Error syncing products: $e');
      return {
        'success': false,
        'message': 'Failed to sync products: $e',
        'count': 0,
      };
    }
  }

  // Safe version of getLocalPaginatedProducts
  Future<Map<String, dynamic>> getLocalPaginatedProducts(
    int page,
    int pageSize,
  ) async {
    if (!await isSqliteAvailable()) {
      throw Exception(
        'SQLite is not available. Please install libsqlite3-dev package.',
      );
    }

    try {
      final db = await database;

      // Get total count for pagination
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM all_products',
      );
      final totalItems = Sqflite.firstIntValue(countResult) ?? 0;

      // Calculate offset based on page number and page size
      final offset = (page - 1) * pageSize;

      // Fetch paginated data
      final results = await db.query(
        'all_products',
        orderBy: 'id DESC',
        limit: pageSize,
        offset: offset,
      );

      // Parse products
      List<Product> products = [];
      for (var json in results) {
        try {
          // Convert SQLite bool (stored as int) back to bool for Product class
          final bool popularProduct = (json['popular_product'] as int?) == 1;

          final product = Product(
            id: json['id'] as int,
            createdAt:
                json['created_at'] != null
                    ? DateTime.parse(json['created_at'] as String)
                    : DateTime(2023, 1, 1),
            name: json['name'] as String? ?? 'Unnamed Product',
            uPrices: json['uprices'] as String? ?? '0',
            image: json['image'] as String?,
            discount: json['discount'] as int?,
            description: json['description'] as String?,
            category1: json['category_1'] as String?,
            category2: json['category_2'] as String?,
            popularProduct: popularProduct,
            matchingWords: json['matching_words'] as String?,
          );
          products.add(product);
        } catch (parseError) {
          developer.log('Error parsing product from SQLite: $parseError');
        }
      }

      // Calculate pagination info
      final totalPages = (totalItems / pageSize).ceil();
      final hasNextPage = page < totalPages;
      final hasPreviousPage = page > 1;

      return {
        'products': products,
        'totalItems': totalItems,
        'currentPage': page,
        'totalPages': totalPages,
        'hasNextPage': hasNextPage,
        'hasPreviousPage': hasPreviousPage,
      };
    } catch (e) {
      developer.log('Error fetching local products: $e');
      throw Exception('Failed to load local products: $e');
    }
  }
}
