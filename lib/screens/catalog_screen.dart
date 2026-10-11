import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/store_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/book_card.dart';

class CatalogScreen extends StatefulWidget {
  final ValueChanged<int> onIndex;
  const CatalogScreen({super.key, required this.onIndex});
  @override State<CatalogScreen> createState() => _CatalogScreenState();
}
class _CatalogScreenState extends State<CatalogScreen> {
  String? genre, author;
  late final Stream<List<Book>> stream = StoreService.booksStream();
  @override Widget build(BuildContext context) => AppShell(index: 1,
    onIndex: widget.onIndex, child: StreamBuilder<List<Book>>(
      stream: stream, builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Unable to load catalog.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final books = snapshot.data!;
        final genres = books.map((b) => b.genre.trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();
        final authors = books.map((b) => b.author.trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();
        final activeGenre = genres.contains(genre) ? genre : null;
        final activeAuthor = authors.contains(author) ? author : null;
        final filtered = books.where((b) =>
          (activeGenre == null || b.genre.trim() == activeGenre) &&
          (activeAuthor == null || b.author.trim() == activeAuthor)).toList();
        return CustomScrollView(slivers: [
          SliverAppBar(pinned: true, title: const Text('Book Catalog'),
            leading: IconButton(onPressed: () => widget.onIndex(0), icon: const Icon(Icons.arrow_back)),
            actions: [IconButton(onPressed: () => widget.onIndex(2), icon: const Icon(Icons.search))]),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16),
            child: Column(children: [
              DropdownButtonFormField<String>(value: activeGenre ?? '', isExpanded: true,
                decoration: const InputDecoration(labelText: 'Genre'),
                items: [const DropdownMenuItem(value: '', child: Text('All genres')),
                  ...genres.map((s) => DropdownMenuItem(value: s, child: Text(s)))],
                onChanged: (s) => setState(() => genre = s == '' ? null : s)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(value: activeAuthor ?? '', isExpanded: true,
                decoration: const InputDecoration(labelText: 'Author'),
                items: [const DropdownMenuItem(value: '', child: Text('All authors')),
                  ...authors.map((s) => DropdownMenuItem(value: s, child: Text(s)))],
                onChanged: (s) => setState(() => author = s == '' ? null : s)),
              Row(children: [Text('${filtered.length} books'), const Spacer(),
                TextButton(onPressed: () => setState(() { genre = null; author = null; }),
                  child: const Text('Reset filters'))]),
            ]))),
          if (filtered.isEmpty) const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.all(24), child: Text('No books match these filters.'))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 25),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((_, i) => BookCard(book: filtered[i],
                onTap: () => Navigator.pushNamed(context, '/details', arguments: filtered[i]),
                onAdd: () => Navigator.pushNamed(context, '/details', arguments: filtered[i])),
                childCount: filtered.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 470, mainAxisExtent: 150, crossAxisSpacing: 10, mainAxisSpacing: 10))),
        ]);
      }));
}
