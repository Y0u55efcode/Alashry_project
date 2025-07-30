class Invoice {
  final String id;
  final String customerName;
  final DateTime date;
  final List<InvoiceItem> items;
  final double totalAmount;

  Invoice({
    required this.id,
    required this.customerName,
    required this.date,
    required this.items,
    required this.totalAmount,
  });

  factory Invoice.fromMap(Map<String, dynamic> map, String id) {
    return Invoice(
      id: id,
      customerName: map['customerName'] ?? '',
      date: DateTime.parse(map['date']),
      items: (map['items'] as List)
          .map((item) => InvoiceItem.fromMap(item))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'date': date.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
    };
  }
}

class InvoiceItem {
  final String productId; // <--- تم إضافة هذا الحقل
  final String productName;
  final String productType;
  final int quantity;
  final double price;
  final double total;

  InvoiceItem({
    required this.productId, // <--- تم إضافة هذا الحقل
    required this.productName,
    required this.productType,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'] ?? '', // <--- تم إضافة هذا الحقل
      productName: map['productName'] ?? '',
      productType: map['productType'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId, // <--- تم إضافة هذا الحقل
      'productName': productName,
      'productType': productType,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }
}
