import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/firebase_service.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import '../widgets/app_shell.dart';
import '../widgets/book_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Book> allBooks = [];
  Map<String, int> cart = {};
  bool booksReady = false, cartReady = false, checkingOut = false;
  String? error;
  final pending = <String>{};
  StreamSubscription<List<Book>>? _books;
  StreamSubscription<DatabaseEvent>? _cart;
  List<Book> get books => allBooks.where((b) => (cart[b.id] ?? 0) > 0).toList();
  int get subtotalCents =>
      books.fold(0, (sum, b) => sum + lineCents(b.price, cart[b.id] ?? 0));
  // Existing checkout uses an 8% estimated tax. Backend confirms the final amount.
  int get taxCents => (subtotalCents * .08).round();
  bool get loading => !booksReady || !cartReady;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    _books?.cancel();
    _cart?.cancel();
    super.dispose();
  }

  void _watch() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _books = StoreService.booksStream().listen((value) {
      if (mounted)
        setState(() {
          allBooks = value;
          booksReady = true;
          error = null;
        });
    }, onError: _fail);
    _cart = FirebaseService.carts.child(user.uid).onValue.listen((event) {
      final raw = event.snapshot.value;
      final value = raw is Map
          ? raw.map((k, v) => MapEntry('$k', int.tryParse('$v') ?? 0))
          : <String, int>{};
      if (mounted)
        setState(() {
          cart = value;
          cartReady = true;
          error = null;
        });
    }, onError: _fail);
  }

  void _fail(Object e) {
    if (mounted)
      setState(
        () => error = 'Unable to load cart. Check your connection and retry.',
      );
  }

  Future<void> _retry() async {
    await _books?.cancel();
    await _cart?.cancel();
    if (!mounted) return;
    setState(() {
      error = null;
      booksReady = false;
      cartReady = false;
    });
    _watch();
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _qty(Book book, int qty) async {
    if (checkingOut || pending.contains(book.id)) return;
    if (qty > book.stock) {
      _message('Only ${book.stock} copies are available.');
      return;
    }
    setState(() => pending.add(book.id));
    try {
      await StoreService.setCartItem(
        FirebaseAuth.instance.currentUser!.uid,
        book.id,
        qty,
      );
    } catch (e) {
      _message('Unable to update cart: $e');
    } finally {
      if (mounted) setState(() => pending.remove(book.id));
    }
  }

  Future<void> _checkout() async {
    if (books.isEmpty || checkingOut || pending.isNotEmpty) return;
    if (books.any((b) => (cart[b.id] ?? 0) > b.stock)) {
      _message('Some quantities exceed current stock. Update your cart first.');
      return;
    }
    setState(() => checkingOut = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = await StoreService.getProfile(user.uid);
      if ('${profile['shippingAddress'] ?? ''}'.trim().isEmpty) {
        _message('Add a shipping address in Profile before checkout.');
        if (mounted) Navigator.pushNamed(context, '/profile');
        return;
      }
      final id = await StoreService.createOrder(
        user.uid,
        books
            .map((b) => <String, dynamic>{'bookId': b.id, 'qty': cart[b.id]})
            .toList(),
        (subtotalCents + taxCents) / 100,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Order placed'),
          content: Text(
            'Order $id is confirmed. Your order page shows the final total and delivery status.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('View my orders'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pushNamed(context, '/orders');
    } catch (e) {
      _message('Checkout failed: $e');
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => StoreScaffold(
    title: 'Shopping cart',
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
        : loading
        ? const Center(child: CircularProgressIndicator())
        : books.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 52),
                const SizedBox(height: 14),
                Text(
                  'Your cart is empty',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => openStoreTab(context, 1),
                  child: const Text('Explore books'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${books.length} selected titles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...books.map((book) {
                      final qty = cart[book.id] ?? 0;
                      final busy = pending.contains(book.id) || checkingOut;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: BookImage(
                                      source: book.imageUrl,
                                      width: 56,
                                      height: 80,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(book.author),
                                        const SizedBox(height: 8),
                                        Text('${money(book.price)} each'),
                                        if (qty > book.stock)
                                          Text(
                                            'Only ${book.stock} in stock',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove book',
                                    onPressed: busy
                                        ? null
                                        : () => _qty(book, 0),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Decrease quantity',
                                    onPressed: busy
                                        ? null
                                        : () => _qty(book, qty - 1),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Text(
                                      '$qty',
                                      key: ValueKey(qty),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Increase quantity',
                                    onPressed: busy || qty >= book.stock
                                        ? null
                                        : () => _qty(book, qty + 1),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                  const Spacer(),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Text(
                                      money(lineCents(book.price, qty) / 100),
                                      key: ValueKey(qty),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _row('Books subtotal', subtotalCents),
                            _row('Estimated tax (8%)', taxCents),
                            _row('Delivery', 0),
                            const Divider(),
                            _row(
                              'Estimated order total',
                              subtotalCents + taxCents,
                              bold: true,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'The confirmed amount appears in My orders.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: checkingOut || pending.isNotEmpty
                        ? null
                        : _checkout,
                    child: checkingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Place order · ${money((subtotalCents + taxCents) / 100)}',
                          ),
                  ),
                ),
              ),
            ],
          ),
  );
  Widget _row(String label, int cents, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          money(cents / 100),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
