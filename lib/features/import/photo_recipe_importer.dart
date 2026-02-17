import 'photo_recipe_importer_stub.dart'
    if (dart.library.io) 'photo_recipe_importer_io.dart'
    if (dart.library.html) 'photo_recipe_importer_web.dart' as impl;

import 'photo_recipe_importer_types.dart';

export 'photo_recipe_importer_types.dart';

PhotoRecipeImporter createPhotoRecipeImporter() {
  return impl.createPhotoRecipeImporter();
}
