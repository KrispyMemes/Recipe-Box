import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../models/recipe.dart';
import '../../services/platform/platform_capability_service.dart';
import '../../services/storage/app_file_storage.dart';
import 'photo_recipe_importer_types.dart';

PhotoRecipeImporter createPhotoRecipeImporter() => IoPhotoRecipeImporter();

class IoPhotoRecipeImporter implements PhotoRecipeImporter {
  IoPhotoRecipeImporter({
    TextRecognizer? textRecognizer,
    PlatformCapabilityService? capabilityService,
    AppFileStorage? fileStorage,
  }) : _textRecognizer = textRecognizer ?? TextRecognizer(),
       _capabilityService = capabilityService ?? createPlatformCapabilityService(),
       _fileStorage = fileStorage ?? createAppFileStorage();

  final TextRecognizer _textRecognizer;
  final PlatformCapabilityService _capabilityService;
  final AppFileStorage _fileStorage;
  static const MethodChannel _ocrChannel = MethodChannel('recipe_app/ocr');

  @override
  Future<RecipeInput> importFromImagePath(String imagePath) async {
    final String storedImagePath = await _fileStorage.copyImportPhoto(imagePath);
    String extractedText = '';
    String? fallbackMessage;

    if (!_capabilityService.supportsOcr) {
      fallbackMessage =
          'OCR is not yet available on this platform. Your photo was attached and you can finish entry manually.';
      return buildRecipeInputFromText(
        extractedText,
        thumbnailPath: storedImagePath,
        sourceImagePath: storedImagePath,
        fallbackMessage: fallbackMessage,
      );
    }

    try {
      if (_capabilityService.isDesktopFfiPlatform) {
        extractedText = await _extractTextWithMacOSVision(storedImagePath);
      } else {
        final InputImage inputImage = InputImage.fromFilePath(storedImagePath);
        final RecognizedText recognizedText = await _textRecognizer.processImage(
          inputImage,
        );
        extractedText = recognizedText.text;
      }
    } catch (_) {
      extractedText = '';
      fallbackMessage = 'OCR failed on this image. You can still edit manually.';
    }

    return buildRecipeInputFromText(
      extractedText,
      thumbnailPath: storedImagePath,
      sourceImagePath: storedImagePath,
      fallbackMessage: fallbackMessage,
    );
  }

  @override
  RecipeInput buildRecipeInputFromText(
    String extractedText, {
    required String thumbnailPath,
    required String sourceImagePath,
    String? fallbackMessage,
  }) {
    final List<String> rawLines = extractedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String title = rawLines.isEmpty ? 'Photo Import' : rawLines.first;
    if (title.length > 80) {
      title = title.substring(0, 80);
    }

    final _Sections sections = _splitSections(rawLines);
    final String description = sections.description.join('\n').trim();
    final String ingredients = sections.ingredients.join('\n').trim();
    final String directions = sections.directions.join('\n').trim();

    final String fallbackDescription = extractedText.trim().isEmpty
        ? (fallbackMessage ??
            'No text was detected from this photo. You can type the recipe manually.')
        : description;

    return RecipeInput(
      title: title,
      description: fallbackDescription.isEmpty ? null : fallbackDescription,
      ingredients: ingredients.isEmpty ? null : ingredients,
      directions: directions.isEmpty ? null : directions,
      sourceUrl: sourceImagePath,
      thumbnailPath: thumbnailPath,
      tagNames: const <String>['Photo Import'],
      collectionNames: const <String>[],
    );
  }

  _Sections _splitSections(List<String> lines) {
    if (lines.isEmpty) {
      return const _Sections(
        description: <String>[],
        ingredients: <String>[],
        directions: <String>[],
      );
    }

    int ingredientsHeader = -1;
    int directionsHeader = -1;

    for (int i = 0; i < lines.length; i++) {
      final String lower = lines[i].toLowerCase();
      if (ingredientsHeader == -1 && _isIngredientsHeader(lower)) {
        ingredientsHeader = i;
      }
      if (directionsHeader == -1 && _isDirectionsHeader(lower)) {
        directionsHeader = i;
      }
    }

    if (ingredientsHeader != -1 && directionsHeader != -1) {
      final int startIngredients = ingredientsHeader + 1;
      final int startDirections = directionsHeader + 1;
      if (ingredientsHeader < directionsHeader) {
        return _Sections(
          description: lines.take(ingredientsHeader).toList(),
          ingredients: lines.sublist(startIngredients, directionsHeader),
          directions: lines.sublist(startDirections),
        );
      }

      return _Sections(
        description: lines.take(directionsHeader).toList(),
        ingredients: lines.sublist(startIngredients),
        directions: lines.sublist(startDirections, ingredientsHeader),
      );
    }

    final List<String> ingredientLike = <String>[];
    final List<String> directionLike = <String>[];
    for (final String line in lines.skip(1)) {
      if (_looksLikeIngredient(line)) {
        ingredientLike.add(line);
      } else {
        directionLike.add(line);
      }
    }

    return _Sections(
      description: const <String>[],
      ingredients: ingredientLike,
      directions: directionLike,
    );
  }

  bool _isIngredientsHeader(String value) {
    return value == 'ingredients' ||
        value == 'ingredient' ||
        value == 'what you need';
  }

  bool _isDirectionsHeader(String value) {
    return value == 'directions' ||
        value == 'direction' ||
        value == 'instructions' ||
        value == 'method' ||
        value == 'steps';
  }

  bool _looksLikeIngredient(String line) {
    final String lower = line.toLowerCase();
    if (RegExp(r'^\d').hasMatch(lower) ||
        RegExp(
          r'\b(cup|cups|tbsp|tsp|oz|ounce|ounces|lb|lbs|gram|g|kg|ml|l)\b',
        ).hasMatch(lower)) {
      return true;
    }

    return false;
  }

  Future<String> _extractTextWithMacOSVision(String imagePath) async {
    final String? result = await _ocrChannel.invokeMethod<String>(
      'recognizeText',
      <String, Object?>{'path': imagePath},
    );
    return result ?? '';
  }
}

class _Sections {
  const _Sections({
    required this.description,
    required this.ingredients,
    required this.directions,
  });

  final List<String> description;
  final List<String> ingredients;
  final List<String> directions;
}
