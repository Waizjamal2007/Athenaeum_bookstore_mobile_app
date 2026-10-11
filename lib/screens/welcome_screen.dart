import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
        child: Column(children: [
          const Spacer(),
          Container(
            width: 82, height: 82,
            decoration: BoxDecoration(border: Border.all(color: AppTheme.line), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.menu_book_outlined, size: 34, color: AppTheme.accent),
          ),
          const SizedBox(height: 22),
          Text('Athenaeum', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 5),
          const Text('LITERARY CURATION & ARCHIVAL', style: TextStyle(fontSize: 10, letterSpacing: 2.2, color: AppTheme.muted)),
          const SizedBox(height: 7),
          const Text('PRESS', style: TextStyle(fontSize: 9, letterSpacing: 2, color: AppTheme.muted)),
          const Spacer(),
          const Text('PREPARING YOUR CATALOG...', style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: AppTheme.muted)),
          const SizedBox(height: 5),
          const Text('LITERATURE · HISTORY · IDEAS · CULTURE', style: TextStyle(fontSize: 8, letterSpacing: 1.1, color: AppTheme.muted)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 46, child: FilledButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/auth'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
            child: const Text('Enter the Library'),
          )),
        ]),
      ),
    ),
  );
}
