import 'dart:typed_data';

import 'app_file_storage.dart';

AppFileStorage createAppFileStorageImpl() => _WebAppFileStorage();

class _WebAppFileStorage implements AppFileStorage {
  @override
  Future<String> copyImportPhoto(String imagePath) {
    throw UnsupportedError('Copying local files is not available on web.');
  }

  @override
  bool fileExistsSync(String path) => false;

  @override
  Future<String> databasePath(String filename) {
    throw UnsupportedError('Local database storage is not available on web.');
  }

  @override
  Future<Uint8List> readAsBytes(String path) {
    throw UnsupportedError('Reading local files by path is not available on web.');
  }

  @override
  Future<String> saveThumbnailBytes(
    Uint8List bytes, {
    String? extensionHint,
    String filenamePrefix = 'thumb',
  }) {
    throw UnsupportedError('Saving local files is not available on web.');
  }
}
