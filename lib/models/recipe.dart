class RecipeInput {
  RecipeInput({
    required this.title,
    this.description,
    this.ingredients,
    this.directions,
    this.sourceUrl,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.servings,
    this.totalTimeMinutes,
    this.tagNames = const <String>[],
    this.collectionNames = const <String>[],
  });

  final String title;
  final String? description;
  final String? ingredients;
  final String? directions;
  final String? sourceUrl;
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final int? servings;
  final int? totalTimeMinutes;
  final List<String> tagNames;
  final List<String> collectionNames;
}

class Recipe {
  Recipe({
    required this.id,
    required this.title,
    this.description,
    this.ingredients,
    this.directions,
    this.sourceUrl,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.servings,
    this.totalTimeMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.tagNames = const <String>[],
    this.collectionNames = const <String>[],
  });

  final String id;
  final String title;
  final String? description;
  final String? ingredients;
  final String? directions;
  final String? sourceUrl;
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final int? servings;
  final int? totalTimeMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tagNames;
  final List<String> collectionNames;
}

class RecipeTag {
  const RecipeTag({required this.id, required this.name});

  final String id;
  final String name;
}

class RecipeCollection {
  const RecipeCollection({required this.id, required this.name});

  final String id;
  final String name;
}

class RecipeLibraryData {
  const RecipeLibraryData({
    required this.recipes,
    required this.tags,
    required this.collections,
  });

  final List<Recipe> recipes;
  final List<RecipeTag> tags;
  final List<RecipeCollection> collections;
}
