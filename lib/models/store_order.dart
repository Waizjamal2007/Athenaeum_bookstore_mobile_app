import 'package:intl/intl.dart';

class StoreOrder {
  final String id;
  final Map<String, dynamic> data;
  const StoreOrder(this.id, this.data);
  static const statuses = ['Placed', 'Processing', 'Dispatched', 'Delivered'];
  String get status => '${data['status'] ?? 'Placed'}';
  int get stage =>
      statuses.indexWhere((s) => s.toLowerCase() == status.toLowerCase());
  double get total => double.tryParse('${data['total'] ?? 0}') ?? 0;
  String get userId => '${data['userId'] ?? ''}';
  String get address => '${data['shippingAddress'] ?? data['address'] ?? ''}';
  String get date {
    final millis = int.tryParse('${data['createdAt'] ?? ''}');
    return millis == null || millis <= 0
        ? 'Date unavailable'
        : DateFormat('d MMM yyyy, h:mm a')
              .format(DateTime.fromMillisecondsSinceEpoch(millis).toLocal());
  }

  List<Map<String, dynamic>> get items {
    final raw = data['items'];
    final Iterable values = raw is List
        ? raw
        : raw is Map
        ? raw.values
        : const [];
    return values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  int get quantity => items.fold(
    0,
    (n, i) => n + (int.tryParse('${i['qty'] ?? i['quantity'] ?? 1}') ?? 1),
  );
  static List<StoreOrder> rows(Object? raw) {
    if (raw is! Map) return [];
    final rows = raw.entries
        .where((e) => e.value is Map)
        .map(
          (e) =>
              StoreOrder('${e.key}', Map<String, dynamic>.from(e.value as Map)),
        )
        .toList();
    rows.sort(
      (a, b) => (int.tryParse('${b.data['createdAt']}') ?? 0).compareTo(
        int.tryParse('${a.data['createdAt']}') ?? 0,
      ),
    );
    return rows;
  }
}
