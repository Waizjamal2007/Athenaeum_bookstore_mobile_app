import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/firebase_service.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import '../widgets/app_shell.dart';
import '../widgets/book_badges.dart';
import '../widgets/book_image.dart';

class DetailsScreen extends StatefulWidget {
  final Book book;
  const DetailsScreen({super.key, required this.book});
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool saved = false,
      wishlistBusy = false,
      cartBusy = false,
      reviewsLoading = true;
  int qty = 1;
  String? reviewError;
  List<Map<String, dynamic>> reviews = [];
  final pendingReviews = <String>{};
  StreamSubscription<DatabaseEvent>? _reviews;
  late Book book;
  StreamSubscription<List<Book>>? _books;
  @override
  void initState() {
    super.initState();
    book = widget.book;
    _loadWishlist();
    _reviews = FirebaseService.reviews
        .child(book.id)
        .onValue
        .listen(
          (event) {
            final raw = event.snapshot.value;
            final rows = raw is Map
                ? raw.entries
                      .where((e) => e.value is Map)
                      .map(
                        (e) => <String, dynamic>{
                          ...Map<String, dynamic>.from(e.value as Map),
                          'id': '${e.key}',
                        },
                      )
                      .toList()
                : <Map<String, dynamic>>[];
            rows.sort(
              (a, b) => (int.tryParse('${b['createdAt']}') ?? 0).compareTo(
                int.tryParse('${a['createdAt']}') ?? 0,
              ),
            );
            if (mounted)
              setState(() {
                reviews = rows;
                reviewsLoading = false;
                reviewError = null;
              });
          },
          onError: (Object e) {
            if (mounted)
              setState(() {
                reviewsLoading = false;
                reviewError = 'Unable to load reviews. Check your connection or database access.';
              });
          },
        );
    _books = StoreService.booksStream().listen((rows) {
      final found = rows.where((b) => b.id == book.id);
      if (mounted && found.isNotEmpty)
        setState(() {
          book = found.first;
          if (qty > book.stock && book.stock > 0) qty = book.stock;
        });
    }, onError: (Object e) {});
  }

  @override
  void dispose() {
    _reviews?.cancel();
    _books?.cancel();
    super.dispose();
  }

