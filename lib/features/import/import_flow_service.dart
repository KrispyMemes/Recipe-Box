import '../../models/recipe.dart';
import 'paprika_recipe_importer.dart';
import 'paprika_recipe_importer_types.dart';
import 'photo_recipe_importer.dart';
import 'photo_recipe_importer_types.dart';

abstract class ImportFlowService {
  Future<RecipeInput> importPhotoFromPath(String imagePath);

  Future<RecipeInput> importPaprikaFromPath(String filePath);

  Future<RecipeInput> importPaprikaFromBytes(
    List<int> archiveBytes, {
    String? sourceFilePath,
  });
}

class DefaultImportFlowService implements ImportFlowService {
  DefaultImportFlowService({
    PhotoRecipeImporter? photoImporter,
    PaprikaRecipeImporter? paprikaImporter,
  }) : _photoImporter = photoImporter ?? createPhotoRecipeImporter(),
       _paprikaImporter = paprikaImporter ?? createPaprikaRecipeImporter();

  final PhotoRecipeImporter _photoImporter;
  final PaprikaRecipeImporter _paprikaImporter;

  @override
  Future<RecipeInput> importPhotoFromPath(String imagePath) {
    return _photoImporter.importFromImagePath(imagePath);
  }

  @override
  Future<RecipeInput> importPaprikaFromPath(String filePath) {
    return _paprikaImporter.importFromPaprikaFile(filePath);
  }

  @override
  Future<RecipeInput> importPaprikaFromBytes(
    List<int> archiveBytes, {
    String? sourceFilePath,
  }) {
    return _paprikaImporter.importFromPaprikaArchiveBytes(
      archiveBytes,
      sourceFilePath: sourceFilePath,
    );
  }
}
