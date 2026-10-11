import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/firebase_service.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/book_image.dart';

class DetailsScreen extends StatefulWidget {
  final Book book;
  const DetailsScreen({super.key, required this.book});
  @override State<DetailsScreen> createState() => _DetailsScreenState();
}
class _DetailsScreenState extends State<DetailsScreen> {
  bool saved = false; int qty = 1; List<Map<String, dynamic>> reviews = []; bool reviewsLoading = true;
  @override void initState() { super.initState(); _load(); _loadReviews(); }
  Future<void> _load() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final w = await StoreService.getWishlist(u.uid);
    if (mounted) setState(() => saved = w.contains(widget.book.id));
  }
  Future<void> _wishlist() async {
    final u = FirebaseAuth.instance.currentUser; if (u == null) return;
    await StoreService.setWishlist(u.uid, widget.book.id, !saved);
    setState(() => saved = !saved);
  }
  Future<void> _cart() async {
    final u = FirebaseAuth.instance.currentUser; if (u == null) return;
    await StoreService.setCartItem(u.uid, widget.book.id, qty);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to shopping bag.')));
  }

  Future<void> _loadReviews() async {
    try {
      final data = await StoreService.getReviews(widget.book.id);
      if (mounted) setState(() { reviews = data; reviewsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => reviewsLoading = false);
    }
  }

  Future<void> _reviewDialog({Map<String, dynamic>? existing}) async {
    final controller = TextEditingController(text: '${existing?['text'] ?? ''}');
    double rating = double.tryParse('${existing?['rating'] ?? 5}') ?? 5;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Write a Review' : 'Edit Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<double>(
                value: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                items: [1, 2, 3, 4, 5]
                    .map((v) => DropdownMenuItem(value: v.toDouble(), child: Text('$v stars')))
                    .toList(),
                onChanged: (v) => setDialogState(() => rating = v ?? 5),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLength: 5000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Your review'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => error = 'Please write a review.');
                  return;
                }
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                try {
                  if (existing == null) {
                    await StoreService.addReview(
                      bookId: widget.book.id,
                      uid: user.uid,
                      name: user.displayName?.trim().isNotEmpty == true
                          ? user.displayName!
                          : 'Reader',
                      rating: rating,
                      text: controller.text.trim(),
                    );
                  } else {
                    await StoreService.updateReview(
                      bookId: widget.book.id,
                      reviewId: '${existing['id']}',
                      rating: rating,
                      text: controller.text.trim(),
                    );
                  }
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadReviews();
                } catch (e) {
                  setDialogState(() => error = '$e');
                }
              },
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    await StoreService.deleteReview(widget.book.id, '${review['id']}');
    await _loadReviews();
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: const Text('Athenaeum'),
      actions: [IconButton(onPressed: _wishlist, icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border)), const Icon(Icons.share_outlined), const SizedBox(width: 6)]),
    body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: BookImage(source: widget.book.imageUrl, width: 180, height: 260))),
      const SizedBox(height: 20),
      Text(widget.book.genre.toUpperCase(), style: const TextStyle(fontSize: 9, letterSpacing: 1.5, color: AppTheme.accent, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5), Text(widget.book.title, style: Theme.of(context).textTheme.headlineMedium),
      Text('by ${widget.book.author}', style: const TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 10),
      Row(children: [const Icon(Icons.star_rounded, color: AppTheme.accent, size: 17), Text(' ${widget.book.rating.toStringAsFixed(1)}'), Text('  ·  ${reviews.length} reviews', style: const TextStyle(color: AppTheme.muted, fontSize: 11))]),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Text('Edition',style:Theme.of(context).textTheme.titleMedium), const Spacer(), Text('\$${widget.book.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))]))),
      const SizedBox(height: 18),
      Text('Editorial Synopsis', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 7), Text(widget.book.description, style: const TextStyle(height: 1.55, color: AppTheme.muted)),
      const SizedBox(height: 20),
      Text('Bibliographic Details', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(children: [
        _row('Author', widget.book.author), _row('Genre', widget.book.genre), _row('Publication', '${widget.book.year}'), _row('Availability', widget.book.stock > 0 ? 'In stock' : 'Out of stock'),
      ]))),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(child: Text('Reader Reviews', style: Theme.of(context).textTheme.titleLarge)),
          TextButton.icon(
            onPressed: () => _reviewDialog(),
            icon: const Icon(Icons.rate_review_outlined, size: 17),
            label: const Text('Write'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (reviewsLoading)
        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
      else if (reviews.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No reviews yet. Be the first reader to review this book.')))
      else
        ...reviews.map((review) {
          final user = FirebaseAuth.instance.currentUser;
          final own = user != null && '${review['userId']}' == user.uid;
          final likes = int.tryParse('${review['likes'] ?? 0}') ?? 0;
          final stars = double.tryParse('${review['rating'] ?? 0}') ?? 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('★ ${stars.toStringAsFixed(1)}', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (own) ...[
                    IconButton(onPressed: () => _reviewDialog(existing: review), icon: const Icon(Icons.edit_outlined, size: 17)),
                    IconButton(onPressed: () => _deleteReview(review), icon: const Icon(Icons.delete_outline, size: 17)),
                  ],
                ]),
                const SizedBox(height: 5),
                Text('${review['text'] ?? ''}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text('— ${review['name'] ?? 'Reader'}', style: const TextStyle(fontSize: 11, color: AppTheme.muted))),
                  TextButton.icon(
                    onPressed: () async {
                      await StoreService.likeReview(widget.book.id, '${review['id']}', likes);
                      await _loadReviews();
                    },
                    icon: const Icon(Icons.thumb_up_outlined, size: 15),
                    label: Text('$likes'),
                  ),
                ]),
              ]),
            ),
          );
        }),
      const SizedBox(height: 18),
      Row(children: [
        Container(decoration: BoxDecoration(border: Border.all(color: AppTheme.line), borderRadius: BorderRadius.circular(8)), child: Row(children: [
          IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove, size: 17)),
          Text('$qty'), IconButton(onPressed: qty < widget.book.stock ? () => setState(() => qty++) : null, icon: const Icon(Icons.add, size: 17)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 48, child: FilledButton(onPressed: widget.book.stock > 0 ? _cart : null, style: FilledButton.styleFrom(backgroundColor: AppTheme.accent), child: const Text('Add to Cart  →')))),
      ]),
    ])),
  );
  Widget _row(String a, String b) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Text(a, style: const TextStyle(color: AppTheme.muted, fontSize: 12)), const Spacer(), Flexible(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)))]));
}
