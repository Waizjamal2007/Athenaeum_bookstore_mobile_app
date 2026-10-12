import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/firebase_service.dart';
import '../services/store_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/book_card.dart';

class WishlistScreen extends StatefulWidget {
  final ValueChanged<int> onIndex;
  const WishlistScreen({super.key, required this.onIndex});
  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Book> allBooks = [];
  Set<String> ids = {}, pending = {};
  bool booksReady = false, wishlistReady = false;
  String? error;
  StreamSubscription<List<Book>>? _books;
  StreamSubscription<DatabaseEvent>? _wishlist;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    _books?.cancel();
    _wishlist?.cancel();
    super.dispose();
  }

  void _watch() {
    _books = StoreService.booksStream().listen((value) {
      if (mounted)
        setState(() {
          allBooks = value;
          booksReady = true;
          error = null;
        });
    }, onError: _fail);
    _wishlist = FirebaseService.wishlists
        .child(FirebaseAuth.instance.currentUser!.uid)
        .onValue
        .listen((event) {
          final raw = event.snapshot.value;
          if (mounted)
            setState(() {
              ids = raw is Map ? raw.keys.map((e) => '$e').toSet() : {};
              wishlistReady = true;
              error = null;
            });
        }, onError: _fail);
  }

  void _fail(Object e) {
    if (mounted)
      setState(() => error = 'Unable to load wishlist. Please try again.');
  }

  Future<void> _retry() async {
    await _books?.cancel();
    await _wishlist?.cancel();
    if (!mounted) return;
    setState(() {
      error = null;
      booksReady = false;
      wishlistReady = false;
    });
    _watch();
  }

  Future<void> _remove(Book book) async {
    if (pending.contains(book.id)) return;
    setState(() => pending.add(book.id));
    try {
      await StoreService.setWishlist(
        FirebaseAuth.instance.currentUser!.uid,
        book.id,
        false,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update wishlist: $e')),
        );
    } finally {
      if (mounted) setState(() => pending.remove(book.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = allBooks.where((b) => ids.contains(b.id)).toList();
    return StoreScaffold(
      title: 'Wishlist',
      index: 3,
      onIndex: widget.onIndex,
      body: error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(onPressed: _retry, child: const Text('Retry')),
                ],
              ),
            )
          : !booksReady || !wishlistReady
          ? const Center(child: CircularProgressIndicator())
          : books.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    'Save your next read',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text('Books you bookmark will appear here.'),
                  TextButton(
                    onPressed: () => widget.onIndex(1),
                    child: const Text('Browse the catalog'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${books.length} saved titles',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...books.map(
                  (book) => Column(
                    children: [
                      BookCard(
                        book: book,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/details',
                          arguments: book,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: pending.contains(book.id)
                              ? null
                              : () => _remove(book),
                          icon: const Icon(
                            Icons.bookmark_remove_outlined,
                            size: 18,
                          ),
                          label: const Text('Remove from wishlist'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
