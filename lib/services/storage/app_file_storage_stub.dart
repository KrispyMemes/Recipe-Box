import 'dart:typed_data';

import 'app_file_storage.dart';

AppFileStorage createAppFileStorageImpl() => _StubAppFileStorage();

class _StubAppFileStorage implements AppFileStorage {
  @override
  Future<String> copyImportPhoto(String imagePath) {
    throw UnsupportedError('Local file storage is not available on this platform.');
  }

  @override
  bool fileExistsSync(String path) => false;

  @override
  Future<String> databasePath(String filename) {
    throw UnsupportedError('Local database storage is not available on this platform.');
  }

  @override
  Future<Uint8List> readAsBytes(String path) {
    throw UnsupportedError('Local file storage is not available on this platform.');
  }

  @override
  Future<String> saveThumbnailBytes(
    Uint8List bytes, {
    String? extensionHint,
    String filenamePrefix = 'thumb',
  }) {
    throw UnsupportedError('Local file storage is not available on this platform.');
  }
}
