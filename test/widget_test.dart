import 'package:flutter_test/flutter_test.dart';
import 'package:athenaeum_bookstore/main.dart';

void main() {
  testWidgets('Bookstore app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BookstoreApp());

    expect(find.text('Bookstore'), findsWidgets);
  });
}