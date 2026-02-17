import '../../models/recipe.dart';
import 'photo_recipe_importer_types.dart';

PhotoRecipeImporter createPhotoRecipeImporter() => WebPhotoRecipeImporter();

class WebPhotoRecipeImporter implements PhotoRecipeImporter {
  @override
  Future<RecipeInput> importFromImagePath(String imagePath) async {
    return buildRecipeInputFromText(
      '',
      thumbnailPath: imagePath,
      sourceImagePath: imagePath,
      fallbackMessage:
          'OCR is not available on web yet. Your photo reference was attached and you can finish manually.',
    );
  }

  @override
  RecipeInput buildRecipeInputFromText(
    String extractedText, {
    required String thumbnailPath,
    required String sourceImagePath,
    String? fallbackMessage,
  }) {
    return RecipeInput(
      title: 'Photo Import',
      description: fallbackMessage ?? extractedText,
      sourceUrl: sourceImagePath,
      thumbnailPath: thumbnailPath,
      tagNames: const <String>['Photo Import'],
      collectionNames: const <String>[],
    );
  }
}