  void _message(String value) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _loadWishlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ids = await StoreService.getWishlist(user.uid);
      if (mounted) setState(() => saved = ids.contains(book.id));
    } catch (e) {
      _message('Unable to load wishlist: $e');
    }
  }

  Future<void> _wishlist() async {
    if (wishlistBusy) return;
    setState(() => wishlistBusy = true);
    try {
      await StoreService.setWishlist(
        FirebaseAuth.instance.currentUser!.uid,
        book.id,
        !saved,
      );
      if (mounted) setState(() => saved = !saved);
    } catch (e) {
      _message('Unable to update wishlist: $e');
    } finally {
      if (mounted) setState(() => wishlistBusy = false);
    }
  }

  Future<void> _cart() async {
    if (cartBusy) return;
    setState(() => cartBusy = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cart = await StoreService.getCart(user.uid);
      final next = (cart[book.id] ?? 0) + qty;
      if (next > book.stock) {
        _message(
          'Your cart already has ${cart[book.id] ?? 0} copies. Only ${book.stock} are available.',
        );
        return;
      }
      await StoreService.setCartItem(user.uid, book.id, next);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Added to your cart'),
            action: SnackBarAction(
              label: 'View cart',
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
          ),
        );
    } catch (e) {
      _message('Unable to add book: $e');
    } finally {
      if (mounted) setState(() => cartBusy = false);
    }
  }

  double get average => reviews.isEmpty
      ? 0
      : reviews.fold<double>(
              0,
              (sum, r) => sum + (double.tryParse('${r['rating']}') ?? 0),
            ) /
            reviews.length;
  Future<void> _reviewDialog({Map<String, dynamic>? existing}) async {
    final controller = TextEditingController(
      text: '${existing?['text'] ?? ''}',
    );
    int rating = (double.tryParse('${existing?['rating'] ?? 5}') ?? 5)
        .round()
        .clamp(1, 5)
        .toInt();
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              existing == null ? 'Write a review' : 'Edit your review',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    children: [
                      for (int i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i stars',
                          visualDensity: VisualDensity.compact,
                          onPressed: saving
                              ? null
                              : () => update(() => rating = i),
                          icon: Icon(
                            i <= rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  Text('$rating out of 5'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !saving,
                    maxLength: 5000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your reading experience',
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) {
                          update(() => error = 'Please write a review.');
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final user = FirebaseAuth.instance.currentUser!;
                          if (existing == null) {
                            await StoreService.addReview(
                              bookId: book.id,
                              uid: user.uid,
                              name: user.displayName ?? 'Reader',
                              rating: rating.toDouble(),
                              text: controller.text.trim(),
                            );
                          } else {
                            await StoreService.updateReview(
                              bookId: book.id,
                              reviewId: '${existing['id']}',
                              rating: rating.toDouble(),
                              text: controller.text.trim(),
                            );
                          }
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                        } catch (e) {
                          if (dialogContext.mounted)
                            update(() {
                              saving = false;
                              error = 'Unable to save review: $e';
                            });
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save review'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _delete(Map<String, dynamic> review) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your review?'),
        content: const Text('This removes your rating and review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _reviewAction(
      review,
      () => StoreService.deleteReview(book.id, '${review['id']}'),
    );
  }

  Future<void> _reviewAction(
    Map<String, dynamic> review,
    Future<void> Function() action,
  ) async {
    final id = '${review['id']}';
    if (pendingReviews.contains(id)) return;
    setState(() => pendingReviews.add(id));
    try {
      await action();
    } catch (e) {
      _message('Unable to update review: $e');
    } finally {
      if (mounted) setState(() => pendingReviews.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => StoreScaffold(
    title: 'Book details',
    index: 1,
    actions: [
      IconButton(
        tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
        onPressed: wishlistBusy ? null : _wishlist,
        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BookImage(source: book.imageUrl, width: 172, height: 245),
          ),
        ),
        const SizedBox(height: 20),
        BookBadges(book: book),
        const SizedBox(height: 8),
        Text(book.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('by ${book.author}'),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            Text(
              reviews.isEmpty
                  ? ' No ratings yet'
                  : ' ${average.toStringAsFixed(1)} · ${reviews.length} reviews',
            ),
            const Spacer(),
            Text(
              money(book.price),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('About this book', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(book.description, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _row('Genre', book.genre),
                _row('Published', '${book.year}'),
                _row(
                  'Availability',
                  book.stock > 0 ? '${book.stock} in stock' : 'Out of stock',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            IconButton(
              tooltip: 'Decrease quantity',
              onPressed: qty > 1 && !cartBusy
                  ? () => setState(() => qty--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text('$qty', key: ValueKey(qty)),
            ),
            IconButton(
              tooltip: 'Increase quantity',
              onPressed: qty < book.stock && !cartBusy
                  ? () => setState(() => qty++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
            const Spacer(),
            Text(
              money(lineCents(book.price, qty) / 100),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: book.stock > 0 && !cartBusy ? _cart : null,
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: Text(cartBusy ? 'Adding...' : 'Add to cart'),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reader reviews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => _reviewDialog(),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Write'),
            ),
          ],
        ),
        if (reviewsLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reviewError != null)
          Text(reviewError!)
        else if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No reviews yet. Share your reading experience.'),
          )
        else
          ...reviews.map(_reviewCard),
      ],
    ),
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(label),
        const SizedBox(width: 20),
        Expanded(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
  Widget _reviewCard(Map<String, dynamic> review) {
    final own = review['userId'] == FirebaseAuth.instance.currentUser?.uid;
    final busy = pendingReviews.contains('${review['id']}');
    final likes = review['likes'] is Map
        ? (review['likes'] as Map).length
        : int.tryParse('${review['likes'] ?? 0}') ?? 0;
    final stars = double.tryParse('${review['rating']}') ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18),
                Text(' ${stars.toStringAsFixed(1)}'),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${review['name'] ?? 'Reader'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (own)
                  PopupMenuButton<String>(
                    enabled: !busy,
                    onSelected: (s) {
                      if (s == 'edit') {
                        _reviewDialog(existing: review);
                      } else {
                        _delete(review);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${review['text'] ?? ''}',
              style: const TextStyle(height: 1.5),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => _reviewAction(
                        review,
                        () => StoreService.likeReview(
                          book.id,
                          '${review['id']}',
                          likes,
                        ),
                      ),
                icon: const Icon(Icons.thumb_up_outlined, size: 16),
                label: Text('$likes ${likes == 1 ? 'like' : 'likes'}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
