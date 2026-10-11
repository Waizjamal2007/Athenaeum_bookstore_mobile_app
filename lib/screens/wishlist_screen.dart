import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/book_card.dart';

class WishlistScreen extends StatefulWidget {
final ValueChanged<int> onIndex;

const WishlistScreen({
super.key,
required this.onIndex,
});

@override
State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
List<Book> books = [];
Set<String> ids = {};
bool loading = true;

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
if (mounted) {
setState(() {
loading = false;
});
}
return;
}

try {
final allBooks = await StoreService.booksOnce();
final wishlist = await StoreService.getWishlist(user.uid);

if (!mounted) return;

setState(() {
ids = wishlist;
books = allBooks
    .where((book) => wishlist.contains(book.id))
    .toList();
loading = false;
});
} catch (e) {
if (!mounted) return;

setState(() {
loading = false;
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Unable to load wishlist: $e'),
),
);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
leading: IconButton(onPressed: () => widget.onIndex(0), icon: const Icon(Icons.arrow_back)),
title: const Text('Curated Reserve'),
actions: [
IconButton(
onPressed: _load,
icon: const Icon(Icons.refresh),
),
],
),
body: loading
? const Center(
child: CircularProgressIndicator(),
)
    : ListView(
padding: const EdgeInsets.all(16),
children: [
const Text(
'CURATED WISHLIST',
style: TextStyle(
fontSize: 9,
letterSpacing: 1.7,
color: AppTheme.accent,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 4),
const Text(
'A considered reserve of private reading selections awaiting acquisition.',
style: TextStyle(
color: AppTheme.muted,
fontSize: 12,
),
),
const SizedBox(height: 14),
if (books.isEmpty)
const Card(
child: Padding(
padding: EdgeInsets.all(18),
child: Text(
'Your reserve is empty. Save books from their detail pages.',
),
),
),
...books.map(
(book) => Padding(
padding: const EdgeInsets.only(bottom: 8),
child: BookCard(
book: book,
onTap: () {
Navigator.pushNamed(
context,
'/details',
arguments: book,
);
},
onAdd: () {
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
);
}
}

