import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/book_card.dart';

class SearchScreen extends StatefulWidget {
  final ValueChanged<int> onIndex;
  const SearchScreen({super.key, required this.onIndex});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final q = TextEditingController();
  String sort = 'Popularity';
  String genre = 'All';
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
    index: 2,
    onIndex: widget.onIndex,
    child: StreamBuilder<List<Book>>(
      stream: StoreService.booksStream(),
      builder: (c, s) {
        if (s.hasError)
          return const Center(
            child: Text('Unable to load books. Please try again.'),
          );
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        var books = List<Book>.from(s.data ?? []);
        final term = q.text.trim().toLowerCase();
        if (term.isNotEmpty)
          books = books
              .where(
                (b) => '${b.title} ${b.author} ${b.genre}'
                    .toLowerCase()
                    .contains(term),
              )
              .toList();
        if (genre != 'All')
          books = books.where((b) => b.genre == genre).toList();
        if (sort == 'Price: Low to High')
          books.sort((a, b) => a.price.compareTo(b.price));
        if (sort == 'Price: High to Low')
          books.sort((a, b) => b.price.compareTo(a.price));
        if (sort == 'Release Date')
          books.sort((a, b) => b.year.compareTo(a.year));
        if (sort == 'Popularity')
          books.sort((a, b) => b.rating.compareTo(a.rating));
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: q,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by title, author, or genre...',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 45,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final x in [
                      'Popularity',
                      'Price: Low to High',
                      'Price: High to Low',
                      'Release Date',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(x, style: const TextStyle(fontSize: 10)),
                          selected: sort == x,
                          onSelected: (_) => setState(() => sort = x),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
                child: Row(
                  children: [
                    const Text('Showing '),
                    Text(
                      '${books.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(' titles'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        q.clear();
                        genre = 'All';
                        sort = 'Popularity';
                      }),
                      child: const Text('Reset All'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BookCard(
                      book: books[i],
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/details',
                        arguments: books[i],
                      ),
                      onAdd: () => Navigator.pushNamed(
                        context,
                        '/details',
                        arguments: books[i],
                      ),
                    ),
                  ),
                  childCount: books.length,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
