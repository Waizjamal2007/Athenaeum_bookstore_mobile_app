import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class AuthService {
  static final auth = FirebaseAuth.instance;
  static bool _admin = false;
  static bool get isAdmin => auth.currentUser != null && _admin;
  static Future<bool> refreshRole({bool force = false}) async {
    final user = auth.currentUser;
    _admin = user != null &&
        (await user.getIdTokenResult(force)).claims?['admin'] == true;
    return _admin;
  }
  static Future<UserCredential> login(String email, String password) async {
    final result = await auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    await refreshRole(force: true);
    // Backfill old accounts that did not have a database profile.
    final user = result.user!;
    final ref = FirebaseService.users.child(user.uid);
    if (!(await ref.get()).exists) {
      await ref.set({'name': user.displayName ?? 'Reader', 'email': user.email,
        'createdAt': ServerValue.timestamp, 'shippingAddress': '',
        'paymentMethod': ''});
    }
    return result;
  }
  static Future<UserCredential> register(String email, String password, String name) async {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Name must contain 1 to 80 characters.');
    }
    final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    _admin = false;
    await cred.user!.updateDisplayName(name.trim());
    await FirebaseService.users.child(cred.user!.uid).set({
      'name': name.trim(), 'email': email.trim(), 'createdAt': ServerValue.timestamp,
      'shippingAddress': '', 'paymentMethod': '',
    });
    await cred.user!.sendEmailVerification();
    return cred;
  }
  static Future<void> updateProfile({required String name,
      required String address, required String paymentMethod}) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please sign in.');
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Name must contain 1 to 80 characters.');
    }
    await FirebaseService.users.child(user.uid).update({
      'name': name.trim(), 'shippingAddress': address.trim(),
      'paymentMethod': paymentMethod.trim(), 'updatedAt': ServerValue.timestamp,
    });
    await user.updateDisplayName(name.trim());
  }
  static Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
  static Future<void> resendVerification() async {
    final user = auth.currentUser;
    if (user != null && !user.emailVerified) await user.sendEmailVerification();
  }
  static Future<void> logout() async {
    await NotificationService.detachUser();
    _admin = false;
    await auth.signOut();
  }
}
