import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../models/recipe.dart';

class WebRecipeImporter {
  WebRecipeImporter({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RecipeInput> importFromUrl(String sourceUrl) async {
    final Uri uri = Uri.parse(sourceUrl);
    final http.Response response = await _client.get(
      uri,
      headers: <String, String>{
        'User-Agent': 'RecipeApp/1.0 (+https://local.recipe.app) Mozilla/5.0',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Could not fetch URL (${response.statusCode}).');
    }

    return parseHtml(sourceUrl: sourceUrl, html: response.body);
  }

  RecipeInput parseHtml({required String sourceUrl, required String html}) {
    final dynamic recipeNode = _findRecipeNode(html);

    if (recipeNode is! Map<String, dynamic>) {
      throw StateError(
        'Could not find a recipe on this page. Try a different recipe URL.',
      );
    }

    final String? title = _asString(recipeNode['name']);
    final String? description = _asString(recipeNode['description']);
    final String? thumbnailUrl = _extractImageUrl(recipeNode['image']);
    final int? servings = _extractServings(recipeNode['recipeYield']);
    final int? totalMinutes = _extractTotalMinutes(recipeNode);

    final List<String> ingredients = _extractIngredients(
      recipeNode['recipeIngredient'],
    );
    final List<String> instructions = _extractInstructions(
      recipeNode['recipeInstructions'],
    );
    final List<String> tags = _extractTags(recipeNode);

    return RecipeInput(
      title: (title == null || title.trim().isEmpty)
          ? 'Imported Recipe'
          : title.trim(),
      description: description,
      ingredients: ingredients.join('\n'),
      directions: _numberedInstructions(instructions),
      sourceUrl: sourceUrl,
      thumbnailUrl: thumbnailUrl,
      servings: servings,
      totalTimeMinutes: totalMinutes,
      tagNames: tags,
    );
  }

  dynamic _findRecipeNode(String html) {
    final document = html_parser.parse(html);
    final scripts = document.querySelectorAll(
      'script[type="application/ld+json"]',
    );

    for (final script in scripts) {
      final String payload = script.text.trim();
      if (payload.isEmpty) {
        continue;
      }

      final dynamic decoded = _safeDecodeJson(payload);
      if (decoded == null) {
        continue;
      }

      final dynamic recipe = _searchForRecipe(decoded);
      if (recipe != null) {
        return recipe;
      }
    }

    return null;
  }

  dynamic _safeDecodeJson(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      return null;
    }
  }

  dynamic _searchForRecipe(dynamic node) {
    if (node is List) {
      for (final item in node) {
        final dynamic result = _searchForRecipe(item);
        if (result != null) {
          return result;
        }
      }
      return null;
    }

    if (node is Map) {
      final Map<String, dynamic> mapped = node.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      if (_isRecipeType(mapped['@type'])) {
        return mapped;
      }

      if (mapped.containsKey('@graph')) {
        final dynamic result = _searchForRecipe(mapped['@graph']);
        if (result != null) {
          return result;
        }
      }

      for (final dynamic value in mapped.values) {
        final dynamic result = _searchForRecipe(value);
        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  bool _isRecipeType(dynamic value) {
    if (value is String) {
      return value.toLowerCase() == 'recipe';
    }

    if (value is List) {
      return value.any((item) => item.toString().toLowerCase() == 'recipe');
    }

    return false;
  }

  String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _extractImageUrl(dynamic imageNode) {
    if (imageNode == null) {
      return null;
    }

    if (imageNode is String) {
      return _asString(imageNode);
    }

    if (imageNode is List && imageNode.isNotEmpty) {
      return _extractImageUrl(imageNode.first);
    }

    if (imageNode is Map) {
      return _asString(imageNode['url']);
    }

    return null;
  }

  int? _extractServings(dynamic yieldNode) {
    final String? value = _asString(
      yieldNode is List && yieldNode.isNotEmpty ? yieldNode.first : yieldNode,
    );
    if (value == null) {
      return null;
    }

    final RegExpMatch? match = RegExp(r'\d+').firstMatch(value);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(0)!);
  }

  int? _extractTotalMinutes(Map<String, dynamic> recipeNode) {
    final String? total = _asString(recipeNode['totalTime']);
    if (total != null) {
      final int? parsed = _parseIsoDurationMinutes(total);
      if (parsed != null) {
        return parsed;
      }
    }

    final int? prep = _parseIsoDurationMinutes(
      _asString(recipeNode['prepTime']),
    );
    final int? cook = _parseIsoDurationMinutes(
      _asString(recipeNode['cookTime']),
    );

    if (prep == null && cook == null) {
      return null;
    }

    return (prep ?? 0) + (cook ?? 0);
  }

  int? _parseIsoDurationMinutes(String? rawDuration) {
    if (rawDuration == null) {
      return null;
    }

    final RegExp matchExp = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?$',
      caseSensitive: false,
    );

    final RegExpMatch? match = matchExp.firstMatch(rawDuration.trim());
    if (match == null) {
      return null;
    }

    final int days = int.tryParse(match.group(1) ?? '') ?? 0;
    final int hours = int.tryParse(match.group(2) ?? '') ?? 0;
    final int minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    return (days * 24 * 60) + (hours * 60) + minutes;
  }

  List<String> _extractIngredients(dynamic ingredientNode) {
    if (ingredientNode is! List) {
      return const <String>[];
    }

    return ingredientNode
        .map((item) => _asString(item))
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .toList();
  }

  List<String> _extractInstructions(dynamic instructionNode) {
    if (instructionNode == null) {
      return const <String>[];
    }

    if (instructionNode is String) {
      final String normalized = instructionNode.trim();
      return normalized.isEmpty ? const <String>[] : <String>[normalized];
    }

    if (instructionNode is List) {
      final List<String> lines = <String>[];
      for (final dynamic item in instructionNode) {
        lines.addAll(_extractInstructions(item));
      }
      return lines;
    }

    if (instructionNode is Map) {
      final String? text = _asString(instructionNode['text']);
      if (text != null) {
        return <String>[text];
      }

      if (instructionNode.containsKey('itemListElement')) {
        return _extractInstructions(instructionNode['itemListElement']);
      }
    }

    return const <String>[];
  }

  List<String> _extractTags(Map<String, dynamic> recipeNode) {
    final List<String> tags = <String>[];

    void addFromCsv(String? value) {
      if (value == null) {
        return;
      }

      for (final String part in value.split(',')) {
        final String tag = part.trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    addFromCsv(_asString(recipeNode['keywords']));
    addFromCsv(_asString(recipeNode['recipeCategory']));
    addFromCsv(_asString(recipeNode['recipeCuisine']));

    final Map<String, String> unique = <String, String>{};
    for (final String tag in tags) {
      unique[tag.toLowerCase()] = tag;
    }

    return unique.values.toList();
  }

  String _numberedInstructions(List<String> instructions) {
    if (instructions.isEmpty) {
      return '';
    }

    return instructions
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
  }
}
