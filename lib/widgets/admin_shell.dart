import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/theme_controller.dart';
import 'motion.dart';

const adminRoutes = ['/admin', '/admin/books', '/admin/users', '/admin/orders'];
void openAdminTab(BuildContext context, int index) =>
    Navigator.pushNamedAndRemoveUntil(
      context,
      adminRoutes[index],
      (_) => false,
    );

class AdminShell extends StatelessWidget {
  final int index;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final ValueChanged<int>? onIndex;
  const AdminShell({
    super.key,
    required this.index,
    required this.title,
    required this.body,
    this.actions = const [],
    this.onIndex,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        ...actions,
        IconButton(
          tooltip: 'Theme',
          onPressed: () => context.read<ThemeController>().toggle(),
          icon: Icon(
            context.watch<ThemeController>().isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (value) async {
            if (value == 'store') {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
            } else {
              try {
                await AuthService.logout();
                if (context.mounted)
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/auth',
                    (_) => false,
                  );
              } catch (e) {
                if (context.mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'store', child: Text('Open bookstore')),
            PopupMenuItem(value: 'logout', child: Text('Sign out')),
          ],
        ),
      ],
    ),
    body: SafeArea(child: PageEntrance(child: body)),
    bottomNavigationBar: NavigationBar(
      height: 72,
      selectedIndex: index,
      onDestinationSelected: onIndex ?? (i) => openAdminTab(context, i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Books',
        ),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Users'),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Orders',
        ),
      ],
    ),
  );
}
