import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/store_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
final ValueChanged<int> onIndex;

const ProfileScreen({
super.key,
required this.onIndex,
});

@override
State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
Map<String, dynamic> profile = {};
List<Map<String, dynamic>> orders = [];
bool loading = true;
StreamSubscription<DatabaseEvent>? _profileSubscription, _orderSubscription;
@override void dispose() {
  _profileSubscription?.cancel(); _orderSubscription?.cancel(); super.dispose();
}
void _watch() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  _profileSubscription = FirebaseService.users.child(user.uid).onValue.listen((event) {
    if (mounted && event.snapshot.value is Map) setState(() =>
      profile = Map<String, dynamic>.from(event.snapshot.value as Map));
  }, onError: (Object error) { /* SessionGuard handles access failures. */ });
  _orderSubscription = FirebaseService.orders.orderByChild('userId').equalTo(user.uid).onValue.listen((event) {
    final raw = event.snapshot.value;
    final data = raw is Map ? raw.entries.where((e) => e.value is Map).map((e) =>
      <String, dynamic>{...Map<String, dynamic>.from(e.value as Map), 'id': '${e.key}'}).toList()
      : <Map<String, dynamic>>[];
    data.sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    if (mounted) setState(() => orders = data);
  }, onError: (Object error) { /* SessionGuard handles access failures. */ });
}

@override
void initState() {
super.initState();
_load();
_watch();
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
profile = await StoreService.getProfile(user.uid);

final snapshot = await FirebaseService.orders
    .orderByChild('userId')
    .equalTo(user.uid)
    .get();

final raw = snapshot.value;

if (raw is Map) {
orders = raw.entries
    .map(
(entry) => {
'id': '${entry.key}',
...Map<String, dynamic>.from(entry.value as Map),
},
)
    .toList()
    .reversed
    .toList();
}

if (!mounted) return;

setState(() {
loading = false;
});
} catch (e) {
if (!mounted) return;

setState(() {
loading = false;
});

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Unable to load profile: $e'),
),
);
}
}

Future<void> _edit() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final name = TextEditingController(text: '${profile['name'] ?? user.displayName ?? ''}');
  final address = TextEditingController(text: '${profile['shippingAddress'] ?? ''}');
  final method = TextEditingController(text: '${profile['paymentMethod'] ?? ''}');
  bool saving = false;
  String? error;
  final changed = await showDialog<bool>(context: context, barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(builder: (context, update) =>
      PopScope(canPop: !saving, child: AlertDialog(title: const Text('Edit Profile'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, enabled: !saving, maxLength: 80,
            decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 10),
          TextField(controller: address, enabled: !saving, maxLength: 500, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Shipping address')),
          const SizedBox(height: 10),
          TextField(controller: method, enabled: !saving, maxLength: 100,
            decoration: const InputDecoration(labelText: 'Payment preference',
              helperText: 'For example Cash on delivery. Do not enter card details.')),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        ])), actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: saving ? null : () async {
            update(() { saving = true; error = null; });
            try {
              await AuthService.updateProfile(name: name.text, address: address.text, paymentMethod: method.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (e) {
              if (dialogContext.mounted) update(() { saving = false; error = '$e'; });
            }
          }, child: Text(saving ? 'Saving...' : 'Save')),
        ]))));
  name.dispose(); address.dispose(); method.dispose();
  if (changed == true && mounted) await _load();
}

@override
Widget build(BuildContext context) {
final user = FirebaseAuth.instance.currentUser;

return Scaffold(
appBar: AppBar(
leading: IconButton(onPressed: () => widget.onIndex(0), icon: const Icon(Icons.arrow_back)),
title: const Text('Patron Profile'),
actions: [
IconButton(tooltip: 'Notifications', onPressed: () => Navigator.pushNamed(context, '/notifications'), icon: const Icon(Icons.notifications_outlined)),
IconButton(
onPressed: () => context.read<ThemeController>().toggle(),
icon: Icon(
context.watch<ThemeController>().isDark
? Icons.light_mode_outlined
: Icons.dark_mode_outlined,
),
tooltip: 'Toggle theme',
),
IconButton(
onPressed: _edit,
icon: const Icon(Icons.settings_outlined),
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
Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Row(
children: [
const CircleAvatar(radius: 28, child: Icon(Icons.person_outline, size: 30)),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
profile['name'] ??
user?.displayName ??
'Patron',
style: Theme.of(context)
    .textTheme
    .titleLarge,
),
Text(
profile['email'] ??
user?.email ??
'',
style: const TextStyle(
fontSize: 11,
color: AppTheme.muted,
),
),
const SizedBox(height: 5),
Text(
orders.length == 1
? '1 VOLUME'
    : '${orders.length} VOLUMES',
style: const TextStyle(
fontSize: 9,
letterSpacing: 1.2,
color: AppTheme.accent,
),
),
],
),
),
],
),
),
),
const SizedBox(height: 14),
Text(
'Active Consignments',
style: Theme.of(context).textTheme.titleLarge,
),
const SizedBox(height: 7),
if (orders.isEmpty)
const Card(
child: Padding(
padding: EdgeInsets.all(15),
child: Text(
'No orders yet. Your consignments will appear here.',
),
),
),
...orders.map(
(order) => Card(
child: ListTile(
leading: const Icon(
Icons.inventory_2_outlined,
),
title: Text(
'Order ${order['id']}',
),
subtitle: Text(
'${order['status'] ?? 'Placed'} · \$${order['total'] ?? 0}',
),
trailing: const Icon(
Icons.chevron_right,
),
),
),
),
const SizedBox(height: 12),
Text(
'Account',
style: Theme.of(context).textTheme.titleLarge,
),
const SizedBox(height: 7),
Card(
child: Column(
children: [
ListTile(
leading: const Icon(
Icons.location_on_outlined,
),
title: const Text('Shipping Address'),
subtitle: Text(
'${profile['shippingAddress'] ?? 'Not set'}',
),
),
const Divider(height: 1),
ListTile(
leading: const Icon(
Icons.credit_card_outlined,
),
title: const Text('Payment Method'),
subtitle: Text(
'${profile['paymentMethod'] ?? 'Not set'}',
),
),
const Divider(height: 1),
ListTile(
leading: const Icon(Icons.logout),
title: const Text('Sign Out'),
onTap: () async {
await AuthService.logout();

if (!mounted) return;

Navigator.pushNamedAndRemoveUntil(
context,
'/auth',
(_) => false,
);
},
),
],
),
),
],
),
);
}
}

