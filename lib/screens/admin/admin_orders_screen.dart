import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/store_order.dart';
import '../../services/firebase_service.dart';
import '../../widgets/order_card.dart';

// Displayed inside the common AdminShell as a separate Orders destination.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final stream = FirebaseService.orders.onValue;
  String query = '', status = 'All';
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(
          child: Text(
            'Unable to load orders. Check admin access and connection.',
          ),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final rows = StoreOrder.rows(snapshot.data!.snapshot.value)
          .where(
            (o) =>
                (status == 'All' || o.status == status) &&
                '${o.id} ${o.userId} ${o.data['email'] ?? ''}'
                    .toLowerCase()
                    .contains(query),
          )
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search order or customer',
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final label in ['All', ...StoreOrder.statuses])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: status == label,
                      onSelected: (_) => setState(() => status = label),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No matching orders.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (_, i) =>
                        OrderCard(order: rows[i], admin: true),
                  ),
          ),
        ],
      );
    },
  );
}
