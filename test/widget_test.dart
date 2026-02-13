import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:recipe_app/data/app_database.dart';
import 'package:recipe_app/data/recipe_repository.dart';
import 'package:recipe_app/main.dart';

void main() {
  late Database db;
  late RecipeRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (Database db, int version) async {
          await AppDatabase.createSchema(db);
        },
      ),
    );

    repository = RecipeRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('shows primary navigation labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(recipeRepository: repository)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recipe Box'), findsAtLeastNWidgets(1));
    expect(find.text('This Week'), findsAtLeastNWidgets(1));
    expect(find.text('Shopping'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('recipe_box_add_fab')), findsOneWidget);
  });
}
