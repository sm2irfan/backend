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

      return await openDatabase(
        dbPath,
        version: 2, // Increased version number for migration
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE all_products(
            id INTEGER PRIMARY KEY,
            created_at TEXT,
            updated_at TEXT,
            name TEXT,
            uprices TEXT,
            image TEXT,
            discount INTEGER,
            description TEXT,
            category_1 TEXT,
            category_2 TEXT,
            popular_product INTEGER,
            matching_words TEXT
          )
          ''');

          // Create the column visibility settings table
          await db.execute('''
          CREATE TABLE column_visibility(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            view_name TEXT NOT NULL,
            column_index INTEGER NOT NULL,
            is_visible INTEGER NOT NULL,
            UNIQUE(view_name, column_index)
          )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Add column_visibility table if upgrading from version 1
            await db.execute('''
            CREATE TABLE IF NOT EXISTS column_visibility(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              view_name TEXT NOT NULL,
              column_index INTEGER NOT NULL,
              is_visible INTEGER NOT NULL,
              UNIQUE(view_name, column_index)
            )
            ''');
          }
        },
      );
    } catch (e) {
      developer.log('Error initializing database: $e');
      _sqliteAvailable = false;
      throw SqliteNotAvailableException('Failed to initialize SQLite: $e');
    }
  }

  // Create tables in the database
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS all_products(
        id INTEGER PRIMARY KEY,
        created_at TEXT,
        updated_at TEXT,
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

  // Add migration function for database upgrades
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    developer.log('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Check if the column exists before adding it to avoid errors
      var columns = await db.rawQuery('PRAGMA table_info(all_products)');
      var columnNames = columns.map((c) => c['name'] as String).toList();

      if (!columnNames.contains('updated_at')) {
        developer.log('Adding updated_at column to all_products table');
        await db.execute('ALTER TABLE all_products ADD COLUMN updated_at TEXT');
      }
    }
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
              'updated_at':
                  item['updated_at'] ?? DateTime.now().toIso8601String(),
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

  // Updated to support filtering with comma-separated IDs and LIKE queries for name and category1
  Future<Map<String, dynamic>> getLocalPaginatedProducts(
    int page,
    int pageSize, {
    Map<String, String> filters = const {},
  }) async {
    if (!await isSqliteAvailable()) {
      throw Exception(
        'SQLite is not available. Please install libsqlite3-dev package.',
      );
    }

    try {
      final db = await database;

      // Start building the query
      String queryConditions = '';
      List<dynamic> queryArgs = [];

      // Add filter conditions if any
      if (filters.isNotEmpty) {
        List<String> conditions = [];

        // Handle ID filter with comma-separated values
        if (filters.containsKey('id')) {
          final String idFilter = filters['id']!.trim();

          if (idFilter.contains(',')) {
            // Handle comma-separated IDs
            List<String> idValues =
                idFilter
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

            if (idValues.isNotEmpty) {
              // Create placeholders for each ID
              List<String> idPlaceholders = List.generate(
                idValues.length,
                (_) => '?',
              );

              // Build the IN clause
              conditions.add('id IN (${idPlaceholders.join(', ')})');

              // Add each ID as a separate argument
              for (var idVal in idValues) {
                try {
                  // Parse each ID value to int
                  queryArgs.add(int.parse(idVal));
                } catch (e) {
                  developer.log('Error parsing ID value: $idVal - $e');
                  // Skip invalid IDs
                }
              }
            }
          } else {
            // Single ID value
            try {
              conditions.add('id = ?');
              queryArgs.add(int.parse(idFilter));
            } catch (e) {
              developer.log('Error parsing single ID: $idFilter - $e');
              // If parsing fails, use an impossible ID to ensure no results
              conditions.add('id = ?');
              queryArgs.add(-1);
            }
          }
        }

        // Handle name filter with LIKE query support
        if (filters.containsKey('name')) {
          final String nameFilter = filters['name']!.trim();

          if (nameFilter.isNotEmpty) {
            // Check if the value starts with the LIKE: prefix
            if (nameFilter.startsWith('LIKE:')) {
              // Extract the actual search term
              final String searchTerm = nameFilter.substring(5).trim();

              if (searchTerm.contains(' ')) {
                // Handle multi-word search by creating multiple LIKE conditions
                final List<String> words =
                    searchTerm.split(' ').where((w) => w.isNotEmpty).toList();
                if (words.isNotEmpty) {
                  List<String> wordConditions = [];

                  // Create a LIKE condition for each word
                  for (var word in words) {
                    wordConditions.add('name LIKE ?');
                    queryArgs.add('%$word%');
                  }

                  // Join all word conditions with AND
                  conditions.add('(${wordConditions.join(' AND ')})');

                  developer.log(
                    'Added multi-word LIKE query for name with words: $words',
                  );
                }
              } else {
                // Single word search - existing behavior
                conditions.add('name LIKE ?');
                queryArgs.add('%$searchTerm%');

                developer.log('Added LIKE query for name: %$searchTerm%');
              }
            } else {
              // Standard exact match
              conditions.add('name = ?');
              queryArgs.add(nameFilter);
              developer.log('Added exact match query for name: $nameFilter');
            }
          }
        }

        // Handle category1 filter with LIKE query support
        if (filters.containsKey('category1')) {
          final String categoryFilter = filters['category1']!.trim();

          if (categoryFilter.isNotEmpty) {
            // Check if the value starts with the LIKE: prefix
            if (categoryFilter.startsWith('LIKE:')) {
              // Extract the actual search term
              final String searchTerm = categoryFilter.substring(5).trim();
              conditions.add('category_1 LIKE ?');
              queryArgs.add('%$searchTerm%');
              developer.log('Added LIKE query for category1: %$searchTerm%');
            } else {
              // Use LIKE query for category1 regardless (for partial matching)
              conditions.add('category_1 LIKE ?');
              queryArgs.add('%$categoryFilter%');
              developer.log(
                'Added LIKE query for category1: %$categoryFilter%',
              );
            }
          }
        }

        // Add more column filters here in the future

        if (conditions.isNotEmpty) {
          queryConditions = ' WHERE ${conditions.join(" AND ")}';
        }
      }

      // Get total count for pagination with filters applied
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM all_products$queryConditions',
        queryArgs,
      );
      final totalItems = Sqflite.firstIntValue(countResult) ?? 0;

      // Calculate offset based on page number and page size
      final offset = (page - 1) * pageSize;

      // Fetch paginated data with filters
      final results = await db.rawQuery(
        'SELECT * FROM all_products$queryConditions ORDER BY id DESC LIMIT ? OFFSET ?',
        [...queryArgs, pageSize, offset],
      );

      // Parse products
      List<Product> products = [];
      for (var json in results) {
        try {
          // Convert SQLite bool (stored as int) back to bool for Product class
          final bool popularProduct = (json['popular_product'] as int?) == 1;

          // Parse the updated_at field
          DateTime? updatedAt;
          if (json['updated_at'] != null) {
            try {
              updatedAt = DateTime.parse(json['updated_at'] as String);
            } catch (e) {
              developer.log('Error parsing updated_at: $e');
              updatedAt = null;
            }
          }

          final product = Product(
            id: json['id'] as int,
            createdAt:
                json['created_at'] != null
                    ? DateTime.parse(json['created_at'] as String)
                    : DateTime(2023, 1, 1),
            updatedAt: updatedAt,
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

  // Add method to update a product in the database
  Future<bool> updateProduct(Product product) async {
    if (!await isSqliteAvailable()) {
      throw SqliteNotAvailableException(
        'SQLite library is not available. Please install SQLite development libraries.',
      );
    }

    try {
      final db = await database;

      // Convert bool to int for SQLite
      final popularProductInt = product.popularProduct ? 1 : 0;

      // Update the record in the database
      final rowsAffected = await db.update(
        'all_products',
        {
          'name': product.name,
          'uprices': product.uPrices,
          'image': product.image,
          'discount': product.discount,
          'description': product.description,
          'category_1': product.category1,
          'category_2': product.category2,
          'popular_product': popularProductInt,
          'matching_words': product.matchingWords,
          'updated_at': product.updatedAt?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [product.id],
      );

      developer.log(
        'Updated product #${product.id}: ${rowsAffected} rows affected',
      );
      return rowsAffected > 0;
    } catch (e) {
      developer.log('Error updating product: $e');
      return false;
    }
  }

  // Add method to delete a product in the database
  Future<bool> deleteProduct(int productId) async {
    if (!await isSqliteAvailable()) {
      throw SqliteNotAvailableException(
        'SQLite library is not available. Please install SQLite development libraries.',
      );
    }

    try {
      final db = await database;

      // Delete the record from the database
      final rowsAffected = await db.delete(
        'all_products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      developer.log('Deleted product #$productId: $rowsAffected rows affected');
      return rowsAffected > 0;
    } catch (e) {
      developer.log('Error deleting product: $e');
      return false;
    }
  }

  // Add method to insert a new product in the database
  Future<bool> insertProduct(Product product) async {
    if (!await isSqliteAvailable()) {
      throw SqliteNotAvailableException(
        'SQLite library is not available. Please install SQLite development libraries.',
      );
    }

    try {
      final db = await database;

      // Convert bool to int for SQLite
      final popularProductInt = product.popularProduct ? 1 : 0;

      // Insert the new product into the database
      final id = await db.insert('all_products', {
        'id': product.id,
        'created_at': product.createdAt.toIso8601String(),
        'updated_at': product.updatedAt?.toIso8601String(),
        'name': product.name,
        'uprices': product.uPrices,
        'image': product.image,
        'discount': product.discount,
        'description': product.description,
        'category_1': product.category1,
        'category_2': product.category2,
        'popular_product': popularProductInt,
        'matching_words': product.matchingWords,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      developer.log('Inserted new product with ID: $id');
      return id > 0;
    } catch (e) {
      developer.log('Error inserting product: $e');
      return false;
    }
  }

  // Ensure that the column visibility table exists
  Future<void> ensureColumnVisibilityTableExists() async {
    try {
      final db = await database;

      // Check if the table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='column_visibility'",
      );

      if (tables.isEmpty) {
        developer.log('Creating column_visibility table');
        await db.execute('''
        CREATE TABLE column_visibility(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          view_name TEXT NOT NULL,
          column_index INTEGER NOT NULL,
          is_visible INTEGER NOT NULL,
          UNIQUE(view_name, column_index)
        )
        ''');
        developer.log('Column visibility table created successfully');
      }
    } catch (e) {
      developer.log('Error creating column visibility table: $e');
    }
  }

  // Save column visibility settings to the database
  Future<void> saveColumnVisibility(
    String viewName,
    List<int> hiddenColumns,
  ) async {
    if (!await isSqliteAvailable()) {
      throw SqliteNotAvailableException(
        'SQLite library is not available. Please install SQLite development libraries.',
      );
    }

    try {
      // Ensure the table exists before attempting to use it
      await ensureColumnVisibilityTableExists();

      final db = await database;

      // Start a transaction for batch operations
      await db.transaction((txn) async {
        // Delete existing settings for this view
        await txn.delete(
          'column_visibility',
          where: 'view_name = ?',
          whereArgs: [viewName],
        );

        // Insert new settings for hidden columns
        for (int columnIndex in hiddenColumns) {
          await txn.insert('column_visibility', {
            'view_name': viewName,
            'column_index': columnIndex,
            'is_visible': 0, // 0 means hidden
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      developer.log(
        'Saved column visibility settings for $viewName: $hiddenColumns',
      );
    } catch (e) {
      developer.log('Error saving column visibility settings: $e');
      // Don't throw here to prevent UI crashes if saving fails
    }
  }

  // Load column visibility settings from the database
  Future<List<int>> loadColumnVisibility(String viewName) async {
    if (!await isSqliteAvailable()) {
      return [];
    }

    try {
      // Ensure the table exists before attempting to query it
      await ensureColumnVisibilityTableExists();

      final db = await database;

      // Query hidden columns
      final results = await db.query(
        'column_visibility',
        columns: ['column_index'],
        where: 'view_name = ? AND is_visible = 0',
        whereArgs: [viewName],
      );

      final List<int> hiddenColumns =
          results.map((row) => row['column_index'] as int).toList();
      developer.log(
        'Loaded column visibility settings for $viewName: $hiddenColumns',
      );

      return hiddenColumns;
    } catch (e) {
      developer.log('Error loading column visibility settings: $e');
      return [];
    }
  }
}
