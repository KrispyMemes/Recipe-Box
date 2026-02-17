import '../../models/recipe.dart';
import 'photo_recipe_importer_types.dart';

PhotoRecipeImporter createPhotoRecipeImporter() => _StubPhotoRecipeImporter();

class _StubPhotoRecipeImporter implements PhotoRecipeImporter {
  @override
  Future<RecipeInput> importFromImagePath(String imagePath) {
    throw UnsupportedError('Photo import is not available on this platform.');
  }

  @override
  RecipeInput buildRecipeInputFromText(
    String extractedText, {
    required String thumbnailPath,
    required String sourceImagePath,
    String? fallbackMessage,
  }) {
    throw UnsupportedError('Photo import is not available on this platform.');
  }
}
