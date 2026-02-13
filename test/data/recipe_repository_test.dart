import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:recipe_app/data/app_database.dart';
import 'package:recipe_app/data/recipe_repository.dart';
import 'package:recipe_app/models/import_job.dart';
import 'package:recipe_app/models/recipe.dart';
import 'package:recipe_app/models/weekly_planning.dart';

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
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          await AppDatabase.migrate(db, oldVersion, newVersion);
        },
      ),
    );

    repository = RecipeRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create and read recipe with tags and collections', () async {
    final String id = await repository.createRecipe(
      RecipeInput(
        title: 'Pesto Pasta',
        description: 'Easy weeknight dinner',
        ingredients: '12 oz pasta\n2 cups pesto',
        directions: '1. Boil pasta\n2. Toss with pesto',
        sourceUrl: 'https://example.com/pesto',
        thumbnailUrl: 'https://example.com/pesto.jpg',
        thumbnailPath: '/tmp/pesto.jpg',
        servings: 4,
        totalTimeMinutes: 30,
        tagNames: const <String>['Dinner', 'Pasta'],
        collectionNames: const <String>['Weeknight'],
      ),
    );

    final Recipe? recipe = await repository.getRecipeById(id);

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Pesto Pasta');
    expect(recipe.ingredients, contains('12 oz pasta'));
    expect(recipe.directions, contains('Boil pasta'));
    expect(recipe.thumbnailUrl, 'https://example.com/pesto.jpg');
    expect(recipe.thumbnailPath, '/tmp/pesto.jpg');
    expect(recipe.tagNames, containsAll(<String>['Dinner', 'Pasta']));
    expect(recipe.collectionNames, contains('Weeknight'));
  });

  test('update recipe replaces tags and collections', () async {
    final String id = await repository.createRecipe(
      RecipeInput(
        title: 'Chili',
        tagNames: const <String>['Dinner', 'Spicy'],
        collectionNames: const <String>['Cold Weather'],
      ),
    );

    await repository.updateRecipe(
      id,
      RecipeInput(
        title: 'Vegetarian Chili',
        tagNames: const <String>['dinner', 'Vegetarian'],
        collectionNames: const <String>['Meal Prep'],
      ),
    );

    final Recipe updated = (await repository.getRecipeById(id))!;
    final List<RecipeTag> tags = await repository.listTags();

    expect(updated.title, 'Vegetarian Chili');
    expect(updated.tagNames, containsAll(<String>['Dinner', 'Vegetarian']));
    expect(updated.tagNames, isNot(contains('Spicy')));
    expect(updated.collectionNames, equals(const <String>['Meal Prep']));
    expect(tags.where((tag) => tag.name.toLowerCase() == 'dinner').length, 1);
  });

  test('listRecipes supports search, tag, and collection filters', () async {
    await repository.createRecipe(
      RecipeInput(
        title: 'Chicken Tacos',
        description: 'Fast tacos',
        ingredients: 'Chicken\nTortillas',
        tagNames: const <String>['Dinner'],
        collectionNames: const <String>['Weeknight'],
      ),
    );
    await repository.createRecipe(
      RecipeInput(
        title: 'Blueberry Muffins',
        description: 'Sweet breakfast',
        directions: 'Mix batter and bake',
        tagNames: const <String>['Breakfast'],
        collectionNames: const <String>['Baking'],
      ),
    );

    final List<RecipeTag> tags = await repository.listTags();
    final List<RecipeCollection> collections = await repository
        .listCollections();
    final String dinnerTagId = tags
        .firstWhere((tag) => tag.name == 'Dinner')
        .id;
    final String bakingCollectionId = collections
        .firstWhere((collection) => collection.name == 'Baking')
        .id;

    final List<Recipe> searchResults = await repository.listRecipes(
      searchQuery: 'muffin',
    );
    final List<Recipe> ingredientSearchResults = await repository.listRecipes(
      searchQuery: 'tortillas',
    );
    final List<Recipe> dinnerResults = await repository.listRecipes(
      tagId: dinnerTagId,
    );
    final List<Recipe> bakingResults = await repository.listRecipes(
      collectionId: bakingCollectionId,
    );

    expect(
      searchResults.map((recipe) => recipe.title),
      contains('Blueberry Muffins'),
    );
    expect(
      searchResults.map((recipe) => recipe.title),
      isNot(contains('Chicken Tacos')),
    );
    expect(
      dinnerResults.map((recipe) => recipe.title),
      equals(const <String>['Chicken Tacos']),
    );
    expect(
      bakingResults.map((recipe) => recipe.title),
      equals(const <String>['Blueberry Muffins']),
    );
    expect(
      ingredientSearchResults.map((recipe) => recipe.title),
      equals(const <String>['Chicken Tacos']),
    );
  });

  test('deleteRecipe removes recipe', () async {
    final String id = await repository.createRecipe(
      RecipeInput(title: 'Test Recipe'),
    );

    await repository.deleteRecipe(id);

    expect(await repository.getRecipeById(id), isNull);
    expect(await repository.listRecipes(), isEmpty);
  });

  test('weekly pinning tracks pinned recipe ids and list', () async {
    final String pastaId = await repository.createRecipe(
      RecipeInput(title: 'Pasta'),
    );
    final String soupId = await repository.createRecipe(
      RecipeInput(title: 'Soup'),
    );
    final String week = RecipeRepository.weekStartDateFor(DateTime.now());

    await repository.setRecipePinnedForWeek(
      recipeId: pastaId,
      pinned: true,
      weekStartDate: week,
    );
    await repository.setRecipePinnedForWeek(
      recipeId: soupId,
      pinned: true,
      weekStartDate: week,
    );

    final Set<String> pinnedIds = await repository.getPinnedRecipeIdsForWeek(
      weekStartDate: week,
    );
    final List<Recipe> pinnedRecipes = await repository
        .listPinnedRecipesForWeek(weekStartDate: week);

    expect(pinnedIds, containsAll(<String>{pastaId, soupId}));
    expect(
      pinnedRecipes.map((recipe) => recipe.title),
      containsAll(<String>['Pasta', 'Soup']),
    );

    await repository.setRecipePinnedForWeek(
      recipeId: soupId,
      pinned: false,
      weekStartDate: week,
    );
    final Set<String> afterUnpin = await repository.getPinnedRecipeIdsForWeek(
      weekStartDate: week,
    );
    expect(afterUnpin, equals(<String>{pastaId}));
  });

  test(
    'shopping regeneration preserves custom items and aggregates pinned ingredients',
    () async {
      final String tacoId = await repository.createRecipe(
        RecipeInput(
          title: 'Tacos',
          ingredients:
              '1 lb ground beef\n8 tortillas\n1 cup salsa (mild)\nbeans [low sodium]\noil (for sauteing (optional))',
        ),
      );
      final String burritoId = await repository.createRecipe(
        RecipeInput(title: 'Burritos', ingredients: '8 tortillas\n2 cups rice'),
      );
      final String week = RecipeRepository.weekStartDateFor(DateTime.now());

      await repository.setRecipePinnedForWeek(
        recipeId: tacoId,
        pinned: true,
        weekStartDate: week,
      );
      await repository.setRecipePinnedForWeek(
        recipeId: burritoId,
        pinned: true,
        weekStartDate: week,
      );

      await repository.addCustomShoppingItem(
        itemName: 'Coffee',
        weekStartDate: week,
      );
      await repository.regenerateShoppingListFromPinnedRecipes(
        weekStartDate: week,
      );

      final List<ShoppingListItemModel> items = await repository
          .listShoppingItemsForWeek(weekStartDate: week);

      expect(
        items.any((item) => item.itemName == 'Coffee' && item.isCustom),
        isTrue,
      );
      expect(
        items
            .where((item) => item.itemName.toLowerCase() == '8 tortillas')
            .length,
        1,
      );

      final ShoppingListItemModel tortillas = items.firstWhere(
        (item) => item.itemName.toLowerCase() == '8 tortillas',
      );
      expect(tortillas.sourceRecipeIds.length, 2);
      expect(
        items.any((item) => item.itemName.toLowerCase().startsWith('1 lb')),
        isTrue,
      );
      expect(
        items.any((item) => item.itemName.toLowerCase() == '1 cup salsa'),
        isTrue,
      );
      expect(
        items.any((item) => item.itemName.toLowerCase() == 'beans'),
        isTrue,
      );
      expect(items.any((item) => item.itemName.toLowerCase() == 'oil'), isTrue);
    },
  );

  test(
    'purchased source item stays removed during automatic regeneration',
    () async {
      final String tacoId = await repository.createRecipe(
        RecipeInput(
          title: 'Tacos',
          ingredients: '1 lb ground beef\n8 tortillas',
        ),
      );
      final String week = RecipeRepository.weekStartDateFor(DateTime.now());

      await repository.setRecipePinnedForWeek(
        recipeId: tacoId,
        pinned: true,
        weekStartDate: week,
      );

      List<ShoppingListItemModel> items = await repository
          .listShoppingItemsForWeek(weekStartDate: week);
      final ShoppingListItemModel beef = items.firstWhere(
        (item) => item.itemName.toLowerCase().contains('ground beef'),
      );

      await repository.markShoppingItemPurchased(beef.id);
      await repository.regenerateShoppingListFromPinnedRecipes(
        weekStartDate: week,
      );

      items = await repository.listShoppingItemsForWeek(weekStartDate: week);
      expect(
        items.any(
          (item) => item.itemName.toLowerCase().contains('ground beef'),
        ),
        isFalse,
      );
      expect(
        items.any((item) => item.itemName.toLowerCase().contains('tortillas')),
        isTrue,
      );
    },
  );

  test('import jobs persist pending, success payload, and failures', () async {
    final String jobId = await repository.createImportJob(
      type: ImportJobType.url,
      sourcePayload: 'https://example.com/recipe',
    );

    await repository.completeImportJobSuccess(
      jobId: jobId,
      recipeInput: RecipeInput(
        title: 'Imported Soup',
        ingredients: '2 cups broth',
        directions: '1. Heat broth',
      ),
    );

    final String failedJobId = await repository.createImportJob(
      type: ImportJobType.url,
      sourcePayload: 'https://bad.example.com',
    );
    await repository.completeImportJobFailure(
      jobId: failedJobId,
      errorMessage: 'Could not fetch URL',
    );

    final List<ImportJob> jobs = await repository.listImportJobs();
    final ImportJob succeeded = jobs.firstWhere((job) => job.id == jobId);
    final ImportJob failed = jobs.firstWhere((job) => job.id == failedJobId);

    expect(succeeded.status, ImportJobStatus.succeeded);
    expect(succeeded.resultRecipeInput?.title, 'Imported Soup');
    expect(failed.status, ImportJobStatus.failed);
    expect(failed.errorMessage, contains('Could not fetch URL'));

    final String paprikaJobId = await repository.createImportJob(
      type: ImportJobType.paprikaFile,
      sourcePayload: '/tmp/recipe.paprikarecipes',
    );
    final List<ImportJob> refreshed = await repository.listImportJobs();
    final ImportJob paprika = refreshed.firstWhere(
      (job) => job.id == paprikaJobId,
    );
    expect(paprika.type, ImportJobType.paprikaFile);
  });
}
