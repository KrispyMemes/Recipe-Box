import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_app/features/import/paprika_recipe_importer.dart';

void main() {
  test('parses paprika archive payload and maps recipe fields', () async {
    final PaprikaRecipeImporter importer = createPaprikaRecipeImporter();

    final Map<String, Object?> payload = <String, Object?>{
      'name': '1-2-3-4 Yogurt Cake',
      'description': 'Simple cake.',
      'ingredients': '1 cup yogurt\n2 cups sugar',
      'directions': 'Mix\nBake',
      'source_url': 'https://example.com/yogurt-cake',
      'image_url': 'https://example.com/yogurt-cake.jpg',
      'servings': '8 servings',
      'total_time': '1 hour 15 minutes',
      'categories': <String>['Dessert', 'Baking'],
      'photo': 'photo.jpg',
      'photo_data': base64Encode(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF])),
    };

    final recipe = await importer.importFromPaprikaArchiveBytes(
      _buildPaprikaArchive(payload),
      sourceFilePath: '/tmp/1-2-3-4 Yogurt Cake.paprikarecipes',
    );

    expect(recipe.title, '1-2-3-4 Yogurt Cake');
    expect(recipe.description, 'Simple cake.');
    expect(recipe.ingredients, contains('1 cup yogurt'));
    expect(recipe.directions, contains('Mix'));
    expect(recipe.sourceUrl, 'https://example.com/yogurt-cake');
    expect(recipe.thumbnailUrl, 'https://example.com/yogurt-cake.jpg');
    expect(recipe.servings, 8);
    expect(recipe.totalTimeMinutes, 75);
    expect(recipe.tagNames, containsAll(<String>['Dessert', 'Baking']));
  });

  test('throws when archive has no .paprikarecipe payload', () async {
    final Archive archive = Archive();
    archive.addFile(ArchiveFile('not-a-recipe.txt', 5, utf8.encode('hello')));
    final List<int> archiveBytes = ZipEncoder().encode(archive);

    final PaprikaRecipeImporter importer = createPaprikaRecipeImporter();

    expect(
      () => importer.importFromPaprikaArchiveBytes(archiveBytes),
      throwsA(isA<StateError>()),
    );
  });
}

List<int> _buildPaprikaArchive(Map<String, Object?> payload) {
  final Archive archive = Archive();
  final String jsonPayload = jsonEncode(payload);
  final List<int> gzipped = GZipCodec().encode(utf8.encode(jsonPayload));
  archive.addFile(
    ArchiveFile(
      'Recipe.paprikarecipe',
      gzipped.length,
      Uint8List.fromList(gzipped),
    ),
  );
  return ZipEncoder().encode(archive);
}
