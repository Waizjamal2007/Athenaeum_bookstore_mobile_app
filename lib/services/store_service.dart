import 'package:firebase_database/firebase_database.dart';

import '../models/book.dart';
import 'firebase_service.dart';
import 'api_service.dart';

class StoreService {
  static List<Book> _books(Object? raw) {
    if (raw is! Map) return [];

    return raw.entries
        .where((e) => e.value is Map)
        .map(
          (e) => Book.fromMap(
            '${e.key}',
            Map<dynamic, dynamic>.from(e.value as Map),
          ),
        )
        .toList();
  }

  static Stream<List<Book>> booksStream() =>
      FirebaseService.books.onValue.map((e) => _books(e.snapshot.value));

  static Future<List<Book>> booksOnce() async =>
      _books((await FirebaseService.books.get()).value);

  // Kept for compatibility. No automatic demo-book insertion.
  static Future<void> ensureSeedBooks() async {}

  static Future<Map<String, dynamic>> addBook(Book book) => ApiService.post(
    'saveBook',
    {'mode': 'add', 'id': book.id, 'book': book.toMap()},
  );

  static Future<Map<String, dynamic>> updateBook(Book book) => ApiService.post(
    'saveBook',
    {'mode': 'update', 'id': book.id, 'book': book.toMap()},
  );

  static Future<Map<String, dynamic>> deleteBook(String id) =>
      ApiService.post('deleteBook', {'id': id});

  static Future<List<Map<String, dynamic>>> getReviews(String bookId) async {
    final raw = (await FirebaseService.reviews.child(bookId).get()).value;

    if (raw is! Map) return [];

    final rows = raw.entries
        .where((e) => e.value is Map)
        .map(
          (e) => <String, dynamic>{
            ...Map<String, dynamic>.from(e.value as Map),
            'id': '${e.key}',
          },
        )
        .toList();

    rows.sort(
      (a, b) => ((b['createdAt'] as num?) ?? 0).compareTo(
        (a['createdAt'] as num?) ?? 0,
      ),
    );

    return rows;
  }

  static Future<void> addReview({
    required String bookId,
    required String uid,
    required String name,
    required double rating,
    required String text,
  }) => FirebaseService.reviews.child(bookId).push().set({
    'userId': uid,
    'name': name.trim(),
    'rating': rating,
    'text': text.trim(),
    'likes': 0,
    'createdAt': ServerValue.timestamp,
  });

  static Future<void> updateReview({
    required String bookId,
    required String reviewId,
    required double rating,
    required String text,
  }) => FirebaseService.reviews.child(bookId).child(reviewId).update({
    'rating': rating,
    'text': text.trim(),
    'updatedAt': ServerValue.timestamp,
  });

  static Future<void> deleteReview(String bookId, String reviewId) =>
      FirebaseService.reviews.child(bookId).child(reviewId).remove();

  static Future<void> likeReview(
    String bookId,
    String reviewId,
    int currentLikes,
  ) async {
    await ApiService.post('likeReview', {
      'bookId': bookId,
      'reviewId': reviewId,
    });
  }

  static Future<void> saveProfile(String uid, Map<String, dynamic> data) =>
      FirebaseService.users.child(uid).update(data);

  static Future<Map<String, dynamic>> getProfile(String uid) async {
    final value = (await FirebaseService.users.child(uid).get()).value;

    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  static Future<void> setWishlist(String uid, String bookId, bool saved) async {
    final ref = FirebaseService.wishlists.child(uid).child(bookId);

    if (saved) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  }

  static Future<Set<String>> getWishlist(String uid) async {
    final raw = (await FirebaseService.wishlists.child(uid).get()).value;

    return raw is Map ? raw.keys.map((e) => '$e').toSet() : <String>{};
  }

  static Future<void> setCartItem(String uid, String bookId, int qty) async {
    final ref = FirebaseService.carts.child(uid).child(bookId);

    if (qty <= 0) {
      await ref.remove();
    } else {
      await ref.set(qty);
    }
  }

  static Future<Map<String, int>> getCart(String uid) async {
    final raw = (await FirebaseService.carts.child(uid).get()).value;

    return raw is Map
        ? raw.map((k, v) => MapEntry('$k', int.tryParse('$v') ?? 0))
        : <String, int>{};
  }

  static String? _checkoutSignature;
  static String? _checkoutId;

  static Future<String> createOrder(
    String uid,
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final rows =
        items
            .map(
              (i) => <String, dynamic>{'bookId': i['bookId'], 'qty': i['qty']},
            )
            .toList()
          ..sort((a, b) => '${a['bookId']}'.compareTo('${b['bookId']}'));

    final signature =
        '$uid:${rows.map((i) => '${i['bookId']}:${i['qty']}').join('|')}';

    if (_checkoutSignature != signature) {
      _checkoutSignature = signature;
      _checkoutId = ApiService.requestId();
    }

    final result = await ApiService.post('createOrder', {
      'items': rows,
      'requestId': _checkoutId,
    });

    final orderId = result['orderId'];
    if (orderId == null || '$orderId'.trim().isEmpty) {
      throw StateError(
        'Order confirmation is missing. Check My orders before retrying.',
      );
    }
    _checkoutSignature = null;
    _checkoutId = null;
    return '$orderId';
  }
}
