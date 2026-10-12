import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/store_order.dart';
import '../services/firebase_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/order_card.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String filter = 'All';
  late final stream = FirebaseService.orders
      .orderByChild('userId')
      .equalTo(FirebaseAuth.instance.currentUser!.uid)
      .onValue;
  @override
  Widget build(BuildContext context) => StoreScaffold(
    title: 'My orders',
    index: 4,
    body: StreamBuilder<DatabaseEvent>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text('Unable to load orders. Please check your connection.'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final all = StoreOrder.rows(snapshot.data!.snapshot.value);
        final rows = all
            .where(
              (o) =>
                  filter == 'All' ||
                  (filter == 'Delivered'
                      ? o.stage == 3
                      : o.stage >= 0 && o.stage < 3),
            )
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  for (final label in ['All', 'Active', 'Delivered'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: filter == label,
                        onSelected: (_) => setState(() => filter = label),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 48),
                          const SizedBox(height: 14),
                          Text(
                            all.isEmpty
                                ? 'Your first order starts here'
                                : 'No orders in this section',
                          ),
                          if (all.isEmpty)
                            TextButton(
                              onPressed: () => openStoreTab(context, 1),
                              child: const Text('Browse books'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => OrderCard(order: rows[i]),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
