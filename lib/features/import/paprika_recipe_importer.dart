import 'paprika_recipe_importer_stub.dart'
    if (dart.library.io) 'paprika_recipe_importer_io.dart'
    if (dart.library.html) 'paprika_recipe_importer_web.dart' as impl;

import 'paprika_recipe_importer_types.dart';

export 'paprika_recipe_importer_types.dart';

PaprikaRecipeImporter createPaprikaRecipeImporter() {
  return impl.createPaprikaRecipeImporter();
}
