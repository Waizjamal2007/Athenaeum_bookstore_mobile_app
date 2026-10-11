import 'package:flutter_test/flutter_test.dart';
import 'package:athenaeum_bookstore/main.dart';

void main() {
testWidgets('Athenaeum app loads', (WidgetTester tester) async {
await tester.pumpWidget(const AthenaeumApp());

expect(find.text('ATHENAEUM'), findsWidgets);
});
}
