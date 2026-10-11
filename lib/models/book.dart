class Book {
  final String id, title, author, genre, description, imageUrl;
  final double price, rating;
  final int stock, year;
  final bool bestseller, newArrival;

  const Book({
    required this.id, required this.title, required this.author, required this.genre,
    required this.description, required this.imageUrl, required this.price,
    this.rating = 4.5, this.stock = 10, this.year = 2024,
    this.bestseller = false, this.newArrival = false,
  });

  factory Book.fromMap(String id, Map<dynamic, dynamic> m) => Book(
    id: id,
    title: '${m['title'] ?? ''}',
    author: '${m['author'] ?? ''}',
    genre: '${m['genre'] ?? 'Literary Fiction'}',
    description: '${m['description'] ?? ''}',
    imageUrl: '${m['imageUrl'] ?? ''}',
    price: double.tryParse('${m['price'] ?? 0}') ?? 0,
    rating: double.tryParse('${m['rating'] ?? 4.5}') ?? 4.5,
    stock: int.tryParse('${m['stock'] ?? 10}') ?? 10,
    year: int.tryParse('${m['year'] ?? 2024}') ?? 2024,
    bestseller: m['bestseller'] == true,
    newArrival: m['newArrival'] == true,
  );

  Map<String, dynamic> toMap() => {
    'title': title, 'author': author, 'genre': genre, 'description': description,
    'imageUrl': imageUrl, 'price': price, 'rating': rating, 'stock': stock,
    'year': year, 'bestseller': bestseller, 'newArrival': newArrival,
  };
}
