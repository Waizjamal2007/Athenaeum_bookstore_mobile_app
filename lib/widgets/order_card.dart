import 'package:flutter/material.dart';

import '../models/store_order.dart';
import '../utils/money.dart';
import 'motion.dart';

class OrderCard extends StatelessWidget {
  final StoreOrder order;
  final bool admin;
  const OrderCard({super.key, required this.order, this.admin = false});
  @override
  Widget build(BuildContext context) => PageEntrance(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order ${order.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.date, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  money(order.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (order.quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${order.quantity} ${order.quantity == 1 ? 'book' : 'books'}',
                ),
              ),
            if (admin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Customer: ${order.data['email'] ?? order.userId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  admin ? '/admin/order' : '/tracking',
                  arguments: order.id,
                ),
                icon: Icon(
                  admin ? Icons.tune : Icons.local_shipping_outlined,
                  size: 18,
                ),
                label: Text(admin ? 'Manage order' : 'Track order'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
