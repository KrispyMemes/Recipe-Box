import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/recipe.dart';
import '../models/import_job.dart';
import '../models/weekly_planning.dart';

class RecipeRepository {
  RecipeRepository({required this.db});

  final Database db;

  static String weekStartDateFor(DateTime date) {
    final DateTime localDate = DateTime(date.year, date.month, date.day);
    final int daysFromMonday = localDate.weekday - DateTime.monday;
    final DateTime weekStart = localDate.subtract(
      Duration(days: daysFromMonday),
    );
    return weekStart.toIso8601String().split('T').first;
  }

  Future<RecipeLibraryData> loadLibrary({
    String searchQuery = '',
    String? tagId,
    String? collectionId,
  }) async {
    final List<Recipe> recipes = await listRecipes(
      searchQuery: searchQuery,
      tagId: tagId,
      collectionId: collectionId,
    );
    final List<RecipeTag> tags = await listTags();
    final List<RecipeCollection> collections = await listCollections();

    return RecipeLibraryData(
      recipes: recipes,
      tags: tags,
      collections: collections,
    );
  }

  Future<List<Recipe>> listRecipes({
    String searchQuery = '',
    String? tagId,
    String? collectionId,
  }) async {
    final StringBuffer sql = StringBuffer('''
      SELECT DISTINCT r.*
      FROM recipes r
    ''');
    final List<Object?> arguments = <Object?>[];
    final List<String> whereClauses = <String>[];

    if (tagId != null) {
      sql.write(' INNER JOIN recipe_tags rt ON rt.recipe_id = r.id ');
      whereClauses.add('rt.tag_id = ?');
      arguments.add(tagId);
    }

    if (collectionId != null) {
      sql.write(' INNER JOIN recipe_collections rc ON rc.recipe_id = r.id ');
      whereClauses.add('rc.collection_id = ?');
      arguments.add(collectionId);
    }

    final String trimmedQuery = searchQuery.trim();
    if (trimmedQuery.isNotEmpty) {
      whereClauses.add('''
        (
          r.title LIKE ? OR
          r.description LIKE ? OR
          r.ingredients LIKE ? OR
          r.directions LIKE ?
        )
      ''');
      arguments.add('%$trimmedQuery%');
      arguments.add('%$trimmedQuery%');
      arguments.add('%$trimmedQuery%');
      arguments.add('%$trimmedQuery%');
    }

    if (whereClauses.isNotEmpty) {
      sql.write(' WHERE ${whereClauses.join(' AND ')}');
    }

    sql.write(' ORDER BY r.updated_at DESC');

    final List<Map<String, Object?>> recipeRows = await db.rawQuery(
      sql.toString(),
      arguments,
    );

    final List<Recipe> recipes = <Recipe>[];
    for (final Map<String, Object?> row in recipeRows) {
      final String recipeId = row['id'] as String;
      final List<String> tagNames = await _loadTagNamesForRecipe(recipeId);
      final List<String> collectionNames = await _loadCollectionNamesForRecipe(
        recipeId,
      );
      recipes.add(_recipeFromRow(row, tagNames, collectionNames));
    }

    return recipes;
  }

  Future<Recipe?> getRecipeById(String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final List<String> tagNames = await _loadTagNamesForRecipe(id);
    final List<String> collectionNames = await _loadCollectionNamesForRecipe(
      id,
    );

    return _recipeFromRow(rows.first, tagNames, collectionNames);
  }

