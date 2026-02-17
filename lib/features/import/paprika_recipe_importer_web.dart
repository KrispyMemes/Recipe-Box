import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../models/recipe.dart';
import 'paprika_recipe_importer_types.dart';

PaprikaRecipeImporter createPaprikaRecipeImporter() => WebPaprikaRecipeImporter();

class WebPaprikaRecipeImporter implements PaprikaRecipeImporter {
  @override
  Future<RecipeInput> importFromPaprikaFile(String filePath) {
    throw UnsupportedError('Paprika import from local file paths is unavailable on web.');
  }

  @override
  Future<RecipeInput> importFromPaprikaArchiveBytes(
    List<int> archiveBytes, {
    String? sourceFilePath,
  }) async {
    final Archive archive = ZipDecoder().decodeBytes(archiveBytes);
    final ArchiveFile recipeFile = archive.files.firstWhere(
      (file) => file.isFile && file.name.toLowerCase().endsWith('.paprikarecipe'),
    );
    final Uint8List compressed = Uint8List.fromList(recipeFile.content as List<int>);
    final List<int> payload = GZipCodec().decode(compressed);
    final Map<String, dynamic> decoded =
        (jsonDecode(utf8.decode(payload)) as Map).cast<String, dynamic>();

    return RecipeInput(
      title: (decoded['name']?.toString().trim().isNotEmpty ?? false)
          ? decoded['name'].toString().trim()
          : (sourceFilePath == null
                ? 'Imported Paprika Recipe'
                : p.basenameWithoutExtension(sourceFilePath)),
      description: decoded['description']?.toString(),
      ingredients: decoded['ingredients']?.toString(),
      directions: decoded['directions']?.toString(),
      sourceUrl: decoded['source_url']?.toString(),
      thumbnailUrl: decoded['image_url']?.toString(),
      tagNames: const <String>[],
      collectionNames: const <String>[],
    );
  }
}
