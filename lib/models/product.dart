class Product {
  final String id;
  final String name;
  final String type;
  final int quantity;
  final double price;
  final String notes;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.type,
    required this.quantity,
    required this.price,
    required this.notes,
    required this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'quantity': quantity,
      'price': price,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
