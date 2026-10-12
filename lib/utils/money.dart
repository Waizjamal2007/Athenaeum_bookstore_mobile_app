// Sum integer cents to avoid binary floating-point surprises with prices.
int priceCents(double price) => (price * 100).round();
int lineCents(double price, int quantity) => priceCents(price) * quantity;
String money(Object? value) =>
    '\$${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';