  Future<String> createRecipe(RecipeInput input) async {
    final String id = _newId();
    final DateTime now = DateTime.now().toUtc();

    await db.transaction((txn) async {
      await txn.insert('recipes', <String, Object?>{
        'id': id,
        'title': input.title.trim(),
        'description': _nullIfBlank(input.description),
        'ingredients': _nullIfBlank(input.ingredients),
        'directions': _nullIfBlank(input.directions),
        'source_url': _nullIfBlank(input.sourceUrl),
        'thumbnail_url': _nullIfBlank(input.thumbnailUrl),
        'thumbnail_path': _nullIfBlank(input.thumbnailPath),
        'servings': input.servings,
        'total_time_minutes': input.totalTimeMinutes,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await _saveRecipeTags(txn, recipeId: id, tagNames: input.tagNames);
      await _saveRecipeCollections(
        txn,
        recipeId: id,
        collectionNames: input.collectionNames,
      );
    });

    return id;
  }

  Future<void> updateRecipe(String recipeId, RecipeInput input) async {
    final DateTime now = DateTime.now().toUtc();

    await db.transaction((txn) async {
      final int rowsUpdated = await txn.update(
        'recipes',
        <String, Object?>{
          'title': input.title.trim(),
          'description': _nullIfBlank(input.description),
          'ingredients': _nullIfBlank(input.ingredients),
          'directions': _nullIfBlank(input.directions),
          'source_url': _nullIfBlank(input.sourceUrl),
          'thumbnail_url': _nullIfBlank(input.thumbnailUrl),
          'thumbnail_path': _nullIfBlank(input.thumbnailPath),
          'servings': input.servings,
          'total_time_minutes': input.totalTimeMinutes,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: <Object>[recipeId],
      );
      if (rowsUpdated == 0) {
        throw StateError('Recipe not found: $recipeId');
      }

      await txn.delete(
        'recipe_tags',
        where: 'recipe_id = ?',
        whereArgs: <Object>[recipeId],
      );
      await txn.delete(
        'recipe_collections',
        where: 'recipe_id = ?',
        whereArgs: <Object>[recipeId],
      );

      await _saveRecipeTags(txn, recipeId: recipeId, tagNames: input.tagNames);
      await _saveRecipeCollections(
        txn,
        recipeId: recipeId,
        collectionNames: input.collectionNames,
      );
    });
  }

  Future<void> deleteRecipe(String recipeId) async {
    await db.delete('recipes', where: 'id = ?', whereArgs: <Object>[recipeId]);
  }

  Future<String> createImportJob({
    required ImportJobType type,
    required String sourcePayload,
  }) async {
    final String id = _newId();
    final String now = DateTime.now().toUtc().toIso8601String();
    await db.insert('import_jobs', <String, Object?>{
      'id': id,
      'type': type.name,
      'status': ImportJobStatus.pending.name,
      'source_payload': sourcePayload,
      'result_payload': null,
      'error_message': null,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> completeImportJobSuccess({
    required String jobId,
    required RecipeInput recipeInput,
  }) async {
    await db.update(
      'import_jobs',
      <String, Object?>{
        'status': ImportJobStatus.succeeded.name,
        'result_payload': jsonEncode(_recipeInputToJson(recipeInput)),
        'error_message': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[jobId],
    );
  }

  Future<void> completeImportJobFailure({
    required String jobId,
    required String errorMessage,
  }) async {
    await db.update(
      'import_jobs',
      <String, Object?>{
        'status': ImportJobStatus.failed.name,
        'error_message': errorMessage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[jobId],
    );
  }

  Future<List<ImportJob>> listImportJobs({int limit = 100}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'import_jobs',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(_importJobFromRow).toList();
  }

  Future<Set<String>> getPinnedRecipeIdsForWeek({String? weekStartDate}) async {
    final String week = weekStartDate ?? weekStartDateFor(DateTime.now());
    final List<Map<String, Object?>> rows = await db.query(
      'weekly_pins',
      columns: <String>['recipe_id'],
      where: 'week_start_date = ?',
      whereArgs: <Object>[week],
    );
    return rows.map((row) => row['recipe_id'] as String).toSet();
  }

  Future<void> setRecipePinnedForWeek({
    required String recipeId,
    required bool pinned,
    String? weekStartDate,
  }) async {
    final String week = weekStartDate ?? weekStartDateFor(DateTime.now());

    if (pinned) {
      final List<Map<String, Object?>> existing = await db.query(
        'weekly_pins',
        columns: <String>['id'],
        where: 'recipe_id = ? AND week_start_date = ?',
        whereArgs: <Object>[recipeId, week],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return;
      }

      await db.insert('weekly_pins', <String, Object?>{
        'id': _newId(),
        'recipe_id': recipeId,
        'week_start_date': week,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await regenerateShoppingListFromPinnedRecipes(weekStartDate: week);
      return;
    }

    await db.delete(
      'weekly_pins',
      where: 'recipe_id = ? AND week_start_date = ?',
      whereArgs: <Object>[recipeId, week],
    );
    await regenerateShoppingListFromPinnedRecipes(weekStartDate: week);
  }

  Future<List<Recipe>> listPinnedRecipesForWeek({String? weekStartDate}) async {
    final String week = weekStartDate ?? weekStartDateFor(DateTime.now());
    final List<Map<String, Object?>> recipeRows = await db.rawQuery(
      '''
      SELECT r.*
      FROM recipes r
      INNER JOIN weekly_pins wp ON wp.recipe_id = r.id
      WHERE wp.week_start_date = ?
      ORDER BY wp.created_at ASC
      ''',
      <Object>[week],
    );

    final List<Recipe> recipes = <Recipe>[];
    for (final Map<String, Object?> row in recipeRows) {
      final String recipeId = row['id'] as String;
      final List<String> tagNames = await _loadTagNamesForRecipe(recipeId);
      final List<String> collectionNames = await _loadCollectionNamesForRecipe(
        recipeId,
      );
      recipes.add(_recipeFromRow(row, tagNames, collectionNames));
    }
    return recipes;
  }

  Future<List<ShoppingListItemModel>> listShoppingItemsForWeek({
    String? weekStartDate,
  }) async {
    final String week = weekStartDate ?? weekStartDateFor(DateTime.now());
    final List<Map<String, Object?>> rows = await db.query(
      'shopping_list_items',
      where: 'week_start_date = ?',
      whereArgs: <Object>[week],
      orderBy: 'checked ASC, item_name COLLATE NOCASE ASC',
    );

    return rows.map((row) {
      final String sourceRecipeIdsRaw =
          (row['source_recipe_ids'] as String?)?.trim() ?? '';
      return ShoppingListItemModel(
        id: row['id'] as String,
        weekStartDate: row['week_start_date'] as String,
        itemName: row['item_name'] as String,
        quantityText: row['quantity_text'] as String?,
        checked: (row['checked'] as int) == 1,
        sourceRecipeIds: sourceRecipeIdsRaw.isEmpty
            ? const <String>[]
            : sourceRecipeIdsRaw.split(','),
      );
    }).toList();
  }

  Future<void> addCustomShoppingItem({
    required String itemName,
    String? weekStartDate,
  }) async {
    final String trimmedName = itemName.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final String week = weekStartDate ?? weekStartDateFor(DateTime.now());
    final String now = DateTime.now().toUtc().toIso8601String();
    await db.insert('shopping_list_items', <String, Object?>{
      'id': _newId(),
      'week_start_date': week,
      'item_name': trimmedName,
      'quantity_text': null,
      'checked': 0,
      'source_recipe_ids': null,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> toggleShoppingItemChecked({
    required String itemId,
    required bool checked,
  }) async {
    await db.update(
      'shopping_list_items',
      <String, Object?>{
        'checked': checked ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[itemId],
    );
  }

  Future<void> deleteShoppingItem(String itemId) async {
    await db.delete(
      'shopping_list_items',
      where: 'id = ?',
      whereArgs: <Object>[itemId],
    );
  }

  Future<void> markShoppingItemPurchased(String itemId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'shopping_list_items',
      columns: const <String>['id', 'week_start_date', 'item_name'],
      where: 'id = ?',
      whereArgs: <Object>[itemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final Map<String, Object?> row = rows.first;
    final String week = row['week_start_date'] as String;
    final String itemName = row['item_name'] as String;
    final String normalized = _normalizeShoppingItemName(itemName);
    final String now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      if (normalized.isNotEmpty) {
        await txn.insert('shopping_item_exclusions', <String, Object?>{
          'id': _newId(),
          'week_start_date': week,
          'normalized_item_name': normalized,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.delete(
        'shopping_list_items',
        where: 'id = ?',
        whereArgs: <Object>[itemId],
      );
    });
  }

  Future<void> regenerateShoppingListFromPinnedRecipes({
    String? weekStartDate,
  }) async {
    final String week = weekStartDate ?? weekStartDateFor(DateTime.now());
    final List<Recipe> pinnedRecipes = await listPinnedRecipesForWeek(
      weekStartDate: week,
    );
    final Set<String> exclusions = await _loadShoppingItemExclusionsForWeek(
      week,
    );

    final Map<String, _IngredientAggregate> byNormalizedIngredient =
        <String, _IngredientAggregate>{};

    for (final Recipe recipe in pinnedRecipes) {
      final String ingredientsText = recipe.ingredients ?? '';
      for (final String rawLine in ingredientsText.split('\n')) {
        final String cleaned = _cleanIngredientLine(rawLine);
        if (cleaned.isEmpty) {
          continue;
        }
        final String normalized = _normalizeShoppingItemName(cleaned);
        if (normalized.isEmpty || exclusions.contains(normalized)) {
          continue;
        }
        byNormalizedIngredient.putIfAbsent(
          normalized,
          () => _IngredientAggregate(itemName: cleaned),
        );
        byNormalizedIngredient[normalized]!.sourceRecipeIds.add(recipe.id);
      }
    }

    await db.transaction((txn) async {
      await txn.delete(
        'shopping_list_items',
        where: 'week_start_date = ? AND source_recipe_ids IS NOT NULL',
        whereArgs: <Object>[week],
      );

      final List<String> keys = byNormalizedIngredient.keys.toList()
        ..sort((a, b) => a.compareTo(b));

      final String now = DateTime.now().toUtc().toIso8601String();
      for (final String key in keys) {
        final _IngredientAggregate aggregate = byNormalizedIngredient[key]!;
        final List<String> sortedRecipeIds = aggregate.sourceRecipeIds.toList()
          ..sort();
        await txn.insert('shopping_list_items', <String, Object?>{
          'id': _newId(),
          'week_start_date': week,
          'item_name': aggregate.itemName,
          'quantity_text': null,
          'checked': 0,
          'source_recipe_ids': sortedRecipeIds.join(','),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<Set<String>> _loadShoppingItemExclusionsForWeek(String week) async {
    final List<Map<String, Object?>> rows = await db.query(
      'shopping_item_exclusions',
      columns: const <String>['normalized_item_name'],
      where: 'week_start_date = ?',
      whereArgs: <Object>[week],
    );
    return rows
        .map(
          (row) => (row['normalized_item_name'] as String).trim().toLowerCase(),
        )
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<List<RecipeTag>> listTags() async {
    final List<Map<String, Object?>> rows = await db.query(
      'tags',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (row) =>
              RecipeTag(id: row['id'] as String, name: row['name'] as String),
        )
        .toList();
  }

  Future<List<RecipeCollection>> listCollections() async {
    final List<Map<String, Object?>> rows = await db.query(
      'collections',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (row) => RecipeCollection(
            id: row['id'] as String,
            name: row['name'] as String,
          ),
        )
        .toList();
  }

  Future<void> _saveRecipeTags(
    Transaction txn, {
    required String recipeId,
    required List<String> tagNames,
  }) async {
    final List<String> normalizedNames = _normalizeNames(tagNames);
    for (final String name in normalizedNames) {
      final String tagId = await _ensureTag(txn, name);
      await txn.insert('recipe_tags', <String, Object?>{
        'recipe_id': recipeId,
        'tag_id': tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _saveRecipeCollections(
    Transaction txn, {
    required String recipeId,
    required List<String> collectionNames,
  }) async {
    final List<String> normalizedNames = _normalizeNames(collectionNames);
    for (final String name in normalizedNames) {
      final String collectionId = await _ensureCollection(txn, name);
      await txn.insert('recipe_collections', <String, Object?>{
        'recipe_id': recipeId,
        'collection_id': collectionId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<String> _ensureTag(Transaction txn, String name) async {
    final List<Map<String, Object?>> existing = await txn.query(
      'tags',
      columns: <String>['id'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: <Object>[name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }

    final String id = _newId();
    final String now = DateTime.now().toUtc().toIso8601String();
    await txn.insert('tags', <String, Object?>{
      'id': id,
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<String> _ensureCollection(Transaction txn, String name) async {
    final List<Map<String, Object?>> existing = await txn.query(
      'collections',
      columns: <String>['id'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: <Object>[name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }

    final String id = _newId();
    final String now = DateTime.now().toUtc().toIso8601String();
    await txn.insert('collections', <String, Object?>{
      'id': id,
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<String>> _loadTagNamesForRecipe(String recipeId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT t.name
      FROM tags t
      INNER JOIN recipe_tags rt ON rt.tag_id = t.id
      WHERE rt.recipe_id = ?
      ORDER BY t.name COLLATE NOCASE ASC
      ''',
      <Object>[recipeId],
    );

    return rows.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> _loadCollectionNamesForRecipe(String recipeId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT c.name
      FROM collections c
      INNER JOIN recipe_collections rc ON rc.collection_id = c.id
      WHERE rc.recipe_id = ?
      ORDER BY c.name COLLATE NOCASE ASC
      ''',
      <Object>[recipeId],
    );

    return rows.map((row) => row['name'] as String).toList();
  }

  Recipe _recipeFromRow(
    Map<String, Object?> row,
    List<String> tagNames,
    List<String> collectionNames,
  ) {
    return Recipe(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      ingredients: row['ingredients'] as String?,
      directions: row['directions'] as String?,
      sourceUrl: row['source_url'] as String?,
      thumbnailUrl: row['thumbnail_url'] as String?,
      thumbnailPath: row['thumbnail_path'] as String?,
      servings: row['servings'] as int?,
      totalTimeMinutes: row['total_time_minutes'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      tagNames: tagNames,
      collectionNames: collectionNames,
    );
  }

  List<String> _normalizeNames(List<String> values) {
    final Map<String, String> unique = <String, String>{};
    for (final String raw in values) {
      final String value = raw.trim();
      if (value.isEmpty) {
        continue;
      }
      unique[value.toLowerCase()] = value;
    }

    final List<String> result = unique.values.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  String _newId() {
    final int now = DateTime.now().microsecondsSinceEpoch;
    final int randomValue = _random.nextInt(1 << 32);
    return '${now.toRadixString(16)}${randomValue.toRadixString(16)}';
  }

  String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _cleanIngredientLine(String rawLine) {
    String line = rawLine.trim();
    if (line.isEmpty) {
      return '';
    }

    line = line.replaceFirst(RegExp(r'^[-*•\s]+'), '');
    line = line.replaceFirst(RegExp(r'[\(\[\{].*$'), '');
    line = line.replaceAll(RegExp(r'\s+'), ' ');
    return line.trim();
  }

  String _normalizeShoppingItemName(String raw) {
    final String trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  ImportJob _importJobFromRow(Map<String, Object?> row) {
    RecipeInput? recipeInput;
    final String? resultPayload = row['result_payload'] as String?;
    if (resultPayload != null && resultPayload.trim().isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            (jsonDecode(resultPayload) as Map<dynamic, dynamic>).map(
              (key, value) => MapEntry(key.toString(), value),
            );
        recipeInput = _recipeInputFromJson(decoded);
      } catch (_) {
        recipeInput = null;
      }
    }

    return ImportJob(
      id: row['id'] as String,
      type: ImportJobType.values.firstWhere(
        (value) => value.name == row['type'],
        orElse: () => ImportJobType.url,
      ),
      status: ImportJobStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => ImportJobStatus.pending,
      ),
      sourcePayload: row['source_payload'] as String,
      resultRecipeInput: recipeInput,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, Object?> _recipeInputToJson(RecipeInput input) {
    return <String, Object?>{
      'title': input.title,
      'description': input.description,
      'ingredients': input.ingredients,
      'directions': input.directions,
      'sourceUrl': input.sourceUrl,
      'thumbnailUrl': input.thumbnailUrl,
      'thumbnailPath': input.thumbnailPath,
      'servings': input.servings,
      'totalTimeMinutes': input.totalTimeMinutes,
      'tagNames': input.tagNames,
      'collectionNames': input.collectionNames,
    };
  }

  RecipeInput _recipeInputFromJson(Map<String, dynamic> json) {
    return RecipeInput(
      title: (json['title'] as String?) ?? 'Imported Recipe',
      description: json['description'] as String?,
      ingredients: json['ingredients'] as String?,
      directions: json['directions'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      servings: json['servings'] as int?,
      totalTimeMinutes: json['totalTimeMinutes'] as int?,
      tagNames: ((json['tagNames'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(),
      collectionNames: ((json['collectionNames'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(),
    );
  }

  static final Random _random = Random();
}

class _IngredientAggregate {
  _IngredientAggregate({required this.itemName});

  final String itemName;
  final Set<String> sourceRecipeIds = <String>{};
}
