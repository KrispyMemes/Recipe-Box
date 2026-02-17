import 'dart:collection';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../data/recipe_repository.dart';
import '../../models/import_job.dart';
import '../../models/recipe.dart';
import '../../services/platform/platform_capability_service.dart';
import '../../services/storage/app_file_storage.dart';
import '../../widgets/local_file_image.dart';
import '../import/import_flow_service.dart';
import '../import/web_recipe_importer.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({required this.repository, super.key});

  final RecipeRepository repository;

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final WebRecipeImporter _webRecipeImporter = WebRecipeImporter();
  final ImportFlowService _importFlowService = DefaultImportFlowService();
  final PlatformCapabilityService _capabilities = createPlatformCapabilityService();
  final AppFileStorage _fileStorage = createAppFileStorage();

  bool _isLoading = true;
  bool _isImporting = false;
  String _importingLabel = '';
  final String _weekStartDate = RecipeRepository.weekStartDateFor(
    DateTime.now(),
  );
  Set<String> _pinnedRecipeIds = <String>{};
  RecipeLibraryData _libraryData = const RecipeLibraryData(
    recipes: <Recipe>[],
    tags: <RecipeTag>[],
    collections: <RecipeCollection>[],
  );
  String? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _refreshLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshLibrary() async {
    setState(() {
      _isLoading = true;
    });

    final RecipeLibraryData data = await widget.repository.loadLibrary(
      searchQuery: _searchController.text,
      tagId: _selectedTagId,
    );
    final Set<String> pinnedIds = await widget.repository
        .getPinnedRecipeIdsForWeek(weekStartDate: _weekStartDate);

    if (!mounted) {
      return;
    }

    setState(() {
      _libraryData = data;
      _pinnedRecipeIds = pinnedIds;
      _isLoading = false;
    });
  }

  Future<void> _showCreateRecipeDialog({RecipeInput? initialInput}) async {
    final _EditorTagConfig tagConfig = _buildEditorTagConfig(
      initialInput: initialInput,
    );
    final RecipeInput? input = await showDialog<RecipeInput>(
      context: context,
      builder: (context) => _RecipeEditorDialog(
        initialInput: initialInput,
        existingTagNames: tagConfig.existingTagNames,
        suggestedTagNames: tagConfig.suggestedTagNames,
      ),
    );

    if (input == null) {
      return;
    }

    await widget.repository.createRecipe(input);
    await _refreshLibrary();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recipe created.')));
  }

  Future<void> openRecipeEditor({RecipeInput? initialInput}) async {
    await _showCreateRecipeDialog(initialInput: initialInput);
  }

  Future<void> _showEditRecipeDialog(Recipe recipe) async {
    final _EditorTagConfig tagConfig = _buildEditorTagConfig(recipe: recipe);
    final RecipeInput? input = await showDialog<RecipeInput>(
      context: context,
      builder: (context) => _RecipeEditorDialog(
        recipe: recipe,
        existingTagNames: tagConfig.existingTagNames,
        suggestedTagNames: tagConfig.suggestedTagNames,
      ),
    );

    if (input == null) {
      return;
    }

    await widget.repository.updateRecipe(recipe.id, input);
    await _refreshLibrary();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recipe updated.')));
  }

  Future<void> _openRecipeDetail(Recipe recipe) async {
    final bool isPinned = _pinnedRecipeIds.contains(recipe.id);
    final _RecipeDetailResult? result = await Navigator.of(context)
        .push<_RecipeDetailResult>(
          MaterialPageRoute<_RecipeDetailResult>(
            builder: (context) =>
                _RecipeDetailScreen(recipe: recipe, isPinned: isPinned),
          ),
        );

    if (!mounted || result == null) {
      return;
    }

    if (result.action == _RecipeDetailAction.openTag &&
        result.tagName != null) {
      await _applyTagFilterByName(result.tagName!);
      return;
    }

    final _RecipeDetailAction action = result.action;
    if (action == _RecipeDetailAction.edit) {
      await _showEditRecipeDialog(recipe);
      return;
    }

    if (action == _RecipeDetailAction.delete) {
      await _deleteRecipe(recipe);
      return;
    }

    if (action == _RecipeDetailAction.togglePin) {
      await _togglePinned(recipe.id);
    }
  }

  _EditorTagConfig _buildEditorTagConfig({
    Recipe? recipe,
    RecipeInput? initialInput,
  }) {
    final List<String> existingTagNames = _libraryData.tags
        .map((tag) => tag.name)
        .toList();
    final Set<String> selected = recipe == null
        ? <String>{}
        : recipe.tagNames.map((name) => name.toLowerCase()).toSet();
    final LinkedHashSet<String> suggestions = LinkedHashSet<String>();

    for (final String candidate in initialInput?.tagNames ?? const <String>[]) {
      final String cleaned = candidate.trim();
      if (cleaned.isEmpty || selected.contains(cleaned.toLowerCase())) {
        continue;
      }
      suggestions.add(cleaned);
      if (suggestions.length == 3) {
        break;
      }
    }

    if (suggestions.length < 3) {
      final String haystack = [
        recipe?.title,
        initialInput?.title,
        recipe?.description,
        initialInput?.description,
        recipe?.ingredients,
        initialInput?.ingredients,
        recipe?.directions,
        initialInput?.directions,
      ].whereType<String>().join('\n').toLowerCase();

      for (final String tag in existingTagNames) {
        if (suggestions.length == 3) {
          break;
        }
        final String lower = tag.toLowerCase();
        if (selected.contains(lower)) {
          continue;
        }
        if (lower.isNotEmpty && haystack.contains(lower)) {
          suggestions.add(tag);
        }
      }
    }

    return _EditorTagConfig(
      existingTagNames: existingTagNames,
      suggestedTagNames: suggestions.take(3).toList(),
    );
  }

  Future<void> _applyTagFilterByName(String tagName) async {
    final String target = tagName.trim().toLowerCase();
    if (target.isEmpty) {
      return;
    }

    RecipeTag? match;
    for (final RecipeTag tag in _libraryData.tags) {
      if (tag.name.toLowerCase() == target) {
        match = tag;
        break;
      }
    }

    if (match == null) {
      final List<RecipeTag> tags = await widget.repository.listTags();
      for (final RecipeTag tag in tags) {
        if (tag.name.toLowerCase() == target) {
          match = tag;
          break;
        }
      }
    }

    if (!mounted) {
      return;
    }

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find recipes tagged "$tagName".')),
      );
      return;
    }

    setState(() {
      _selectedTagId = match!.id;
      _searchController.clear();
    });
    await _refreshLibrary();
  }

  Future<void> _togglePinned(String recipeId) async {
    final bool currentlyPinned = _pinnedRecipeIds.contains(recipeId);
    await widget.repository.setRecipePinnedForWeek(
      recipeId: recipeId,
      pinned: !currentlyPinned,
      weekStartDate: _weekStartDate,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      if (currentlyPinned) {
        _pinnedRecipeIds.remove(recipeId);
      } else {
        _pinnedRecipeIds.add(recipeId);
      }
    });
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete recipe?'),
          content: Text('Delete "${recipe.title}" from your library?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.repository.deleteRecipe(recipe.id);
    await _refreshLibrary();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recipe deleted.')));
  }

  Future<void> showAddRecipeOptionsDialog() async {
    final _AddRecipeOption?
    option = await showModalBottomSheet<_AddRecipeOption>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Recipe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Import from Web'),
                  subtitle: const Text(
                    'Paste recipe URL and auto-extract details.',
                  ),
                  onTap: () => Navigator.of(context).pop(_AddRecipeOption.web),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Import from Photo'),
                  subtitle: const Text(
                    'Camera or photo library (coming next).',
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_AddRecipeOption.photo),
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Import Paprika File'),
                  subtitle: const Text('Import a .paprikarecipes export file.'),
                  onTap: () =>
                      Navigator.of(context).pop(_AddRecipeOption.paprikaFile),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Manual Entry'),
                  subtitle: const Text('Type recipe fields by hand.'),
                  onTap: () =>
                      Navigator.of(context).pop(_AddRecipeOption.manual),
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (option) {
      case _AddRecipeOption.web:
        await _startWebImportFlow();
        return;
      case _AddRecipeOption.photo:
        await _startPhotoImportFlow();
        return;
      case _AddRecipeOption.paprikaFile:
        await _startPaprikaFileImportFlow();
        return;
      case _AddRecipeOption.manual:
        await _showCreateRecipeDialog();
        return;
      case null:
        return;
    }
  }

  Future<void> _startWebImportFlow() async {
    final String? clipboardUrl = await _readClipboardUrl();

    if (!mounted) {
      return;
    }

    final String? url = await showDialog<String>(
      context: context,
      builder: (context) => _WebImportUrlDialog(initialUrl: clipboardUrl),
    );

    if (url == null) {
      return;
    }

    await importFromWebUrl(url);
  }

  Future<void> importFromWebUrl(String url) async {
    final Uri? parsed = Uri.tryParse(url.trim());
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a valid web URL.')),
        );
      }
      return;
    }

    final String normalizedUrl = parsed.toString();

    final String importJobId = await widget.repository.createImportJob(
      type: ImportJobType.url,
      sourcePayload: normalizedUrl,
    );

    setState(() {
      _isImporting = true;
      _importingLabel = 'Importing recipe from web...';
    });

    try {
      final RecipeInput imported = await _webRecipeImporter.importFromUrl(
        normalizedUrl,
      );
      final String? localThumbnailPath = await _downloadThumbnailToLocal(
        imported.thumbnailUrl,
      );
      final RecipeInput importedInput = RecipeInput(
        title: imported.title,
        description: imported.description,
        ingredients: imported.ingredients,
        directions: imported.directions,
        sourceUrl: imported.sourceUrl,
        thumbnailUrl: imported.thumbnailUrl,
        thumbnailPath: localThumbnailPath ?? imported.thumbnailPath,
        servings: imported.servings,
        totalTimeMinutes: imported.totalTimeMinutes,
        tagNames: imported.tagNames,
        collectionNames: imported.collectionNames,
      );
      await widget.repository.completeImportJobSuccess(
        jobId: importJobId,
        recipeInput: importedInput,
      );

      if (!mounted) {
        return;
      }

      await _showCreateRecipeDialog(initialInput: importedInput);
    } catch (error) {
      await widget.repository.completeImportJobFailure(
        jobId: importJobId,
        errorMessage: error.toString(),
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Web import failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importingLabel = '';
        });
      }
    }
  }

  Future<void> _startPhotoImportFlow() async {
    final String? imagePath = await _pickPhotoForImport();
    if (imagePath == null) {
      return;
    }
    final bool ocrSupported = _capabilities.supportsOcr;
    if (mounted && !ocrSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR is currently available on iOS/Android. On this platform, photo is attached for manual entry.',
          ),
        ),
      );
    }

    final String importJobId = await widget.repository.createImportJob(
      type: ImportJobType.photo,
      sourcePayload: imagePath,
    );

    setState(() {
      _isImporting = true;
      _importingLabel = 'Importing recipe from photo...';
    });

    try {
      final RecipeInput importedInput = await _importFlowService
          .importPhotoFromPath(imagePath);
      await widget.repository.completeImportJobSuccess(
        jobId: importJobId,
        recipeInput: importedInput,
      );

      if (!mounted) {
        return;
      }
      await _showCreateRecipeDialog(initialInput: importedInput);
    } catch (error) {
      await widget.repository.completeImportJobFailure(
        jobId: importJobId,
        errorMessage: error.toString(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo import failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importingLabel = '';
        });
      }
    }
  }

  Future<void> _startPaprikaFileImportFlow() async {
    final XTypeGroup paprikaType = XTypeGroup(
      label: 'paprika',
      extensions: const ['paprikarecipes', 'paprikarecipe'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [paprikaType]);
    if (file == null) {
      return;
    }

    final String importJobId = await widget.repository.createImportJob(
      type: ImportJobType.paprikaFile,
      sourcePayload: file.path,
    );

    setState(() {
      _isImporting = true;
      _importingLabel = 'Importing Paprika recipe...';
    });

    try {
      final List<int> archiveBytes = await file.readAsBytes();
      final RecipeInput importedInput = await _importFlowService
          .importPaprikaFromBytes(archiveBytes, sourceFilePath: file.name);
      await widget.repository.completeImportJobSuccess(
        jobId: importJobId,
        recipeInput: importedInput,
      );

      if (!mounted) {
        return;
      }
      await _showCreateRecipeDialog(initialInput: importedInput);
    } catch (error) {
      await widget.repository.completeImportJobFailure(
        jobId: importJobId,
        errorMessage: error.toString(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Paprika import failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importingLabel = '';
        });
      }
    }
  }

  Future<String?> _pickPhotoForImport() async {
    final bool mobile = _capabilities.supportsImagePicker;
    final _PhotoImportSource? source =
        await showModalBottomSheet<_PhotoImportSource>(
          context: context,
          builder: (context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mobile)
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('Photo Library'),
                      onTap: () =>
                          Navigator.of(context).pop(_PhotoImportSource.gallery),
                    ),
                  if (mobile)
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Take Photo'),
                      onTap: () =>
                          Navigator.of(context).pop(_PhotoImportSource.camera),
                    ),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: Text(mobile ? 'Choose File' : 'Choose Photo File'),
                    onTap: () =>
                        Navigator.of(context).pop(_PhotoImportSource.file),
                  ),
                ],
              ),
            );
          },
        );

    if (source == null) {
      return null;
    }

    if (source == _PhotoImportSource.gallery) {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      return file?.path;
    }

    if (source == _PhotoImportSource.camera) {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      return file?.path;
    }

    final XTypeGroup imageType = XTypeGroup(
      label: 'images',
      extensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [imageType]);
    return file?.path;
  }

  Future<String?> _downloadThumbnailToLocal(String? imageUrl) async {
    final String? raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      return _fileStorage.saveThumbnailBytes(
        response.bodyBytes,
        extensionHint: p.extension(uri.path),
        filenamePrefix: 'thumb',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readClipboardUrl() async {
    final ClipboardData? clipboardData = await Clipboard.getData(
      Clipboard.kTextPlain,
    );
    final String? text = clipboardData?.text?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (_isImporting) const LinearProgressIndicator(minHeight: 3),
        if (_isImporting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _importingLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('library_search_field'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search recipes',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _refreshLibrary();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _refreshLibrary(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _refreshLibrary,
                icon: const Icon(Icons.filter_alt),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
        _FilterChips(
          title: 'Tags',
          selectedId: _selectedTagId,
          items: _libraryData.tags
              .map((tag) => _FilterChipItem(id: tag.id, label: tag.name))
              .toList(),
          onSelected: (value) {
            setState(() {
              _selectedTagId = value;
            });
            _refreshLibrary();
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildRecipeList(),
        ),
      ],
    );
  }

  Widget _buildRecipeList() {
    if (_libraryData.recipes.isEmpty) {
      return ListView(
        children: const <Widget>[
          SizedBox(height: 64),
          Center(
            child: Text(
              'No recipes yet. Add one to get started.',
              key: Key('library_empty_state'),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 220).floor();
        if (crossAxisCount < 2) {
          crossAxisCount = 2;
        }
        if (crossAxisCount > 6) {
          crossAxisCount = 6;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: _libraryData.recipes.length,
          itemBuilder: (context, index) {
            final Recipe recipe = _libraryData.recipes[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openRecipeDetail(recipe),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _RecipeThumbnail(
                              thumbnailPath: recipe.thumbnailPath,
                              thumbnailUrl: recipe.thumbnailUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              tooltip: _pinnedRecipeIds.contains(recipe.id)
                                  ? 'Unpin from This Week'
                                  : 'Pin for This Week',
                              onPressed: () => _togglePinned(recipe.id),
                              icon: Icon(
                                _pinnedRecipeIds.contains(recipe.id)
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _AddRecipeOption { web, photo, paprikaFile, manual }

enum _PhotoImportSource { gallery, camera, file }

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final String title;
  final List<_FilterChipItem> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('All'),
                selected: selectedId == null,
                onSelected: (_) => onSelected(null),
              ),
              ...items.map(
                (item) => ChoiceChip(
                  label: Text(item.label),
                  selected: selectedId == item.id,
                  onSelected: (_) => onSelected(item.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem {
  const _FilterChipItem({required this.id, required this.label});

  final String id;
  final String label;
}

enum _RecipeDetailAction { edit, delete, togglePin, openTag }

class _RecipeDetailResult {
  const _RecipeDetailResult({required this.action, this.tagName});

  final _RecipeDetailAction action;
  final String? tagName;
}

class _EditorTagConfig {
  const _EditorTagConfig({
    required this.existingTagNames,
    required this.suggestedTagNames,
  });

  final List<String> existingTagNames;
  final List<String> suggestedTagNames;
}

class _RecipeThumbnail extends StatelessWidget {
  const _RecipeThumbnail({
    required this.thumbnailPath,
    required this.thumbnailUrl,
    required this.fit,
  });

  final String? thumbnailPath;
  final String? thumbnailUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String? localPath = thumbnailPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final Widget? localImage = buildLocalFileImage(localPath, fit: fit);
      if (localImage != null) {
        return localImage;
      }
    }

    final String? url = thumbnailUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 34),
        ),
      );
    }

    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 34),
          ),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _RecipeDetailScreen extends StatelessWidget {
  const _RecipeDetailScreen({required this.recipe, required this.isPinned});

  final Recipe recipe;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final bool hasIngredients = _hasText(recipe.ingredients);
    final bool hasDirections = _hasText(recipe.directions);

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: isPinned ? 'Unpin' : 'Pin for This Week',
            onPressed: () => Navigator.of(context).pop(
              const _RecipeDetailResult(action: _RecipeDetailAction.togglePin),
            ),
            icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => Navigator.of(context).pop(
              const _RecipeDetailResult(action: _RecipeDetailAction.delete),
            ),
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.of(
              context,
            ).pop(const _RecipeDetailResult(action: _RecipeDetailAction.edit)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _RecipeThumbnail(
                thumbnailPath: recipe.thumbnailPath,
                thumbnailUrl: recipe.thumbnailUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (recipe.servings != null)
                Chip(label: Text('Servings: ${recipe.servings}')),
              if (recipe.totalTimeMinutes != null)
                Chip(label: Text('Time: ${recipe.totalTimeMinutes} min')),
              if (recipe.tagNames.isNotEmpty)
                Text('Tags:', style: Theme.of(context).textTheme.titleMedium),
              ...recipe.tagNames.map(
                (name) => ActionChip(
                  label: Text(name),
                  onPressed: () => Navigator.of(context).pop(
                    _RecipeDetailResult(
                      action: _RecipeDetailAction.openTag,
                      tagName: name,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_hasText(recipe.sourceUrl)) ...[
            const SizedBox(height: 8),
            Text('Source URL', style: Theme.of(context).textTheme.titleSmall),
            SelectableText(recipe.sourceUrl!),
          ],
          _section(
            context: context,
            title: 'Description',
            value: recipe.description,
          ),
          if (hasIngredients || hasDirections) ...[
            const SizedBox(height: 16),
            _ingredientsDirectionsSection(
              context,
              ingredients: recipe.ingredients,
              directions: recipe.directions,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _RecipeDetailResult(action: _RecipeDetailAction.edit)),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Recipe'),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required BuildContext context,
    required String title,
    required String? value,
  }) {
    if (!_hasText(value)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(value!.trim()),
        ],
      ),
    );
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  Widget _ingredientsDirectionsSection(
    BuildContext context, {
    required String? ingredients,
    required String? directions,
  }) {
    final bool hasIngredients = _hasText(ingredients);
    final bool hasDirections = _hasText(directions);
    final bool wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _sectionCard(
              context: context,
              title: 'Ingredients',
              value: hasIngredients ? ingredients! : 'No ingredients yet.',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _sectionCard(
              context: context,
              title: 'Directions',
              value: hasDirections ? directions! : 'No directions yet.',
            ),
          ),
        ],
      );
    }

    if (hasIngredients && hasDirections) {
      return DefaultTabController(
        length: 2,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            height: 360,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Ingredients'),
                    Tab(text: 'Directions'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _scrollingText(ingredients!),
                      _scrollingText(directions!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _sectionCard(
      context: context,
      title: hasIngredients ? 'Ingredients' : 'Directions',
      value: hasIngredients ? ingredients! : directions!,
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(padding: const EdgeInsets.all(10), child: Text(value.trim())),
        ],
      ),
    );
  }

  Widget _scrollingText(String value) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Text(value.trim()),
    );
  }
}

class _WebImportUrlDialog extends StatefulWidget {
  const _WebImportUrlDialog({this.initialUrl});

  final String? initialUrl;

  @override
  State<_WebImportUrlDialog> createState() => _WebImportUrlDialogState();
}

class _WebImportUrlDialogState extends State<_WebImportUrlDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasClipboardUrl = widget.initialUrl != null;

    return AlertDialog(
      title: const Text('Import from Web'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasClipboardUrl)
              const Text(
                'Found a URL in your clipboard. Use it or paste another URL.',
              ),
            if (hasClipboardUrl) const SizedBox(height: 12),
            TextFormField(
              key: const Key('web_import_url_field'),
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Recipe URL',
                hintText: 'https://example.com/recipe',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final String raw = value?.trim() ?? '';
                final Uri? uri = Uri.tryParse(raw);
                if (uri == null ||
                    (uri.scheme != 'http' && uri.scheme != 'https')) {
                  return 'Enter a valid web URL';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('web_import_submit_button'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(_urlController.text.trim());
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _RecipeEditorDialog extends StatefulWidget {
  const _RecipeEditorDialog({
    required this.existingTagNames,
    required this.suggestedTagNames,
    this.recipe,
    this.initialInput,
  }) : assert(recipe == null || initialInput == null);

  final Recipe? recipe;
  final RecipeInput? initialInput;
  final List<String> existingTagNames;
  final List<String> suggestedTagNames;

  @override
  State<_RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends State<_RecipeEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _directionsController;
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _thumbnailUrlController;
  late final TextEditingController _servingsController;
  late final TextEditingController _totalTimeController;
  TextEditingController? _tagEntryFieldController;
  late final List<String> _selectedTags;
  late final List<String> _knownTagNames;
  late final List<String> _suggestedTagNames;
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    final Recipe? recipe = widget.recipe;
    final RecipeInput? initialInput = widget.initialInput;

    _titleController = TextEditingController(
      text: recipe?.title ?? initialInput?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: recipe?.description ?? initialInput?.description ?? '',
    );
    _ingredientsController = TextEditingController(
      text: recipe?.ingredients ?? initialInput?.ingredients ?? '',
    );
    _directionsController = TextEditingController(
      text: recipe?.directions ?? initialInput?.directions ?? '',
    );
    _sourceUrlController = TextEditingController(
      text: recipe?.sourceUrl ?? initialInput?.sourceUrl ?? '',
    );
    _thumbnailUrlController = TextEditingController(
      text: recipe?.thumbnailUrl ?? initialInput?.thumbnailUrl ?? '',
    );
    _thumbnailPath = recipe?.thumbnailPath ?? initialInput?.thumbnailPath;
    _servingsController = TextEditingController(
      text:
          recipe?.servings?.toString() ??
          initialInput?.servings?.toString() ??
          '',
    );
    _totalTimeController = TextEditingController(
      text:
          recipe?.totalTimeMinutes?.toString() ??
          initialInput?.totalTimeMinutes?.toString() ??
          '',
    );
    _selectedTags = recipe?.tagNames.toList() ?? <String>[];
    _knownTagNames = _dedupeByLower(widget.existingTagNames);
    _suggestedTagNames = _dedupeByLower(
      widget.suggestedTagNames,
    ).where((tag) => !_containsTag(_selectedTags, tag)).take(3).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _directionsController.dispose();
    _sourceUrlController.dispose();
    _thumbnailUrlController.dispose();
    _servingsController.dispose();
    _totalTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.recipe != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Recipe' : 'New Recipe'),
      content: SizedBox(
        width: 980,
        height: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  key: const Key('recipe_form_title'),
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  key: const Key('recipe_form_source_url'),
                  controller: _sourceUrlController,
                  decoration: const InputDecoration(labelText: 'Source URL'),
                ),
                const SizedBox(height: 10),
                _buildThumbnailEditor(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        key: const Key('recipe_form_servings'),
                        controller: _servingsController,
                        decoration: const InputDecoration(
                          labelText: 'Servings',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('recipe_form_total_time'),
                        controller: _totalTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Total mins',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTagsEditor(context),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool useSingleColumn = constraints.maxWidth < 780;
                    if (useSingleColumn) {
                      return Column(
                        children: [
                          _buildTextSection(
                            title: 'Ingredients',
                            fieldKey: const Key('recipe_form_ingredients'),
                            controller: _ingredientsController,
                            hintText: '1 lb pasta\\n2 cups broth',
                            minLines: 8,
                          ),
                          const SizedBox(height: 12),
                          _buildTextSection(
                            title: 'Description',
                            fieldKey: const Key('recipe_form_description'),
                            controller: _descriptionController,
                            hintText: 'Recipe notes, context, or summary.',
                            minLines: 5,
                          ),
                          const SizedBox(height: 12),
                          _buildTextSection(
                            title: 'Directions',
                            fieldKey: const Key('recipe_form_directions'),
                            controller: _directionsController,
                            hintText: '1. Prep ingredients\\n2. Cook and serve',
                            minLines: 10,
                          ),
                        ],
                      );
                    }

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _buildTextSection(
                              title: 'Ingredients',
                              fieldKey: const Key('recipe_form_ingredients'),
                              controller: _ingredientsController,
                              hintText: '1 lb pasta\\n2 cups broth',
                              minLines: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildTextSection(
                                  title: 'Description',
                                  fieldKey: const Key(
                                    'recipe_form_description',
                                  ),
                                  controller: _descriptionController,
                                  hintText:
                                      'Recipe notes, context, or summary.',
                                  minLines: 6,
                                ),
                                const SizedBox(height: 12),
                                _buildTextSection(
                                  title: 'Directions',
                                  fieldKey: const Key('recipe_form_directions'),
                                  controller: _directionsController,
                                  hintText:
                                      '1. Prep ingredients\\n2. Cook and serve',
                                  minLines: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('recipe_form_save'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              RecipeInput(
                title: _titleController.text,
                description: _descriptionController.text,
                ingredients: _ingredientsController.text,
                directions: _directionsController.text,
                sourceUrl: _sourceUrlController.text,
                thumbnailUrl: _thumbnailUrlController.text,
                thumbnailPath: _thumbnailPath,
                servings: _parseOptionalInt(_servingsController.text),
                totalTimeMinutes: _parseOptionalInt(_totalTimeController.text),
                tagNames: _selectedTags,
                collectionNames: const <String>[],
              ),
            );
          },
          child: Text(isEditing ? 'Save changes' : 'Create recipe'),
        ),
      ],
    );
  }

  Widget _buildThumbnailEditor() {
    final bool canUseImagePicker = _capabilities.supportsImagePicker;
    final bool canUseCamera = _capabilities.supportsCamera;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thumbnail', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _RecipeThumbnail(
                thumbnailPath: _thumbnailPath,
                thumbnailUrl: _thumbnailUrlController.text,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickThumbnailFromFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select File'),
              ),
              if (canUseImagePicker)
                OutlinedButton.icon(
                  onPressed: _pickThumbnailFromPhotoLibrary,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Photo Library'),
                ),
              if (canUseCamera)
                OutlinedButton.icon(
                  onPressed: _pickThumbnailFromCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take Photo'),
                ),
              TextButton(
                onPressed: _setThumbnailFromUrl,
                child: const Text('Use URL'),
              ),
              if ((_thumbnailPath ?? '').isNotEmpty ||
                  _thumbnailUrlController.text.trim().isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _thumbnailPath = null;
                      _thumbnailUrlController.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickThumbnailFromFile() async {
    final XTypeGroup imageType = XTypeGroup(
      label: 'images',
      extensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [imageType]);
    if (file == null) {
      return;
    }

    await _setThumbnailFromLocalPath(file.path);
  }

  Future<void> _pickThumbnailFromPhotoLibrary() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (photo == null) {
      return;
    }
    await _setThumbnailFromLocalPath(photo.path);
  }

  Future<void> _pickThumbnailFromCamera() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (photo == null) {
      return;
    }
    await _setThumbnailFromLocalPath(photo.path);
  }

  Future<void> _setThumbnailFromLocalPath(String inputPath) async {
    try {
      final Uint8List bytes = await _fileStorage.readAsBytes(inputPath);
      final String savedPath = await _fileStorage.saveThumbnailBytes(
        bytes: bytes,
        extensionHint: p.extension(inputPath),
        filenamePrefix: 'thumb',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _thumbnailPath = savedPath;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set thumbnail: $error')),
      );
    }
  }

  Future<void> _setThumbnailFromUrl() async {
    final TextEditingController controller = TextEditingController(
      text: _thumbnailUrlController.text,
    );
    final String? url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thumbnail URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/image.jpg',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Use URL'),
            ),
          ],
        );
      },
    );

    if (url == null || url.isEmpty) {
      return;
    }

    _thumbnailUrlController.text = url;
    try {
      final Uri uri = Uri.parse(url);
      final http.Response response = await http.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String savedPath = await _fileStorage.saveThumbnailBytes(
          response.bodyBytes,
          extensionHint: p.extension(uri.path),
          filenamePrefix: 'thumb',
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _thumbnailPath = savedPath;
        });
      }
    } catch (_) {
      // Keep URL for fallback even if local download fails.
      if (mounted) {
        setState(() {});
      }
    }
  }

  int? _parseOptionalInt(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    return int.tryParse(value.trim());
  }

  List<String> _dedupeByLower(Iterable<String> names) {
    final List<String> unique = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in names) {
      final String cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.isEmpty) {
        continue;
      }
      final String lower = cleaned.toLowerCase();
      if (seen.add(lower)) {
        unique.add(cleaned);
      }
    }
    return unique;
  }

  bool _containsTag(List<String> names, String candidate) {
    final String lower = candidate.trim().toLowerCase();
    if (lower.isEmpty) {
      return false;
    }
    for (final String name in names) {
      if (name.toLowerCase() == lower) {
        return true;
      }
    }
    return false;
  }

  void _addTag(String raw) {
    final String cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty || _containsTag(_selectedTags, cleaned)) {
      return;
    }
    setState(() {
      _selectedTags.add(cleaned);
      if (!_containsTag(_knownTagNames, cleaned)) {
        _knownTagNames.add(cleaned);
      }
      _suggestedTagNames.removeWhere(
        (tag) => tag.toLowerCase() == cleaned.toLowerCase(),
      );
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.removeWhere(
        (existing) => existing.toLowerCase() == tag.toLowerCase(),
      );
    });
  }

  Widget _buildTagsEditor(BuildContext context) {
    final List<String> availableSuggestions = _suggestedTagNames
        .where((tag) => !_containsTag(_selectedTags, tag))
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (_selectedTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags
                .map(
                  (tag) => InputChip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                  ),
                )
                .toList(),
          ),
        if (_selectedTags.isNotEmpty) const SizedBox(height: 8),
        if (availableSuggestions.isNotEmpty) ...[
          Text(
            'Suggested tags (optional)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSuggestions
                .map(
                  (tag) => ActionChip(
                    label: Text(tag),
                    onPressed: () => _addTag(tag),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue value) {
            final String query = value.text.trim().toLowerCase();
            if (query.isEmpty) {
              return const Iterable<String>.empty();
            }

            return _knownTagNames
                .where((tag) {
                  final String lower = tag.toLowerCase();
                  return lower.contains(query) &&
                      !_containsTag(_selectedTags, tag);
                })
                .take(8);
          },
          onSelected: (String value) {
            _addTag(value);
            _tagEntryFieldController?.clear();
          },
          fieldViewBuilder:
              (
                context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                _tagEntryFieldController = textEditingController;
                return TextField(
                  key: const Key('recipe_form_tag_input'),
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Add tag',
                    hintText: 'Type to see existing tags',
                    suffixIcon: IconButton(
                      onPressed: () {
                        _addTag(textEditingController.text);
                        textEditingController.clear();
                        focusNode.requestFocus();
                      },
                      icon: const Icon(Icons.add),
                      tooltip: 'Add tag',
                    ),
                  ),
                  onSubmitted: (_) {
                    _addTag(textEditingController.text);
                    textEditingController.clear();
                    onFieldSubmitted();
                  },
                );
              },
        ),
      ],
    );
  }

  Widget _buildTextSection({
    required String title,
    required Key fieldKey,
    required TextEditingController controller,
    required String hintText,
    required int minLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          TextField(
            key: fieldKey,
            controller: controller,
            minLines: minLines,
            maxLines: minLines,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}
