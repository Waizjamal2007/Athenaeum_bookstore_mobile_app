
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class AppShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onIndex;
  final Widget child;

  const AppShell({
    super.key,
    required this.index,
    required this.onIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['Home', 'Catalog', 'Search', 'Wishlist', 'Profile'];
    final icons = [
      Icons.home_outlined,
      Icons.grid_view_outlined,
      Icons.search,
      Icons.bookmark_border,
      Icons.person_outline,
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'storeNotifications', tooltip: 'Notifications',
        onPressed: () => Navigator.pushNamed(context, '/notifications'),
        child: const Icon(Icons.notifications_outlined)),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(index), child: child),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: index,
        onDestinationSelected: onIndex,
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(
            icon: Icon(icons[i], size: 20),
            selectedIcon: Icon(icons[i], size: 21),
            label: labels[i],
          ),
        ),
      ),
    );
  }
}
