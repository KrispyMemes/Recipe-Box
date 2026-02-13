import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_app/features/import/photo_recipe_importer.dart';

void main() {
  test(
    'photo OCR parser splits ingredients and directions from section headers',
    () {
      final PhotoRecipeImporter importer = PhotoRecipeImporter();
      final recipe = importer.buildRecipeInputFromText(
        '''
Grandma Chili
Ingredients
1 lb beef
1 can tomatoes
Directions
Brown beef
Add tomatoes and simmer
''',
        thumbnailPath: '/tmp/chili.jpg',
        sourceImagePath: '/tmp/chili.jpg',
      );

      expect(recipe.title, 'Grandma Chili');
      expect(recipe.ingredients, contains('1 lb beef'));
      expect(recipe.directions, contains('Brown beef'));
      expect(recipe.thumbnailPath, '/tmp/chili.jpg');
      expect(recipe.tagNames, contains('Photo Import'));
    },
  );

  test('photo OCR parser falls back when text is missing', () {
    final PhotoRecipeImporter importer = PhotoRecipeImporter();
    final recipe = importer.buildRecipeInputFromText(
      '',
      thumbnailPath: '/tmp/empty.jpg',
      sourceImagePath: '/tmp/empty.jpg',
    );

    expect(recipe.title, 'Photo Import');
    expect(recipe.description, contains('No text was detected'));
  });
}
