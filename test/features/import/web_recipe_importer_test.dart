import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_app/features/import/web_recipe_importer.dart';

void main() {
  test('parses recipe fields from JSON-LD', () {
    const String html = '''
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Recipe",
              "name": "One Pot Pasta",
              "description": "Simple and quick.",
              "image": "https://example.com/pasta.jpg",
              "recipeYield": "4 servings",
              "prepTime": "PT10M",
              "cookTime": "PT20M",
              "keywords": "Dinner, Weeknight",
              "recipeIngredient": ["1 lb pasta", "2 cups broth"],
              "recipeInstructions": [
                {"@type": "HowToStep", "text": "Boil broth."},
                {"@type": "HowToStep", "text": "Cook pasta."}
              ]
            }
          </script>
        </head>
        <body></body>
      </html>
    ''';

    final WebRecipeImporter importer = WebRecipeImporter();
    final recipe = importer.parseHtml(
      sourceUrl: 'https://example.com/one-pot-pasta',
      html: html,
    );

    expect(recipe.title, 'One Pot Pasta');
    expect(recipe.sourceUrl, 'https://example.com/one-pot-pasta');
    expect(recipe.thumbnailUrl, 'https://example.com/pasta.jpg');
    expect(recipe.servings, 4);
    expect(recipe.totalTimeMinutes, 30);
    expect(recipe.tagNames, containsAll(<String>['Dinner', 'Weeknight']));
    expect(recipe.description, 'Simple and quick.');
    expect(recipe.ingredients, contains('1 lb pasta'));
    expect(recipe.directions, contains('1. Boil broth.'));
  });

  test('throws when recipe JSON-LD is missing', () {
    final WebRecipeImporter importer = WebRecipeImporter();

    expect(
      () => importer.parseHtml(
        sourceUrl: 'https://example.com/not-a-recipe',
        html: '<html><body>No schema recipe here.</body></html>',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
