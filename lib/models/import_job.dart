import 'recipe.dart';

enum ImportJobType { url, photo, paprikaFile, share }

enum ImportJobStatus { pending, succeeded, failed }

class ImportJob {
  const ImportJob({
    required this.id,
    required this.type,
    required this.status,
    required this.sourcePayload,
    this.resultRecipeInput,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ImportJobType type;
  final ImportJobStatus status;
  final String sourcePayload;
  final RecipeInput? resultRecipeInput;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
}
