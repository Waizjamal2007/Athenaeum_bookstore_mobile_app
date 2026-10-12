import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/store_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/book_image.dart';
import '../../widgets/book_badges.dart';
import '../../widgets/admin_shell.dart';
import 'admin_orders_screen.dart';

class AdminScreen extends StatefulWidget {
  final int initialIndex;
  const AdminScreen({super.key, this.initialIndex = 0});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late int index;
  List<Book> books = [];
  List<Map<String, dynamic>> orders = [];
  bool loading = true, retrying = false;
  String query = '';

  late final usersStream = FirebaseService.users.onValue;

  static const statuses = ['Placed', 'Processing', 'Dispatched', 'Delivered'];

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    _load();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _result(Map<String, dynamic> result, String success) =>
      '${result['warning'] ?? success}';

  Future<void> _load() async {
    try {
      final all = await StoreService.booksOnce();
      final raw = (await FirebaseService.orders.get()).value;

      final rows = raw is Map
          ? raw.entries
                .where((e) => e.value is Map)
                .map(
                  (e) => <String, dynamic>{
                    ...Map<String, dynamic>.from(e.value as Map),
                    'id': '${e.key}',
                  },
                )
                .toList()
          : <Map<String, dynamic>>[];

      rows.sort(
        (a, b) => ((b['createdAt'] as num?) ?? 0).compareTo(
          (a['createdAt'] as num?) ?? 0,
        ),
      );

      if (mounted) {
        setState(() {
          books = all;
          orders = rows;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
      _message('Unable to load admin data: $e');
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _bookForm({Book? book}) async {
    final initial = <String, String>{
      'Title': book?.title ?? '',
      'Author': book?.author ?? '',
      'Genre': book?.genre ?? 'Literary Fiction',
      'Price': '${book?.price ?? 0}',
      'Stock': '${book?.stock ?? 10}',
      'Year': '${book?.year ?? DateTime.now().year}',
      'Rating': '${book?.rating ?? 4.5}',
      'Description': book?.description ?? '',
    };

    final fields = initial.map(
      (k, v) => MapEntry(k, TextEditingController(text: v)),
    );

    bool best = book?.bestseller ?? false;
    bool fresh = book?.newArrival ?? true;
    bool saving = false;
    Uint8List? cover;
    String coverName = '';
    String image = book?.imageUrl ?? '';
    String? error;
    Map<String, dynamic>? savedResult;

    final id = book?.id ?? FirebaseService.books.push().key!;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (_, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(book == null ? 'Add Book' : 'Edit Book'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cover != null)
                      Image.memory(cover!, height: 130, fit: BoxFit.cover)
                    else if (image.isNotEmpty)
                      BookImage(source: image, width: 100, height: 130),
                    ...fields.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: entry.value,
                          enabled: !saving,
                          maxLines: entry.key == 'Description' ? 3 : 1,
                          keyboardType:
                              [
                                'Price',
                                'Stock',
                                'Year',
                                'Rating',
                              ].contains(entry.key)
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                )
                              : TextInputType.text,
                          decoration: InputDecoration(labelText: entry.key),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1400,
                                  maxHeight: 1800,
                                  imageQuality: 82,
                                );

                                if (picked == null) return;

                                final bytes = await picked.readAsBytes();

                                if (c.mounted) {
                                  update(() {
                                    cover = bytes;
                                    coverName = picked.name;
                                  });
                                }
                              } catch (e) {
                                if (c.mounted) {
                                  update(() => error = '$e');
                                }
                              }
                            },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Choose cover'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bestseller'),
                      value: best,
                      onChanged: saving ? null : (v) => update(() => best = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('New arrival'),
                      value: fresh,
                      onChanged: saving ? null : (v) => update(() => fresh = v),
                    ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final price = double.tryParse(fields['Price']!.text);
                        final rating = double.tryParse(fields['Rating']!.text);
                        final stock = int.tryParse(fields['Stock']!.text);
                        final year = int.tryParse(fields['Year']!.text);

                        if (fields['Title']!.text.trim().isEmpty ||
                            fields['Author']!.text.trim().isEmpty ||
                            price == null ||
                            !price.isFinite ||
                            price < 0 ||
                            rating == null ||
                            !rating.isFinite ||
                            rating < 0 ||
                            rating > 5 ||
                            stock == null ||
                            stock < 0 ||
                            year == null ||
                            year < 1 ||
                            year > 9999) {
                          update(
                            () => error =
                                'Enter title, author, valid price/'
                                'stock/year and rating 0–5.',
                          );
                          return;
                        }

                        update(() {
                          saving = true;
                          error = null;
                        });

                        try {
                          if (cover != null) {
                            try {
                              image = await SupabaseService.uploadBookCover(
                                fileName: coverName,
                                bytes: cover!,
                              );
                            } catch (_) {
                              if (cover!.length > 900000) {
                                throw StateError(
                                  'Cover too large. Fix Supabase '
                                  'upload policy or choose a smaller image.',
                                );
                              }

                              final ext =
                                  coverName.toLowerCase().endsWith('.png')
                                  ? 'png'
                                  : 'jpeg';

                              image =
                                  'data:image/$ext;base64,${base64Encode(cover!)}';
                            }

                            cover = null;
                          }

                          final value = Book(
                            id: id,
                            title: fields['Title']!.text.trim(),
                            author: fields['Author']!.text.trim(),
                            genre: fields['Genre']!.text.trim().isEmpty
                                ? 'Literary Fiction'
                                : fields['Genre']!.text.trim(),
                            description: fields['Description']!.text.trim(),
                            imageUrl: image,
                            price: price,
                            rating: rating,
                            stock: stock,
                            year: year,
                            bestseller: best,
                            newArrival: fresh,
                          );

                          savedResult = book == null
                              ? await StoreService.addBook(value)
                              : await StoreService.updateBook(value);

                          if (c.mounted) Navigator.pop(c);
                        } catch (e) {
                          if (c.mounted) {
                            update(() {
                              saving = false;
                              error = '$e';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final controller in fields.values) {
      controller.dispose();
    }

    if (savedResult != null) {
      await _load();
      _message(_result(savedResult!, 'Book saved; notification sent.'));
    }
  }

  Future<void> _deleteBook(Book book) async {
    if (!await _confirm(
      'Delete book?',
      'Remove ${book.title} from the catalog?',
    )) {
      return;
    }

    try {
      final result = await StoreService.deleteBook(book.id);
      await _load();
      _message(_result(result, 'Book deleted.'));
    } catch (e) {
      _message('$e');
    }
  }

  Future<void> _status(Map<String, dynamic> order, String status) async {
    try {
      final result = await AdminService.updateOrderStatus(
        '${order['id']}',
        status,
      );
      await _load();
      _message(_result(result, 'Order status updated.'));
    } catch (e) {
      _message('$e');
    }
  }

  Future<void> _manageUser(Map<String, dynamic> user, String action) async {
    final name = TextEditingController(text: '${user['name'] ?? ''}');
    final address = TextEditingController(
      text: '${user['shippingAddress'] ?? ''}',
    );
    final payment = TextEditingController(
      text: '${user['paymentMethod'] ?? ''}',
    );

    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (_, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(action == 'edit' ? 'Edit user' : '$action account?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action == 'edit') ...[
                    TextField(
                      controller: name,
                      maxLength: 80,
                      enabled: !saving,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: address,
                      maxLength: 500,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Shipping address',
                      ),
                    ),
                    TextField(
                      controller: payment,
                      maxLength: 100,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Payment preference',
                      ),
                    ),
                  ] else
                    Text(
                      action == 'delete'
                          ? 'Permanently delete ${user['email']}? '
                                'Orders and reviews remain as store records.'
                          : '$action sign-in for ${user['email']}?',
                    ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() {
                          saving = true;
                          error = null;
                        });

                        try {
                          await AdminService.manageUser(
                            '${user['uid']}',
                            action,
                            name: name.text,
                            address: address.text,
                            paymentMethod: payment.text,
                          );

                          if (c.mounted) Navigator.pop(c);
                          _message('Account updated.');
                        } catch (e) {
                          if (c.mounted) {
                            update(() {
                              saving = false;
                              error = '$e';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Confirm'),
              ),
            ],
          ),
        ),
      ),
    );

    name.dispose();
    address.dispose();
    payment.dispose();
  }

  Future<void> _announce() async {
    final title = TextEditingController();
    final body = TextEditingController();
    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (_, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Notify all readers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 100,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: body,
                  maxLength: 500,
                  maxLines: 3,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() {
                          saving = true;
                          error = null;
                        });

                        try {
                          final result = await AdminService.announce(
                            title.text,
                            body.text,
                          );
                          if (c.mounted) Navigator.pop(c);
                          _message(_result(result, 'Announcement sent.'));
                        } catch (e) {
                          if (c.mounted) {
                            update(() {
                              saving = false;
                              error = '$e';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Sending...' : 'Send'),
              ),
            ],
          ),
        ),
      ),
    );

    title.dispose();
    body.dispose();
  }

