import '../../models/recipe.dart';

abstract class PhotoRecipeImporter {
  Future<RecipeInput> importFromImagePath(String imagePath);

  RecipeInput buildRecipeInputFromText(
    String extractedText, {
    required String thumbnailPath,
    required String sourceImagePath,
    String? fallbackMessage,
  });
}
