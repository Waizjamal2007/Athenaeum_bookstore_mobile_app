import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/store_order.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import 'book_image.dart';

class OrderSummary extends StatefulWidget {
  final StoreOrder order;
  const OrderSummary({super.key, required this.order});
  @override
  State<OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<OrderSummary> {
  late final books = StoreService.booksOnce();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Book>>(
    future: books,
    builder: (context, snapshot) {
      final byId = {for (final b in snapshot.data ?? <Book>[]) b.id: b};
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(widget.order.date),
              const SizedBox(height: 12),
              if (widget.order.items.isEmpty)
                const Text('Item details are unavailable for this order.'),
              ...widget.order.items.map((row) {
                final b = byId['${row['bookId'] ?? row['id']}'];
                final title =
                    '${row['title'] ?? row['bookTitle'] ?? b?.title ?? 'Book ${row['bookId'] ?? ''}'}';
                final price = double.tryParse(
                  '${row['price'] ?? row['unitPrice']}',
                );
                final qty =
                    int.tryParse('${row['qty'] ?? row['quantity'] ?? 1}') ?? 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      if (b != null) ...[
                        BookImage(source: b.imageUrl, width: 38, height: 52),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: Text('$title\nQuantity: $qty')),
                      if (price != null)
                        Text(money(lineCents(price, qty) / 100)),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                children: [
                  const Expanded(child: Text('Confirmed total')),
                  Text(
                    money(widget.order.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (widget.order.address.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Shipping address',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(widget.order.address),
              ],
            ],
          ),
        ),
      );
    },
  );
}
