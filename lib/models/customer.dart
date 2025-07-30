class Customer {
  final String id;
  final String name;
  final String phoneNumber;
  final String notes;
  final DateTime date;
  final double invoiceAmount;
  final double paidAmount;
  final double remainingAmount;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.notes,
    required this.date,
    required this.invoiceAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'notes': notes,
      'date': date.toIso8601String(),
      'invoiceAmount': invoiceAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      notes: map['notes'] ?? '',
      date: DateTime.parse(map['date']),
      invoiceAmount: (map['invoiceAmount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      remainingAmount: (map['remainingAmount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? notes,
    DateTime? date,
    double? invoiceAmount,
    double? paidAmount,
    double? remainingAmount,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      invoiceAmount: invoiceAmount ?? this.invoiceAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
