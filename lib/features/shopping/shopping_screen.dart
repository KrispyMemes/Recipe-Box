import 'package:flutter/material.dart';

import '../../data/recipe_repository.dart';
import '../../models/weekly_planning.dart';
import 'walmart_guided_checkout_screen.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({required this.repository, super.key});

  final RecipeRepository repository;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final String _weekStartDate = RecipeRepository.weekStartDateFor(
    DateTime.now(),
  );
  final TextEditingController _customItemController = TextEditingController();
  bool _isLoading = true;
  List<ShoppingListItemModel> _items = const <ShoppingListItemModel>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _customItemController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    await widget.repository.regenerateShoppingListFromPinnedRecipes(
      weekStartDate: _weekStartDate,
    );
    final List<ShoppingListItemModel> items = await widget.repository
        .listShoppingItemsForWeek(weekStartDate: _weekStartDate);

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _addCustomItem() async {
    final String itemName = _customItemController.text.trim();
    if (itemName.isEmpty) {
      return;
    }

    await widget.repository.addCustomShoppingItem(
      itemName: itemName,
      weekStartDate: _weekStartDate,
    );

    _customItemController.clear();
    await _refresh();
  }

  Future<void> _toggleChecked(ShoppingListItemModel item) async {
    if (!item.isCustom && !item.checked) {
      await widget.repository.markShoppingItemPurchased(item.id);
      await _refresh();
      return;
    }

    await widget.repository.toggleShoppingItemChecked(
      itemId: item.id,
      checked: !item.checked,
    );
    await _refresh();
  }

  Future<void> _deleteItem(ShoppingListItemModel item) async {
    await widget.repository.deleteShoppingItem(item.id);
    await _refresh();
  }

  Future<void> _openGuidedCheckout() async {
    final List<ShoppingListItemModel> unresolved = _items
        .where((item) => !item.checked)
        .toList();
    if (unresolved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unchecked shopping items for the assistant.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => WalmartGuidedCheckoutScreen(
          repository: widget.repository,
          shoppingItems: _items,
        ),
      ),
    );

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openGuidedCheckout,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Start Walmart+ Shopping Assistant'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customItemController,
                  decoration: const InputDecoration(
                    labelText: 'Add custom item',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCustomItem(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addCustomItem, child: const Text('Add')),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No shopping items yet. Add recipes to This Week to generate your list.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ShoppingListItemModel item = _items[index];
                    return CheckboxListTile(
                      dense: true,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -3,
                      ),
                      value: item.checked,
                      onChanged: (_) => _toggleChecked(item),
                      title: Text(
                        item.itemName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.05,
                        ),
                      ),
                      secondary: IconButton(
                        tooltip: 'Delete item',
                        onPressed: () => _deleteItem(item),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
