import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_theme.dart';
import 'book_image.dart';
import 'book_badges.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool compact;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onAdd,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: compact ? 62 : 78,
                    height: compact ? 88 : 112,
                    child: BookImage(source: book.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.genre.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (book.bestseller || book.newArrival) ...[
                        const SizedBox(height: 6),
                        BookBadges(book: book),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.accent,
                          ),
                          Text(
                            ' ${book.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const Spacer(),
                          Text(
                            '\$${book.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (onAdd != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: onAdd,
                            child: const Text(
                              'Add to Bag',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
