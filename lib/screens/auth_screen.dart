import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/motion.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

import 'package:provider/provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signIn = true, loading = false, obscure = true;
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  // --- GOOGLE SIGN IN / REGISTER FUNCTION ---
  Future<void> googleSignIn() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => loading = false);
        return; // User canceled
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Role refresh aur Realtime Database mein record ensure karna
      await AuthService.refreshRole(force: true);
      final user = userCredential.user;
      if (user != null) {
        final ref = FirebaseService.users.child(user.uid);
        if (!(await ref.get()).exists) {
          await ref.set({
            'name': user.displayName ?? 'Reader',
            'email': user.email,
            'createdAt': ServerValue.timestamp,
            'shippingAddress': '',
            'paymentMethod': '',
          });
        }
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AuthService.isAdmin ? '/admin' : '/home',
              (_) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty ||
        password.text.length < 6 ||
        (!signIn && name.text.trim().isEmpty)) {
      setState(
            () => error =
        'Enter an email, password of at least 6 characters, and your name for registration.',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (signIn) {
        final c = await AuthService.login(email.text, password.text);
        if (!c.user!.emailVerified && mounted) {
          await c.user!.sendEmailVerification();
          setState(
                () => error =
            'Please verify your email. A confirmation link was sent.',
          );
          return;
        }
      } else {
        await AuthService.register(email.text, password.text, name.text);
        await AuthService.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Check your email for the confirmation link.',
              ),
            ),
          );
          setState(() => signIn = true);
        }
        return;
      }
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AuthService.isAdmin ? '/admin' : '/home',
              (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> forgot() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Enter your email address first.');
      return;
    }
    try {
      await AuthService.resetPassword(email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: StoreFooter(
      onIndex: (i) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sign in to explore the bookstore.')),
        );
      },
    ),
    appBar: AppBar(
      title: const Text('Bookstore'),
      actions: [
        IconButton(
          tooltip: 'Toggle theme',
          onPressed: () => context.read<ThemeController>().toggle(),
          icon: Icon(
            context.watch<ThemeController>().isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
      ],
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pushReplacementNamed(context, '/'),
      ),
    ),
    body: PageEntrance(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 5, 24, 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Bookstore',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'LITERARY FOLIO',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.8,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 38),
                Text(
                  signIn ? 'Welcome back' : 'Create your account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Enter your credentials to manage collections and reading lists',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Sign In')),
                    ButtonSegment(
                        value: false, label: Text('Create Account')),
                  ],
                  selected: {signIn},
                  onSelectionChanged: loading
                      ? null
                      : (s) => setState(() {
                    signIn = s.first;
                    error = null;
                  }),
                ),
                if (!signIn) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration:
                    const InputDecoration(labelText: 'Full name'),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                  const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                ),
                if (signIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : forgot,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                if (signIn &&
                    AuthService.auth.currentUser != null &&
                    !AuthService.auth.currentUser!.emailVerified)
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: loading
                            ? null
                            : () async {
                          try {
                            await AuthService.resendVerification();
                            if (mounted) {
                              setState(
                                    () => error =
                                'Verification email sent.',
                              );
                            }
                          } catch (e) {
                            if (mounted) setState(() => error = '$e');
                          }
                        },
                        child: const Text('Resend verification'),
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () async {
                          try {
                            await AuthService.auth.currentUser!
                                .reload();
                            final verified = AuthService
                                .auth
                                .currentUser
                                ?.emailVerified ==
                                true;
                            if (verified) {
                              await AuthService.refreshRole(
                                  force: true);
                              if (mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AuthService.isAdmin
                                      ? '/admin'
                                      : '/home',
                                      (_) => false,
                                );
                              }
                            } else if (mounted) {
                              setState(
                                    () => error =
                                'Email is not verified yet.',
                              );
                            }
                          } catch (e) {
                            if (mounted) setState(() => error = '$e');
                          }
                        },
                        child: const Text('I have verified my email'),
                      ),
                    ],
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      error!,
                      style:
                      const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 8),

                // --- EMAIL SIGN IN / CREATE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ink,
                    ),
                    child: loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      signIn
                          ? 'Sign In to Account  →'
                          : 'Create Account  →',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- GOOGLE SIGN IN BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: loading ? null : googleSignIn,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.g_mobiledata, size: 28),
                        SizedBox(width: 8),
                        Text('Continue with Google'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Your next great read starts here',
                    style: TextStyle(fontSize: 10, color: AppTheme.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}