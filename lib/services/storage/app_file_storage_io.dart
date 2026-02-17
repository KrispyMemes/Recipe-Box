import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_file_storage.dart';

AppFileStorage createAppFileStorageImpl() => _IoAppFileStorage();

class _IoAppFileStorage implements AppFileStorage {
  @override
  Future<String> databasePath(String filename) async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, filename);
  }

  @override
  Future<String> saveThumbnailBytes(
    Uint8List bytes, {
    String? extensionHint,
    String filenamePrefix = 'thumb',
  }) async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory thumbnailsDir = Directory(
      p.join(supportDir.path, 'recipe_thumbnails'),
    );
    if (!thumbnailsDir.existsSync()) {
      thumbnailsDir.createSync(recursive: true);
    }

    String ext = (extensionHint ?? '').toLowerCase();
    if (ext.isEmpty || ext.length > 6 || !ext.startsWith('.')) {
      ext = '.jpg';
    }

    final String filename =
        '${filenamePrefix}_${DateTime.now().microsecondsSinceEpoch}$ext';
    final String outputPath = p.join(thumbnailsDir.path, filename);
    await File(outputPath).writeAsBytes(bytes, flush: true);
    return outputPath;
  }

  @override
  Future<String> copyImportPhoto(String imagePath) async {
    final Directory supportDir = await getApplicationSupportDirectory();
    final Directory importsDir = Directory(
      p.join(supportDir.path, 'import_photos'),
    );
    if (!importsDir.existsSync()) {
      importsDir.createSync(recursive: true);
    }

    String extension = p.extension(imagePath).toLowerCase();
    if (extension.isEmpty || extension.length > 6 || !extension.startsWith('.')) {
      extension = '.jpg';
    }

    final String outputPath = p.join(
      importsDir.path,
      'photo_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    await File(imagePath).copy(outputPath);
    return outputPath;
  }

  @override
  Future<Uint8List> readAsBytes(String path) async {
    return File(path).readAsBytes();
  }

  @override
  bool fileExistsSync(String path) {
    return File(path).existsSync();
  }
}
