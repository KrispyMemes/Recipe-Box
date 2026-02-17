import '../../models/recipe.dart';

abstract class PaprikaRecipeImporter {
  Future<RecipeInput> importFromPaprikaFile(String filePath);

  Future<RecipeInput> importFromPaprikaArchiveBytes(
    List<int> archiveBytes, {
    String? sourceFilePath,
  });
}
