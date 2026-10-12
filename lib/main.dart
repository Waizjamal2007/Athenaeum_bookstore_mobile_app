import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'widgets/session_guard.dart';
import 'screens/notifications_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/admin/admin_order_details_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'models/book.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/search_screen.dart';
import 'screens/details_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/admin/admin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SupabaseService.init();
  final theme = await ThemeController.load();
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint("Push initialization: $e");
  }
  runApp(
    ChangeNotifierProvider.value(value: theme, child: const AthenaeumApp()),
  );
}

class AthenaeumApp extends StatelessWidget {
  const AthenaeumApp({super.key});

  Route<dynamic> _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.035, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (_, controller, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Athenaeum',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.mode,
        navigatorKey: NotificationService.navigatorKey,
        initialRoute: '/',
        routes: {
          '/': (_) => const EntryScreen(),
          '/auth': (_) => const AuthScreen(),
          '/home': (_) =>
              const SessionGuard(child: MainNavigation(initialIndex: 0)),
          '/catalog': (_) =>
              const SessionGuard(child: MainNavigation(initialIndex: 1)),
          '/search': (_) =>
              const SessionGuard(child: MainNavigation(initialIndex: 2)),
          '/wishlist': (_) =>
              const SessionGuard(child: MainNavigation(initialIndex: 3)),
          '/profile': (_) =>
              const SessionGuard(child: MainNavigation(initialIndex: 4)),
          '/orders': (_) => const SessionGuard(child: OrdersScreen()),
          '/admin/books': (_) => const SessionGuard(
            adminOnly: true,
            child: AdminScreen(initialIndex: 1),
          ),
          '/admin/users': (_) => const SessionGuard(
            adminOnly: true,
            child: AdminScreen(initialIndex: 2),
          ),
          '/admin/orders': (_) => const SessionGuard(
            adminOnly: true,
            child: AdminScreen(initialIndex: 3),
          ),
          '/cart': (_) => const SessionGuard(child: CartScreen()),
          '/admin': (_) =>
              const SessionGuard(adminOnly: true, child: AdminScreen()),
          '/notifications': (_) =>
              const SessionGuard(child: NotificationsScreen()),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/details' && settings.arguments is Book) {
            return _route(
              SessionGuard(
                child: DetailsScreen(book: settings.arguments as Book),
              ),
            );
          }
          if (settings.name == '/tracking' && settings.arguments is String) {
            return _route(
              SessionGuard(
                child: TrackingScreen(orderId: settings.arguments as String),
              ),
            );
          }
          if (settings.name == '/admin/order' && settings.arguments is String) {
            return _route(
              SessionGuard(
                adminOnly: true,
                child: AdminOrderDetailsScreen(
                  orderId: settings.arguments as String,
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, required this.initialIndex});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  void select(int i) {
    if (i >= 0 && i <= 4 && i != index) {
      setState(() => index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onIndex: select),
      CatalogScreen(onIndex: select),
      SearchScreen(onIndex: select),
      WishlistScreen(onIndex: select),
      ProfileScreen(onIndex: select),
    ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
    );
  }
}

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final Future<bool> role = AuthService.refreshRole();
  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) return const WelcomeScreen();
    return FutureBuilder<bool>(
      future: role,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const AuthScreen();
        if (!snapshot.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        return SessionGuard(
          adminOnly: snapshot.data!,
          child: snapshot.data!
              ? const AdminScreen()
              : const MainNavigation(initialIndex: 0),
        );
      },
    );
  }
}
