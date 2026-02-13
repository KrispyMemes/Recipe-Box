import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/recipe_repository.dart';
import '../../models/recipe.dart';

class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({required this.repository, super.key});

  final RecipeRepository repository;

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  final String _weekStartDate = RecipeRepository.weekStartDateFor(
    DateTime.now(),
  );
  bool _isLoading = true;
  List<Recipe> _pinnedRecipes = const <Recipe>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    final List<Recipe> recipes = await widget.repository
        .listPinnedRecipesForWeek(weekStartDate: _weekStartDate);

    if (!mounted) {
      return;
    }

    setState(() {
      _pinnedRecipes = recipes;
      _isLoading = false;
    });
  }

  Future<void> _unpin(String recipeId) async {
    await widget.repository.setRecipePinnedForWeek(
      recipeId: recipeId,
      pinned: false,
      weekStartDate: _weekStartDate,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pinnedRecipes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No recipes pinned yet. Pin recipes from Recipe Box to build your week.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pinnedRecipes.length,
        itemBuilder: (context, index) {
          final Recipe recipe = _pinnedRecipes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.push_pin),
              title: Text(recipe.title),
              subtitle: recipe.totalTimeMinutes == null
                  ? null
                  : Text('${recipe.totalTimeMinutes} min'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ThisWeekRecipeDetailScreen(recipe: recipe),
                  ),
                );
              },
              trailing: IconButton(
                tooltip: 'Remove from This Week',
                onPressed: () => _unpin(recipe.id),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThisWeekRecipeDetailScreen extends StatelessWidget {
  const _ThisWeekRecipeDetailScreen({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final bool hasIngredients = _hasText(recipe.ingredients);
    final bool hasDirections = _hasText(recipe.directions);

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _RecipeThumb(
                thumbnailPath: recipe.thumbnailPath,
                thumbnailUrl: recipe.thumbnailUrl,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (recipe.servings != null)
                Chip(label: Text('Servings: ${recipe.servings}')),
              if (recipe.totalTimeMinutes != null)
                Chip(label: Text('Time: ${recipe.totalTimeMinutes} min')),
              ...recipe.tagNames.map((tag) => Chip(label: Text('Tag: $tag'))),
            ],
          ),
          if (_hasText(recipe.description))
            _section('Description', recipe.description!),
          if (hasIngredients || hasDirections) ...[
            const SizedBox(height: 16),
            _ingredientsDirectionsBlock(
              context,
              ingredients: recipe.ingredients,
              directions: recipe.directions,
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value.trim()),
        ],
      ),
    );
  }

  Widget _ingredientsDirectionsBlock(
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
            child: _panel(
              context: context,
              title: 'Ingredients',
              value: hasIngredients ? ingredients! : 'No ingredients yet.',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _panel(
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

    return _panel(
      context: context,
      title: hasIngredients ? 'Ingredients' : 'Directions',
      value: hasIngredients ? ingredients! : directions!,
    );
  }

  Widget _panel({
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

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _RecipeThumb extends StatelessWidget {
  const _RecipeThumb({required this.thumbnailPath, required this.thumbnailUrl});

  final String? thumbnailPath;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final String? localPath = thumbnailPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final File localFile = File(localPath);
      if (localFile.existsSync()) {
        return Image.file(localFile, fit: BoxFit.cover);
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
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 34),
          ),
        );
      },
    );
  }
}
