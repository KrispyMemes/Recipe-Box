import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_app/features/shopping/walmart_assist.dart';

void main() {
  test('normalizeQuery keeps ingredient detail and only trims formatting', () {
    expect(
      WalmartAssist.normalizeQuery('2 cups shredded cheddar cheese'),
      '2 cups shredded cheddar cheese',
    );
    expect(
      WalmartAssist.normalizeQuery('- 1 lb ground beef'),
      '1 lb ground beef',
    );
    expect(WalmartAssist.normalizeQuery('8 tortillas'), '8 tortillas');
  });

  test('normalizeQuery removes parenthetical detail', () {
    expect(
      WalmartAssist.normalizeQuery('1 can tomatoes (14.5 oz)'),
      '1 can tomatoes',
    );
    expect(
      WalmartAssist.normalizeQuery('chili powder (optional)'),
      'chili powder',
    );
    expect(
      WalmartAssist.normalizeQuery('beans [low sodium] {drained}'),
      'beans',
    );
    expect(
      WalmartAssist.normalizeQuery('oil (for sauteing (optional))'),
      'oil',
    );
  });

  test(
    'normalizeQuery keeps non-empty fallback when cleanup strips all text',
    () {
      expect(WalmartAssist.normalizeQuery('2 cups'), '2 cups');
    },
  );

  test('buildSearchUrl returns encoded Walmart search URL', () {
    expect(
      WalmartAssist.buildSearchUrl('1 lb ground beef'),
      'https://www.walmart.com/search?q=1+lb+ground+beef',
    );
  });
}
