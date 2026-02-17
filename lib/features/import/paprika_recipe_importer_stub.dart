import '../../models/recipe.dart';
import 'paprika_recipe_importer_types.dart';

PaprikaRecipeImporter createPaprikaRecipeImporter() =>
    _StubPaprikaRecipeImporter();

class _StubPaprikaRecipeImporter implements PaprikaRecipeImporter {
  @override
  Future<RecipeInput> importFromPaprikaArchiveBytes(
    List<int> archiveBytes, {
    String? sourceFilePath,
  }) {
    throw UnsupportedError('Paprika import is not available on this platform.');
  }

  @override
  Future<RecipeInput> importFromPaprikaFile(String filePath) {
    throw UnsupportedError('Paprika import is not available on this platform.');
  }
}
