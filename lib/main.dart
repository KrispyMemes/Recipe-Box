import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data/app_database.dart';
import 'data/recipe_repository.dart';
import 'features/import/import_center_screen.dart';
import 'features/shopping/shopping_screen.dart';
import 'features/library/library_screen.dart';
import 'features/week/this_week_screen.dart';
import 'models/recipe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.initialize();
  runApp(const RecipeApp());
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E6F40)),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.recipeRepository});

  final RecipeRepository? recipeRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const MethodChannel _deepLinkChannel = MethodChannel(
    'recipe_app/deep_link',
  );
  int _selectedIndex = 0;
  RecipeRepository? _repository;
  bool _deepLinkChannelInitialized = false;
  final GlobalKey<LibraryScreenState> _libraryScreenKey =
      GlobalKey<LibraryScreenState>();

  @override
  void initState() {
    super.initState();
    if (widget.recipeRepository != null) {
      _repository = widget.recipeRepository;
      _initializeDeepLinkHandling();
      return;
    }

    _initRepository();
  }

  Future<void> _initRepository() async {
    final RecipeRepository repository = RecipeRepository(
      db: await AppDatabase.instance.database,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _repository = repository;
    });
    _initializeDeepLinkHandling();
  }

  Future<void> _initializeDeepLinkHandling() async {
    if (kIsWeb) {
      return;
    }

    if (_deepLinkChannelInitialized) {
      return;
    }
    _deepLinkChannelInitialized = true;

    _deepLinkChannel.setMethodCallHandler(_handleDeepLinkMethodCall);

    final List<dynamic>? pending = await _deepLinkChannel
        .invokeListMethod<dynamic>('getPendingUrls');
    if (!mounted || pending == null || pending.isEmpty) {
      return;
    }

    for (final dynamic entry in pending) {
      final String? raw = entry as String?;
      if (raw != null) {
        await _handleIncomingDeepLink(raw);
      }
    }
  }

  Future<void> _handleDeepLinkMethodCall(MethodCall call) async {
    if (call.method != 'onIncomingUrl') {
      return;
    }

    final String? raw = call.arguments as String?;
    if (raw == null) {
      return;
    }

    await _handleIncomingDeepLink(raw);
  }

  Future<void> _handleIncomingDeepLink(String rawUrl) async {
    final String? targetRecipeUrl = _extractRecipeUrlFromDeepLink(rawUrl);
    if (!mounted || targetRecipeUrl == null) {
      return;
    }

    setState(() {
      _selectedIndex = 0;
    });

    final LibraryScreenState? library = await _waitForLibraryScreen();
    if (!mounted || library == null) {
      return;
    }
    await library.importFromWebUrl(targetRecipeUrl);
  }

  Future<LibraryScreenState?> _waitForLibraryScreen() async {
    for (int i = 0; i < 20; i++) {
      final LibraryScreenState? state = _libraryScreenKey.currentState;
      if (state != null) {
        return state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return _libraryScreenKey.currentState;
  }

  String? _extractRecipeUrlFromDeepLink(String rawUrl) {
    final Uri? incoming = Uri.tryParse(rawUrl);
    if (incoming == null) {
      return null;
    }

    if (incoming.scheme == 'recipeapp') {
      final String host = incoming.host.toLowerCase();
      if (host != 'import' && host != 'save') {
        return null;
      }

      final String? value =
          incoming.queryParameters['url'] ?? incoming.queryParameters['u'];
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    }

    if (incoming.hasScheme &&
        (incoming.scheme == 'http' || incoming.scheme == 'https')) {
      return incoming.toString();
    }

    return null;
  }

  List<_AppDestination> _buildDestinations() {
    if (_repository == null) {
      return const <_AppDestination>[
        _AppDestination(
          label: 'Recipe Box',
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book,
          page: Center(child: CircularProgressIndicator()),
        ),
        _AppDestination(
          label: 'This Week',
          icon: Icons.push_pin_outlined,
          selectedIcon: Icons.push_pin,
          page: Center(child: CircularProgressIndicator()),
        ),
        _AppDestination(
          label: 'Shopping',
          icon: Icons.shopping_cart_outlined,
          selectedIcon: Icons.shopping_cart,
          page: Center(child: CircularProgressIndicator()),
        ),
        _AppDestination(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          page: _PlaceholderScreen(
            title: 'Settings',
            subtitle: 'Manage sync, account, and app preferences.',
          ),
        ),
      ];
    }

    return <_AppDestination>[
      _AppDestination(
        label: 'Recipe Box',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        page: LibraryScreen(key: _libraryScreenKey, repository: _repository!),
      ),
      _AppDestination(
        label: 'This Week',
        icon: Icons.push_pin_outlined,
        selectedIcon: Icons.push_pin,
        page: ThisWeekScreen(repository: _repository!),
      ),
      _AppDestination(
        label: 'Shopping',
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart,
        page: ShoppingScreen(repository: _repository!),
      ),
      const _AppDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        page: _PlaceholderScreen(
          title: 'Settings',
          subtitle: 'Manage sync, account, and app preferences.',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<_AppDestination> destinations = _buildDestinations();
    final _AppDestination active = destinations[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideLayout = constraints.maxWidth >= 900;
        final Widget currentPage = active.page;

        if (isWideLayout) {
          return Scaffold(
            appBar: AppBar(
              title: Text(active.label),
              actions: _buildAppBarActions(),
            ),
            floatingActionButton: _buildFab(),
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: currentPage),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(active.label),
            actions: _buildAppBarActions(),
          ),
          floatingActionButton: _buildFab(),
          body: currentPage,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: destinations
                .map(
                  (destination) => NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget? _buildFab() {
    if (_selectedIndex != 0 || _repository == null) {
      return null;
    }

    return FloatingActionButton.extended(
      key: const Key('recipe_box_add_fab'),
      onPressed: () {
        _libraryScreenKey.currentState?.showAddRecipeOptionsDialog();
      },
      icon: const Icon(Icons.add),
      label: const Text('Add Recipe'),
    );
  }

  List<Widget>? _buildAppBarActions() {
    if (_selectedIndex != 0 || _repository == null) {
      return null;
    }

    return <Widget>[
      IconButton(
        tooltip: 'Import Center',
        icon: const Icon(Icons.inbox_outlined),
        onPressed: () async {
          final RecipeInput? selectedImport = await Navigator.of(context)
              .push<RecipeInput>(
                MaterialPageRoute<RecipeInput>(
                  builder: (context) =>
                      ImportCenterScreen(repository: _repository!),
                ),
              );

          if (selectedImport != null && mounted) {
            await _libraryScreenKey.currentState?.openRecipeEditor(
              initialInput: selectedImport,
            );
          }
        },
      ),
    ];
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
