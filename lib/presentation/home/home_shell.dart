import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_assets.dart';
import '../../widgets/app_background.dart';
import '../catalog/catalog_screen.dart';
import '../diary/diary_screen.dart';
import '../games/games_screen.dart';
import '../generator/generator_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DiaryScreen(),
    CatalogScreen(),
    GeneratorScreen(),
    GamesScreen(),
    ProfileScreen(),
  ];

  /// Фон для каждой вкладки (по порядку вкладок)
  static const _backgrounds = <String>[
    AppAssets.grass1,
    AppAssets.grass2,
    AppAssets.grass3,
    AppAssets.grass2,
    AppAssets.grass1,
  ];

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      asset: _backgrounds[_index],
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Каталог',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'Генератор',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports_rounded),
            label: 'Игры',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}