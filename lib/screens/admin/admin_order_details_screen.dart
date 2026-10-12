import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/store_order.dart';
import '../../services/admin_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin_shell.dart';
import '../../widgets/order_summary.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const AdminOrderDetailsScreen({super.key, required this.orderId});
  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  late final stream = FirebaseService.orders.child(widget.orderId).onValue;
  bool saving = false;
  Future<void> _update(String status) async {
    setState(() => saving = true);
    try {
      final result = await AdminService.updateOrderStatus(
        widget.orderId,
        status,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['warning'] ?? 'Order status updated.'}'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to update status: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminShell(
    index: 3,
    title: 'Manage order',
    body: StreamBuilder<DatabaseEvent>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Unable to load this order.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final raw = snapshot.data!.snapshot.value;
        if (raw is! Map) return const Center(child: Text('Order not found.'));
        final order = StoreOrder(
          widget.orderId,
          Map<String, dynamic>.from(raw),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Order ${order.id}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Customer: ${order.data['email'] ?? order.userId}'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(order.status),
                      initialValue: StoreOrder.statuses.contains(order.status)
                          ? order.status
                          : null,
                      isExpanded: true,
                      hint: Text(order.status),
                      items: StoreOrder.statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (s) {
                              if (s != null && s != order.status) _update(s);
                            },
                    ),
                    if (saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Changes appear in the customer’s order and tracking screens.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OrderSummary(order: order),
          ],
        );
      },
    ),
  );
}
