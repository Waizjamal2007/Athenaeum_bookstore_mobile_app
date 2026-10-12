import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../widgets/app_shell.dart';
import '../services/store_service.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final announcements = FirebaseService.db
      .ref('announcements')
      .orderByChild('createdAt')
      .limitToLast(50)
      .onValue;
  late final personal = FirebaseService.db
      .ref('notifications/${FirebaseAuth.instance.currentUser!.uid}')
      .orderByChild('createdAt')
      .limitToLast(50)
      .onValue;
  List<Map<String, dynamic>> _rows(DatabaseEvent? e) {
    final raw = e?.snapshot.value;
    if (raw is! Map) return [];
    return raw.entries
        .where((e) => e.value is Map)
        .map((e) => Map<String, dynamic>.from(e.value as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) => StoreScaffold(
    title: 'Notifications',
    body: Column(
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: NotificationService.status,
          builder: (_, status, __) => ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(status ?? 'Receive store and order updates'),
            trailing: TextButton(
              onPressed: () => NotificationService.attachUser(
                FirebaseAuth.instance.currentUser!,
              ),
              child: const Text('Enable'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: announcements,
            builder: (context, a) => StreamBuilder<DatabaseEvent>(
              stream: personal,
              builder: (context, b) {
                if (a.hasError || b.hasError)
                  return const Center(
                    child: Text('Unable to load notifications.'),
                  );
                if (!a.hasData || !b.hasData)
                  return const Center(child: CircularProgressIndicator());
                final rows = [..._rows(a.data), ..._rows(b.data)]
                  ..sort(
                    (x, y) => ((y['createdAt'] as num?) ?? 0).compareTo(
                      (x['createdAt'] as num?) ?? 0,
                    ),
                  );
                if (rows.isEmpty)
                  return const Center(child: Text('No notifications yet.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      (row['createdAt'] as num?)?.toInt() ?? 0,
                    ).toLocal();
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: Text('${row['title'] ?? 'Store update'}'),
                        subtitle: Text(
                          '${row['body'] ?? ''}\n${date.toString().split('.').first}',
                        ),
                        onTap: () async {
                          if (row['type'] == 'order') {
                            Navigator.pushNamed(context, '/orders');
                            return;
                          }
                          if (row['bookId'] != null) {
                            try {
                              final books = await StoreService.booksOnce();
                              final found = books.where(
                                (book) => book.id == row['bookId'],
                              );
                              if (context.mounted && found.isNotEmpty) {
                                Navigator.pushNamed(
                                  context,
                                  '/details',
                                  arguments: found.first,
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This book is no longer in the catalog.',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unable to open book.'),
                                  ),
                                );
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
