class PurchaseDetail {
  final int? id;
  final String identityId;
  final DateTime createdAt;
  final int quantity;
  final String unit;
  final double price;
  final String supplier;
  final DateTime expireDate;

  PurchaseDetail({
    this.id,
    required this.identityId,
    required this.createdAt,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.supplier,
    required this.expireDate,
  });

  // Create from JSON (from Supabase)
  factory PurchaseDetail.fromJson(Map<String, dynamic> json) {
    return PurchaseDetail(
      id: json['id'] as int?,
      identityId: json['identity_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      quantity: json['quantity'] as int,
      unit: json['unit'] as String,
      price: (json['price'] as num).toDouble(),
      supplier: json['supplier'] as String,
      expireDate: DateTime.parse(json['expire_date'] as String),
    );
  }

  // Convert to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'identity_id': identityId,
      'created_at': createdAt.toIso8601String(),
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'supplier': supplier,
      'expire_date': expireDate.toIso8601String().split('T')[0], // Date only
    };
  }

  // Create a copy with updated fields
  PurchaseDetail copyWith({
    int? id,
    String? identityId,
    DateTime? createdAt,
    int? quantity,
    String? unit,
    double? price,
    String? supplier,
    DateTime? expireDate,
  }) {
    return PurchaseDetail(
      id: id ?? this.id,
      identityId: identityId ?? this.identityId,
      createdAt: createdAt ?? this.createdAt,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      supplier: supplier ?? this.supplier,
      expireDate: expireDate ?? this.expireDate,
    );
  }
}
