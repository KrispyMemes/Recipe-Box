import 'dart:typed_data';

import 'app_file_storage_stub.dart'
    if (dart.library.io) 'app_file_storage_io.dart'
    if (dart.library.html) 'app_file_storage_web.dart';

abstract class AppFileStorage {
  Future<String> saveThumbnailBytes(
    Uint8List bytes, {
    String? extensionHint,
    String filenamePrefix,
  });

  Future<String> copyImportPhoto(String imagePath);

  Future<Uint8List> readAsBytes(String path);

  bool fileExistsSync(String path);

  Future<String> databasePath(String filename);
}

AppFileStorage createAppFileStorage() => createAppFileStorageImpl();
