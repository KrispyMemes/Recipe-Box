import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../models/recipe.dart';
import '../../services/storage/app_file_storage.dart';
import 'paprika_recipe_importer_types.dart';

typedef ThumbnailBytesSaver =
    Future<String> Function(Uint8List bytes, {String? extensionHint});

PaprikaRecipeImporter createPaprikaRecipeImporter() => IoPaprikaRecipeImporter();

class IoPaprikaRecipeImporter implements PaprikaRecipeImporter {
  IoPaprikaRecipeImporter({ThumbnailBytesSaver? thumbnailBytesSaver})
    : _thumbnailBytesSaver =
          thumbnailBytesSaver ?? _defaultSaveThumbnailBytes;

  final ThumbnailBytesSaver _thumbnailBytesSaver;

  @override
  Future<RecipeInput> importFromPaprikaFile(String filePath) async {
    final List<int> archiveBytes = await File(filePath).readAsBytes();
    return importFromPaprikaArchiveBytes(
      archiveBytes,
      sourceFilePath: filePath,
    );
  }

  @override
  Future<RecipeInput> importFromPaprikaArchiveBytes(
    List<int> archiveBytes, {
    String? sourceFilePath,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(archiveBytes);
    } catch (_) {
      throw StateError(
        'Could not read this Paprika file. Please choose a .paprikarecipes export.',
      );
    }

    ArchiveFile? paprikaRecipeFile;
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      if (file.name.toLowerCase().endsWith('.paprikarecipe')) {
        paprikaRecipeFile = file;
        break;
      }
    }

    if (paprikaRecipeFile == null) {
      throw StateError(
        'No recipe data was found in this Paprika file. Please export again and retry.',
      );
    }

    final dynamic compressedContent = paprikaRecipeFile.content;
    final List<int> compressedPayload;
    if (compressedContent is Uint8List) {
      compressedPayload = compressedContent;
    } else if (compressedContent is List<int>) {
      compressedPayload = compressedContent;
    } else {
      throw StateError('Unsupported Paprika recipe payload format.');
    }
    final List<int> payloadBytes;
    try {
      payloadBytes = GZipCodec().decode(compressedPayload);
    } catch (_) {
      throw StateError(
        'This Paprika file is not in the expected format. Try exporting from Paprika again.',
      );
    }

    final dynamic decoded = jsonDecode(utf8.decode(payloadBytes));
    if (decoded is! Map) {
      throw StateError('Unsupported Paprika payload format.');
    }

    final Map<String, dynamic> payload = decoded.map(
      (dynamic key, dynamic value) =>
          MapEntry(key.toString(), value as Object?),
    );

    return _toRecipeInput(payload, sourceFilePath: sourceFilePath);
  }

  Future<RecipeInput> _toRecipeInput(
    Map<String, dynamic> payload, {
    String? sourceFilePath,
  }) async {
    final String fallbackTitle = sourceFilePath == null
        ? 'Imported Paprika Recipe'
        : p.basenameWithoutExtension(sourceFilePath);
    final String title = _asString(payload['name'])?.trim().isNotEmpty == true
        ? _asString(payload['name'])!.trim()
        : fallbackTitle;

    final String? thumbnailPath = await _saveEmbeddedPhoto(payload);

    return RecipeInput(
      title: title,
      description: _asString(payload['description']),
      ingredients: _asString(payload['ingredients']),
      directions: _asString(payload['directions']),
      sourceUrl: _asString(payload['source_url']),
      thumbnailUrl: _asString(payload['image_url']),
      thumbnailPath: thumbnailPath,
      servings: _parseServings(_asString(payload['servings'])),
      totalTimeMinutes: _parseDurationMinutes(_asString(payload['total_time'])),
      tagNames: _extractTags(payload),
      collectionNames: const <String>[],
    );
  }

  List<String> _extractTags(Map<String, dynamic> payload) {
    final List<String> tags = <String>[];
    final dynamic categories = payload['categories'];
    if (categories is List) {
      for (final dynamic value in categories) {
        final String? tag = _asString(value);
        if (tag != null && tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    final Map<String, String> unique = <String, String>{};
    for (final String tag in tags) {
      unique[tag.toLowerCase()] = tag;
    }

    return unique.values.toList();
  }

  Future<String?> _saveEmbeddedPhoto(Map<String, dynamic> payload) async {
    final String? photoDataRaw = _asString(payload['photo_data']);
    if (photoDataRaw == null || photoDataRaw.trim().isEmpty) {
      return null;
    }

    final String normalizedBase64 = photoDataRaw
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '');
    if (normalizedBase64.isEmpty) {
      return null;
    }

    try {
      final Uint8List bytes = base64Decode(normalizedBase64);
      final String? photoFilename = _asString(payload['photo']);
      return _thumbnailBytesSaver(
        bytes,
        extensionHint: photoFilename == null
            ? null
            : p.extension(photoFilename),
      );
    } catch (_) {
      return null;
    }
  }

  int? _parseServings(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(0)!);
  }

  int? _parseDurationMinutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final String value = raw.toLowerCase();
    final RegExpMatch? hoursMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:hour|hours|hr|hrs)',
    ).firstMatch(value);
    final RegExpMatch? minutesMatch = RegExp(
      r'(\d+)\s*(?:minute|minutes|min|mins)',
    ).firstMatch(value);

    if (hoursMatch == null && minutesMatch == null) {
      return int.tryParse(value.trim());
    }

    int minutes = 0;
    if (hoursMatch != null) {
      final double? hours = double.tryParse(hoursMatch.group(1)!);
      if (hours != null) {
        minutes += (hours * 60).round();
      }
    }
    if (minutesMatch != null) {
      minutes += int.tryParse(minutesMatch.group(1)!) ?? 0;
    }
    return minutes == 0 ? null : minutes;
  }

  String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Future<String> _defaultSaveThumbnailBytes(
    Uint8List bytes, {
    String? extensionHint,
  }) {
    return createAppFileStorage().saveThumbnailBytes(
      bytes,
      extensionHint: extensionHint,
      filenamePrefix: 'thumb_paprika',
    );
  }
}
