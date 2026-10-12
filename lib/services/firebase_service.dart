import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static const databaseUrl =
      'https://athenaeum-8845d-default-rtdb.firebaseio.com/';
  static final db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: databaseUrl,
  );

  static DatabaseReference get books => db.ref('books');
  static DatabaseReference get users => db.ref('users');
  static DatabaseReference get carts => db.ref('carts');
  static DatabaseReference get wishlists => db.ref('wishlists');
  static DatabaseReference get orders => db.ref('orders');
  static DatabaseReference get reviews => db.ref('reviews');
}