  Future<void> _retryPush() async {
    setState(() => retrying = true);

    try {
      final result = await AdminService.retryNotifications();
      final rows = result['results'] as List;
      final pending = rows.where((r) => r['push'] == 'pending').length;

      _message(
        'Retried ${rows.length} notifications; '
        '$pending still pending.',
      );
    } catch (e) {
      _message('$e');
    } finally {
      if (mounted) setState(() => retrying = false);
    }
  }

  Widget _users() => StreamBuilder<DatabaseEvent>(
    stream: usersStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Cannot load users. Check admin claim/rules.');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final raw = snapshot.data!.snapshot.value;

      final users = raw is Map
          ? raw.entries
                .where((e) => e.value is Map)
                .map(
                  (e) => <String, dynamic>{
                    ...Map<String, dynamic>.from(e.value as Map),
                    'uid': '${e.key}',
                  },
                )
                .toList()
          : <Map<String, dynamic>>[];

      final filtered = users
          .where(
            (u) => '${u['name']} ${u['email']}'.toLowerCase().contains(query),
          )
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${users.length} registered users'),
          if (filtered.isEmpty) const Text('No matching users.'),
          ...filtered.map(
            (u) => Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${u['name'] ?? 'Reader'}'),
                subtitle: Text(
                  '${u['email'] ?? ''}\n'
                  '${u['disabled'] == true ? 'Disabled' : 'Active'}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _manageUser(u, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit profile'),
                    ),
                    PopupMenuItem(
                      value: u['disabled'] == true ? 'enable' : 'disable',
                      child: Text(u['disabled'] == true ? 'Enable' : 'Disable'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => AdminShell(
    index: index,
    title: const [
      'Admin overview',
      'Book inventory',
      'User accounts',
      'Order management',
    ][index],
    onIndex: (i) {
      if (i != index)
        setState(() {
          index = i;
          query = '';
        });
    },
    actions: [
      IconButton(
        tooltip: 'Refresh data',
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: KeyedSubtree(
        key: ValueKey(index),
        child: index == 3
            ? const AdminOrdersScreen()
            : loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (index == 0) ...[
                              Text(
                                'Your bookstore at a glance',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _metric(
                                    'Books',
                                    '${books.length}',
                                    Icons.menu_book_outlined,
                                    1,
                                  ),
                                  _metric(
                                    'Orders',
                                    '${orders.length}',
                                    Icons.receipt_long_outlined,
                                    3,
                                  ),
                                  _metric(
                                    'Pending',
                                    '${orders.where((o) => o['status'] == 'Placed').length}',
                                    Icons.hourglass_empty,
                                    3,
                                  ),
                                  _metric(
                                    'Low stock',
                                    '${books.where((b) => b.stock <= 3).length}',
                                    Icons.inventory_2_outlined,
                                    1,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.payments_outlined),
                                  title: const Text('Recorded order value'),
                                  subtitle: Text(
                                    '\$${orders.fold<double>(0, (sum, o) => sum + (double.tryParse('${o['total']}') ?? 0)).toStringAsFixed(2)}',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Quick actions',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              ListTile(
                                leading: const Icon(Icons.add),
                                title: const Text('Add a book'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _bookForm(),
                              ),
                              ListTile(
                                leading: const Icon(Icons.people_outline),
                                title: const Text('Manage user accounts'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => setState(() => index = 2),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.local_shipping_outlined,
                                ),
                                title: const Text('Manage orders and delivery'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => setState(() => index = 3),
                              ),
                              const Divider(),
                              Text(
                                'Announcements',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _announce,
                                icon: const Icon(Icons.notifications_outlined),
                                label: const Text('Notify all readers'),
                              ),
                              TextButton(
                                onPressed: retrying ? null : _retryPush,
                                child: Text(
                                  retrying
                                      ? 'Retrying...'
                                      : 'Retry pending notifications',
                                ),
                              ),
                            ],
                            if (index == 1) ...[
                              FilledButton.icon(
                                onPressed: () => _bookForm(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add book'),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                onChanged: (v) => setState(
                                  () => query = v.trim().toLowerCase(),
                                ),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Search title, author or genre',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (books
                                  .where(
                                    (b) => '${b.title} ${b.author} ${b.genre}'
                                        .toLowerCase()
                                        .contains(query),
                                  )
                                  .isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('No matching books.'),
                                ),
                              ...books
                                  .where(
                                    (b) => '${b.title} ${b.author} ${b.genre}'
                                        .toLowerCase()
                                        .contains(query),
                                  )
                                  .map(
                                    (b) => Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            BookImage(
                                              source: b.imageUrl,
                                              width: 42,
                                              height: 60,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    b.title,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${b.author} · ${b.stock} in stock',
                                                  ),
                                                  Text(
                                                    '\$${b.price.toStringAsFixed(2)}',
                                                  ),
                                                  if (b.bestseller ||
                                                      b.newArrival) ...[
                                                    const SizedBox(height: 6),
                                                    BookBadges(book: b),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              onSelected: (s) {
                                                if (s == 'edit') {
                                                  _bookForm(book: b);
                                                } else {
                                                  _deleteBook(b);
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit book'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete book'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                            if (index == 2) ...[
                              Text(
                                'Reader accounts',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                onChanged: (v) => setState(
                                  () => query = v.trim().toLowerCase(),
                                ),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Search name or email',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _users(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
  Widget _metric(String label, String value, IconData icon, int destination) =>
      SizedBox(
        width: 150,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => index = destination),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      );
}
