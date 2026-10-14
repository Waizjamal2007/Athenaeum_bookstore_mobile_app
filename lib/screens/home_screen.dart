import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/book_card.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onIndex;

  const HomeScreen({super.key, required this.onIndex});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      index: 0,
      onIndex: onIndex,
      child: StreamBuilder<List<Book>>(
        stream: StoreService.booksStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Unable to load books.'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final books = snapshot.data ?? [];

          final bestsellers = books.where((book) => book.bestseller).toList();

          final newArrivals = books.where((book) => book.newArrival).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bookstore',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 2,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Discover your next read',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => onIndex(4),
                        icon: const Icon(Icons.person_outline),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'THE CURATOR’S CHOICE',
                          style: TextStyle(
                            color: Color(0xFFD9B69F),
                            fontSize: 9,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Autumn Literary Highlights',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'A considered selection of enduring works and recent discoveries.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => onIndex(1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          child: const Text('Explore Collection'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _section(
                context,
                'Bestsellers',
                bestsellers,
                onIndex,
              ),
              _section(context, 'New Arrivals', newArrivals, onIndex),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Center(
                    child: Text(
                      '“Whatever it is you’re seeking, come in for a literary experience.”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _section(
    BuildContext context,
    String title,
    List<Book> books,
    ValueChanged<int> onIndex,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => onIndex(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (books.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No selections yet. Check back soon.'),
              ),
            ...books
                .take(3)
                .map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BookCard(
                      book: book,
                      compact: true,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/details',
                          arguments: book,
                        );
                      },
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
