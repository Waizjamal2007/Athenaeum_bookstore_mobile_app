import 'package:flutter/material.dart';

import '../models/book.dart';

class BookBadges extends StatelessWidget {
  final Book book;
  const BookBadges({super.key, required this.book});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      if (book.bestseller)
        _badge(context, 'Bestseller', Icons.workspace_premium_outlined),
      if (book.newArrival)
        _badge(context, 'New arrival', Icons.auto_awesome_outlined),
    ],
  );
  Widget _badge(BuildContext context, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
