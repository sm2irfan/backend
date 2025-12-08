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

        // On Linux, check if SQLite is installed
        if (Platform.isLinux) {
          try {
            // Test if we can open a database
            final dbTest = await databaseFactory.openDatabase(':memory:');
            await dbTest.close();
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

        return true;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, SQLite is natively supported
        _sqliteAvailable = true;
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

      // Log the database file path
      developer.log('Database path: $dbPath');

      return await openDatabase(
        dbPath,
        version: 4, // Increment version for migration to add config table
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
            matching_words TEXT,
            production INTEGER DEFAULT 0
          )
          ''');

          // Create config table for app configuration
          await db.execute('''
          CREATE TABLE config(
            key TEXT PRIMARY KEY,
            value TEXT
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
          // Handle upgrades
          if (oldVersion < 3) {
            // Check if production column exists, add if not
            var columns = await db.rawQuery('PRAGMA table_info(all_products)');
            var columnNames = columns.map((c) => c['name'] as String).toList();

            if (!columnNames.contains('production')) {
              await db.execute(
                'ALTER TABLE all_products ADD COLUMN production INTEGER DEFAULT 0',
              );
              developer.log('Added production column to all_products table');
            }
          }

          if (oldVersion < 4) {
            // Add config table if upgrading from version < 4
            try {
              await db.execute('''
              CREATE TABLE IF NOT EXISTS config(
                key TEXT PRIMARY KEY,
                value TEXT
              )
              ''');
              developer.log('Added config table to database');
            } catch (e) {
              developer.log('Error adding config table: $e');
            }
          }
        },
      );
    } catch (e) {
      developer.log('Error initializing database: $e');
      _sqliteAvailable = false;
      throw SqliteNotAvailableException('Failed to initialize SQLite: $e');
    }
  }

  // Get a configuration value from the config table
  Future<String?> getConfigValue(String key) async {
    if (!await isSqliteAvailable()) {
      return null;
    }

    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        'config',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result.isNotEmpty) {
        return result.first['value'] as String?;
      }
      return null;
    } catch (e) {
      developer.log('Error getting config value: $e');
      return null;
    }
  }

  // Set a configuration value in the config table
  Future<bool> setConfigValue(String key, String value) async {
    if (!await isSqliteAvailable()) {
      return false;
    }

    try {
      final db = await database;
      await db.insert('config', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    } catch (e) {
      developer.log('Error setting config value: $e');
      return false;
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
  Future<Map<String, dynamic>> syncProductsFromSupabase({
    bool initialSync = false,
  }) async {
    if (!await isSqliteAvailable()) {
      return simulateSyncOperation();
    }

    try {
      final db = await database;

      // Get the last sync time from config
      String? lastSyncTime = await getConfigValue('last_sync_pre_all_products');
      developer.log('Last sync time: ${lastSyncTime ?? "Never"}');

      // Store sync timestamp outside of transaction
      final now = DateTime.now().toUtc().toIso8601String();
      String message = '';
      int count = 0;

      // Begin transaction
      await db.transaction((txn) async {
        // Determine if this is first sync or incremental sync
        bool isFirstSync = lastSyncTime == null || lastSyncTime.isEmpty;

        // Build the appropriate query based on sync type
        List<Map<String, dynamic>> response;

        if (isFirstSync) {
          if (initialSync) {
            // First sync - clear existing data and fetch all records
            developer.log('Performing full initial sync');
            await txn.execute('DELETE FROM all_products');

            // Fetch all records without any filters
            response = await _supabaseClient.from('pre_all_products').select();
          } else {
            // First sync but we want to limit the number of records
            // Get most recent records (last 50)
            developer.log(
              'Performing limited initial sync (most recent 50 records)',
            );
            response = await _supabaseClient
                .from('pre_all_products')
                .select()
                .order('created_at', ascending: false)
                .limit(50);
          }
        } else {
          // Incremental sync - only get records updated since last sync
          developer.log('Syncing only records updated since: $lastSyncTime');
          response = await _supabaseClient
              .from('pre_all_products')
              .select()
              .gte('updated_at', lastSyncTime);
        }

        developer.log('Got ${response.length} records from Supabase');

        // Insert or update each product into SQLite
        int successCount = 0;
        int failCount = 0;

        for (var item in response) {
          try {
            print(
              'LocalDatabase - Syncing product ID: ${item['id']}, uprices: ${item['uprices']}',
            );

            // Convert bool to int for SQLite
            final popularProductInt = item['popular_product'] == true ? 1 : 0;
            final productionInt = item['production'] == true ? 1 : 0;

            // Validate and clean uprices
            String upricesValue;
            if (item['uprices'] == null) {
              upricesValue = '[]';
              print(
                'LocalDatabase - uprices is null for product ${item['id']}, using []',
              );
            } else if (item['uprices'].toString().isEmpty) {
              upricesValue = '[]';
              print(
                'LocalDatabase - uprices is empty for product ${item['id']}, using []',
              );
            } else {
              upricesValue = item['uprices'].toString();
              print(
                'LocalDatabase - uprices for product ${item['id']}: $upricesValue',
              );
            }

            // Use insert with REPLACE conflict strategy
            await txn.insert('all_products', {
              'id': item['id'],
              'created_at':
                  item['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at':
                  item['updated_at'] ?? DateTime.now().toIso8601String(),
              'name': item['name'] ?? 'Unnamed Product',
              'uprices': upricesValue,
              'image': item['image'],
              'discount': item['discount'],
              'description': item['description'],
              'category_1': item['category_1'],
              'category_2': item['category_2'],
              'popular_product': popularProductInt,
              'matching_words': item['matching_words'],
              'production': productionInt,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            successCount++;
          } catch (e) {
            developer.log('Error inserting/updating product: $e');
            failCount++;
          }
        }

        // Update the config table directly using the transaction object
        await txn.insert('config', {
          'key': 'last_sync_pre_all_products',
          'value': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        message =
            'Synced ${response.length} records (S:$successCount, F:$failCount)';
        developer.log('Updated last sync time to: $now');
      });

      // Get count of records after sync
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM all_products',
      );
      count = Sqflite.firstIntValue(countResult) ?? 0;

      developer.log('Sync completed: $count total records in database');

      return {
        'success': true,
        'message': message,
        'count': count,
        'totalCount': count, // Total count in database
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
                }
              } else {
                // Single word search - existing behavior
                conditions.add('name LIKE ?');
                queryArgs.add('%$searchTerm%');
              }
            } else {
              // Standard exact match
              conditions.add('name = ?');
              queryArgs.add(nameFilter);
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
            } else {
              // Use LIKE query for category1 regardless (for partial matching)
              conditions.add('category_1 LIKE ?');
              queryArgs.add('%$categoryFilter%');
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
          final bool production =
              (json['production'] as int?) ==
              1; // Convert production int to boolean

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
            production: production, // Add production field
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
      final productionInt =
          product.production ? 1 : 0; // Convert production boolean to int

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
          'production': productionInt, // Add production field
        },
        where: 'id = ?',
        whereArgs: [product.id],
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
      final productionInt =
          product.production ? 1 : 0; // Convert production boolean to int

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
        'production': productionInt, // Add production field
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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
        await db.execute('''
        CREATE TABLE column_visibility(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          view_name TEXT NOT NULL,
          column_index INTEGER NOT NULL,
          is_visible INTEGER NOT NULL,
          UNIQUE(view_name, column_index)
        )
        ''');
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

      return hiddenColumns;
    } catch (e) {
      developer.log('Error loading column visibility settings: $e');
      return [];
    }
  }

  // Ensure that the column dimensions tables exist
  Future<void> ensureColumnDimensionsTablesExist() async {
    try {
      final db = await database;

      // Check if the column width table exists
      final widthTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='column_widths'",
      );

      if (widthTables.isEmpty) {
        await db.execute('''
        CREATE TABLE column_widths(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          view_name TEXT NOT NULL,
          column_index INTEGER NOT NULL,
          width REAL NOT NULL,
          UNIQUE(view_name, column_index)
        )
        ''');
      }

      // Check if the row height table exists
      final heightTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='row_heights'",
      );

      if (heightTables.isEmpty) {
        await db.execute('''
        CREATE TABLE row_heights(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          view_name TEXT NOT NULL,
          height REAL NOT NULL,
          UNIQUE(view_name)
        )
        ''');
      }
    } catch (e) {
      developer.log('Error creating column dimensions tables: $e');
    }
  }

  // Save column widths to the database
  Future<void> saveColumnWidths(
    String viewName,
    Map<int, double> columnWidths,
  ) async {
    if (!await isSqliteAvailable()) {
      return;
    }

    try {
      // Ensure the table exists
      await ensureColumnDimensionsTablesExist();

      final db = await database;

      // Start a transaction for batch operations
      await db.transaction((txn) async {
        // Delete existing settings for this view
        await txn.delete(
          'column_widths',
          where: 'view_name = ?',
          whereArgs: [viewName],
        );

        // Insert new width values
        columnWidths.forEach((columnIndex, width) async {
          await txn.insert('column_widths', {
            'view_name': viewName,
            'column_index': columnIndex,
            'width': width,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
      });
    } catch (e) {
      developer.log('Error saving column widths: $e');
    }
  }

  // Load column widths from the database
  Future<Map<int, double>> loadColumnWidths(String viewName) async {
    if (!await isSqliteAvailable()) {
      return {};
    }

    try {
      // Ensure the table exists
      await ensureColumnDimensionsTablesExist();

      final db = await database;

      // Query saved column widths
      final results = await db.query(
        'column_widths',
        columns: ['column_index', 'width'],
        where: 'view_name = ?',
        whereArgs: [viewName],
      );

      final Map<int, double> columnWidths = {};
      for (var row in results) {
        columnWidths[row['column_index'] as int] = row['width'] as double;
      }

      return columnWidths;
    } catch (e) {
      developer.log('Error loading column widths: $e');
      return {};
    }
  }

  // Save row height to the database
  Future<void> saveRowHeight(String viewName, double height) async {
    if (!await isSqliteAvailable()) {
      return;
    }

    try {
      // Ensure the table exists
      await ensureColumnDimensionsTablesExist();

      final db = await database;

      // Insert or replace row height
      await db.insert('row_heights', {
        'view_name': viewName,
        'height': height,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      developer.log('Error saving row height: $e');
    }
  }

  // Load row height from the database
  Future<double?> loadRowHeight(String viewName) async {
    if (!await isSqliteAvailable()) {
      return null;
    }

    try {
      // Ensure the table exists
      await ensureColumnDimensionsTablesExist();

      final db = await database;

      // Query saved row height
      final results = await db.query(
        'row_heights',
        columns: ['height'],
        where: 'view_name = ?',
        whereArgs: [viewName],
      );

      if (results.isNotEmpty) {
        final height = results.first['height'] as double;
        return height;
      }
      return null;
    } catch (e) {
      developer.log('Error loading row height: $e');
      return null;
    }
  }
}
