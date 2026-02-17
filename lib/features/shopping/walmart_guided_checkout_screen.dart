import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/recipe_repository.dart';
import '../../models/weekly_planning.dart';
import '../../services/platform/platform_capability_service.dart';
import 'walmart_assist.dart';

class WalmartGuidedCheckoutScreen extends StatefulWidget {
  const WalmartGuidedCheckoutScreen({
    required this.repository,
    required this.shoppingItems,
    super.key,
  });

  final RecipeRepository repository;
  final List<ShoppingListItemModel> shoppingItems;

  @override
  State<WalmartGuidedCheckoutScreen> createState() =>
      _WalmartGuidedCheckoutScreenState();
}

class _WalmartGuidedCheckoutScreenState
    extends State<WalmartGuidedCheckoutScreen> {
  WebViewController? _webViewController;
  late final List<ShoppingListItemModel> _orderedItems;
  late final bool _embeddedBrowserSupported;
  final PlatformCapabilityService _capabilities = createPlatformCapabilityService();

  _GuidedStep _step = _GuidedStep.setup;
  String? _activeItemId;
  final Set<String> _openedItemIds = <String>{};
  final Set<String> _addedItemIds = <String>{};
  final Set<String> _skippedItemIds = <String>{};
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _embeddedBrowserSupported = _capabilities.supportsEmbeddedBrowser;
    _orderedItems = List<ShoppingListItemModel>.from(
      widget.shoppingItems.where((item) => !item.checked),
    );
    if (_embeddedBrowserSupported) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate())
        ..loadRequest(Uri.parse(WalmartAssist.walmartHomeUrl));
    }
  }

  List<ShoppingListItemModel> get _pendingItems {
    return _orderedItems.where((item) {
      if (_addedItemIds.contains(item.id)) {
        return false;
      }
      if (_skippedItemIds.contains(item.id)) {
        return false;
      }
      return true;
    }).toList();
  }

  ShoppingListItemModel? get _activeItem {
    final String? id = _activeItemId;
    if (id == null) {
      return null;
    }
    for (final ShoppingListItemModel item in _orderedItems) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openWalmartHome() async {
    if (_webViewController != null) {
      await _webViewController!.loadRequest(
        Uri.parse(WalmartAssist.walmartHomeUrl),
      );
      return;
    }
    await launchUrl(
      Uri.parse(WalmartAssist.walmartHomeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openCart() async {
    if (_webViewController != null) {
      await _webViewController!.loadRequest(
        Uri.parse('https://www.walmart.com/cart'),
      );
      return;
    }
    await _openExternalWalmartCart();
  }

  Future<void> _startGuidedItems() async {
    if (_pendingItems.isEmpty) {
      setState(() {
        _step = _GuidedStep.finish;
      });
      return;
    }

    final ShoppingListItemModel first = _pendingItems.first;
    setState(() {
      _step = _GuidedStep.items;
      _activeItemId = first.id;
    });
    await _searchForItem(first);
  }

  Future<void> _searchForItem(ShoppingListItemModel item) async {
    final String url = WalmartAssist.buildSearchUrl(item.itemName);
    setState(() {
      _openedItemIds.add(item.id);
    });
    if (_webViewController != null) {
      await _webViewController!.loadRequest(Uri.parse(url));
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _searchActiveItemAgain() async {
    final ShoppingListItemModel? item = _activeItem;
    if (item == null) {
      return;
    }
    await _searchForItem(item);
  }

  Future<void> _markAddedAndNext() async {
    final ShoppingListItemModel? item = _activeItem;
    if (item == null) {
      return;
    }
    if (_isWorking) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.repository.markShoppingItemPurchased(item.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _addedItemIds.add(item.id);
      });
      await _advanceToNextItem();
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _markSkippedAndNext() async {
    final ShoppingListItemModel? item = _activeItem;
    if (item == null) {
      return;
    }

    setState(() {
      _skippedItemIds.add(item.id);
    });
    await _advanceToNextItem();
  }

  Future<void> _advanceToNextItem() async {
    final List<ShoppingListItemModel> pending = _pendingItems;
    if (pending.isEmpty) {
      setState(() {
        _activeItemId = null;
        _step = _GuidedStep.finish;
      });
      return;
    }

    final ShoppingListItemModel next = pending.first;
    setState(() {
      _activeItemId = next.id;
    });
    await _searchForItem(next);
  }

  Future<void> _openExternalWalmartCart() async {
    await launchUrl(
      Uri.parse('https://www.walmart.com/cart'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walmart+ Guided Checkout')),
      body: Column(
        children: [
          _buildStepHeader(),
          const Divider(height: 1),
          Expanded(
            child: switch (_step) {
              _GuidedStep.setup => _buildSetupStep(),
              _GuidedStep.items => _buildItemStep(),
              _GuidedStep.finish => _buildFinishStep(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    Widget stepChip(_GuidedStep step, String label) {
      final bool selected = _step == step;
      return Chip(
        label: Text(label),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          stepChip(_GuidedStep.setup, '1. Setup'),
          stepChip(_GuidedStep.items, '2. Add Items'),
          stepChip(_GuidedStep.finish, '3. Checkout'),
        ],
      ),
    );
  }

  Widget _buildSetupStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Before you start',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Sign in to Walmart.\n'
            '2. Confirm delivery or pickup method.\n'
            '3. Confirm your store/location.\n'
            'Then continue to guided item entry.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openWalmartHome,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Walmart Home In Panel'),
              ),
              FilledButton.icon(
                onPressed: _startGuidedItems,
                icon: const Icon(Icons.play_arrow),
                label: const Text('I’m Ready'),
              ),
              if (!_embeddedBrowserSupported)
                const Chip(label: Text('External Browser Mode')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBrowserPanel()),
        ],
      ),
    );
  }

  Widget _buildItemStep() {
    final ShoppingListItemModel? current = _activeItem;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool sideBySide =
            constraints.maxWidth > 900 &&
            constraints.maxWidth > constraints.maxHeight * 1.2;
        final Widget panel = _buildItemPanel(current);
        final Widget browser = Padding(
          padding: const EdgeInsets.all(8),
          child: _buildBrowserPanel(),
        );

        if (sideBySide) {
          return Row(
            children: [
              SizedBox(width: constraints.maxWidth * 0.34, child: panel),
              const VerticalDivider(width: 1),
              Expanded(child: browser),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: browser),
            const Divider(height: 1),
            SizedBox(height: constraints.maxHeight * 0.36, child: panel),
          ],
        );
      },
    );
  }

  Widget _buildItemPanel(ShoppingListItemModel current) {
    final int total = _orderedItems.length;
    final int added = _addedItemIds.length;
    final int skipped = _skippedItemIds.length;
    final int pending = _pendingItems.length;
    final String query = WalmartAssist.normalizeQuery(current.itemName);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: [
              Text(
                'Current Item',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                current.itemName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (current.quantityText != null &&
                  current.quantityText!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Quantity: ${current.quantityText}'),
              ],
              const SizedBox(height: 8),
              Text('Search query: $query'),
              const SizedBox(height: 12),
              Text(
                'Progress: Added $added • Skipped $skipped • Pending $pending • Total $total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _searchActiveItemAgain,
                    icon: const Icon(Icons.search),
                    label: const Text('Search Again'),
                  ),
                  FilledButton.icon(
                    onPressed: _isWorking ? null : _markAddedAndNext,
                    icon: const Icon(Icons.check),
                    label: const Text('Added to Cart + Next'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : _markSkippedAndNext,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip + Next'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openCart,
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Open Cart In Panel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishStep() {
    final int added = _addedItemIds.length;
    final int skipped = _skippedItemIds.length;
    final int unresolved = _pendingItems.length;
    final bool complete = unresolved == 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finish Checkout',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'All guided items were processed. Review cart, delivery time, substitutions, and submit your Walmart order.'
                : 'Some items are still unresolved. You can return to item flow or continue checkout manually.',
          ),
          const SizedBox(height: 12),
          Text('Added: $added'),
          Text('Skipped: $skipped'),
          Text('Unresolved: $unresolved'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openCart,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Open Cart In Panel'),
              ),
              OutlinedButton.icon(
                onPressed: _openExternalWalmartCart,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Cart In Browser'),
              ),
              if (!complete)
                FilledButton.icon(
                  onPressed: () async {
                    setState(() {
                      _step = _GuidedStep.items;
                      _activeItemId = _pendingItems.isEmpty
                          ? null
                          : _pendingItems.first.id;
                    });
                    if (_activeItem != null) {
                      await _searchActiveItemAgain();
                    }
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Resume Items'),
                ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBrowserPanel()),
        ],
      ),
    );
  }

  Widget _buildBrowserPanel() {
    if (_webViewController == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Embedded browser not supported on this platform.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use external browser mode. The guided item flow still works.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openExternalWalmartCart,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Walmart Cart'),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: WebViewWidget(controller: _webViewController!),
    );
  }
}

enum _GuidedStep { setup, items, finish }
