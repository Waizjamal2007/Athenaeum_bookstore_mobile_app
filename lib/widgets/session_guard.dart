import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class SessionGuard extends StatefulWidget {
  final Widget child;
  final bool adminOnly;
  const SessionGuard({super.key, required this.child, this.adminOnly = false});
  @override State<SessionGuard> createState() => _SessionGuardState();
}
class _SessionGuardState extends State<SessionGuard> {
  late final authStream = FirebaseAuth.instance.userChanges();
  String? _uid;
  Future<bool>? _role;
  Stream<DatabaseEvent>? _profile;
  @override Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: authStream, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user == null || !user.emailVerified) {
        _uid = null; _attached = null;
        return const AuthScreen();
      }
      if (_uid != user.uid) {
        _uid = user.uid;
        _role = AuthService.refreshRole();
        _profile = FirebaseService.users.child(user.uid).onValue;
      }
      return FutureBuilder<bool>(future: _role, builder: (context, role) {
        if (role.hasError) return const Scaffold(body: Center(child: Text('Unable to verify access. Please sign in again.')));
        if (!role.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (widget.adminOnly && role.data != true) {
          return Scaffold(appBar: AppBar(title: const Text('Access denied')),
            body: Center(child: TextButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
              child: const Text('Return to store'))));
        }
        return StreamBuilder<DatabaseEvent>(stream: _profile, builder: (context, profile) {
          if (profile.hasError) return Scaffold(body: Center(child: TextButton(
            onPressed: () async { await AuthService.logout(); }, child: const Text('Access unavailable. Sign out'))));
          if (!profile.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final data = profile.data!.snapshot.value;
          if (data is! Map) {
            return Scaffold(body: Center(child: TextButton(onPressed: () async {
              await AuthService.logout();
            }, child: const Text('Profile unavailable. Sign out and sign in again.'))));
          }
          if (data['disabled'] == true) {
            return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Your account is disabled. Contact the store.'),
              TextButton(onPressed: () async { await AuthService.logout(); }, child: const Text('Sign out')),
            ])));
          }
          // Runs once per mounted guard; service deduplicates device registration.
          if (_attached != user.uid) {
            _attached = user.uid;
            WidgetsBinding.instance.addPostFrameCallback((_) => NotificationService.attachUser(user));
          }
          return widget.child;
        });
      });
    });
  String? _attached;
}
