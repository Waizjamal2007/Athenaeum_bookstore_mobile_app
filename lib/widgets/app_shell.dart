import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'motion.dart';

const storeRoutes = ['/home', '/catalog', '/search', '/wishlist', '/profile'];

void openStoreTab(BuildContext context, int index) {
  Navigator.pushNamedAndRemoveUntil(context, storeRoutes[index], (_) => false);
}

PreferredSizeWidget storeAppBar(
  BuildContext context,
  String title, {
  Widget? leading,
  List<Widget> actions = const [],
}) => AppBar(
  title: Text(title),
  leading: leading,
  actions: [
    ...actions,
    IconButton(
      tooltip: 'Shopping cart',
      icon: const Icon(Icons.shopping_bag_outlined),
      onPressed: () => Navigator.pushNamed(context, '/cart'),
    ),
    PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) => Navigator.pushNamed(context, value),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '/orders', child: Text('My orders')),
        const PopupMenuItem(
          value: '/notifications',
          child: Text('Notifications'),
        ),
        if (AuthService.isAdmin)
          const PopupMenuItem(value: '/admin', child: Text('Admin console')),
      ],
    ),
  ],
);

class StoreFooter extends StatelessWidget {
  final int index;
  final ValueChanged<int>? onIndex;
  const StoreFooter({super.key, this.index = 0, this.onIndex});
  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 72,
    selectedIndex: index,
    onDestinationSelected: onIndex ?? (i) => openStoreTab(context, i),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view),
        label: 'Catalog',
      ),
      NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      NavigationDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: 'Wishlist',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ],
  );
}

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
  Widget build(BuildContext context) => StoreScaffold(
    title: const [
      'Athenaeum',
      'Book catalog',
      'Search books',
      'Wishlist',
      'My profile',
    ][index],
    index: index,
    onIndex: onIndex,
    body: child,
  );
}

class StoreScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final int index;
  final ValueChanged<int>? onIndex;
  final Widget? leading;
  final List<Widget> actions;
  const StoreScaffold({
    super.key,
    required this.title,
    required this.body,
    this.index = 0,
    this.onIndex,
    this.leading,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: storeAppBar(context, title, leading: leading, actions: actions),
    body: SafeArea(child: PageEntrance(child: body)),
    bottomNavigationBar: StoreFooter(index: index, onIndex: onIndex),
  );
}
