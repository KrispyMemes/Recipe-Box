import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int schemaVersion = 6;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDatabase();
    return _db!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory supportDir = await getApplicationSupportDirectory();
    final String dbPath = p.join(supportDir.path, 'recipe_app.sqlite');

    return openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await migrate(db, oldVersion, newVersion);
      },
    );
  }

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        ingredients TEXT,
        directions TEXT,
        source_url TEXT,
        thumbnail_url TEXT,
        thumbnail_path TEXT,
        servings INTEGER,
        total_time_minutes INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE weekly_pins (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        week_start_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE shopping_list_items (
        id TEXT PRIMARY KEY,
        week_start_date TEXT NOT NULL,
        item_name TEXT NOT NULL,
        quantity_text TEXT,
        checked INTEGER NOT NULL DEFAULT 0,
        source_recipe_ids TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await _createShoppingItemExclusionsTable(db);

    await _createImportJobsTable(db);
    await _createRecipeOrganizationTables(db);
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createRecipeOrganizationTables(db);
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE recipes ADD COLUMN ingredients TEXT;');
      await db.execute('ALTER TABLE recipes ADD COLUMN directions TEXT;');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE recipes ADD COLUMN thumbnail_path TEXT;');
    }

    if (oldVersion < 5) {
      await _createImportJobsTable(db);
    }

    if (oldVersion < 6) {
      await _createShoppingItemExclusionsTable(db);
    }
  }

  static Future<void> _createRecipeOrganizationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_tags (
        recipe_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (recipe_id, tag_id),
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_collections (
        recipe_id TEXT NOT NULL,
        collection_id TEXT NOT NULL,
        PRIMARY KEY (recipe_id, collection_id),
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY(collection_id) REFERENCES collections(id) ON DELETE CASCADE
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recipe_tags_tag_id ON recipe_tags(tag_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recipe_collections_collection_id ON recipe_collections(collection_id);',
    );
  }

  static Future<void> _createImportJobsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_jobs (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        source_payload TEXT NOT NULL,
        result_payload TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_import_jobs_created_at ON import_jobs(created_at DESC);',
    );
  }

  static Future<void> _createShoppingItemExclusionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_item_exclusions (
        id TEXT PRIMARY KEY,
        week_start_date TEXT NOT NULL,
        normalized_item_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_shopping_item_exclusions_week_item
      ON shopping_item_exclusions(week_start_date, normalized_item_name);
    ''');
  }
}
