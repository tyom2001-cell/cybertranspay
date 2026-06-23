class Product {
  Product({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.priceEur,
    required this.stock,
    required this.active,
    required this.createdAt,
    this.imageUrl,
  });

  final String id;
  final String sellerId;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final double priceEur;
  final int stock;
  final bool active;
  final DateTime createdAt;
  final String? imageUrl;

  bool get inStock => stock > 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      priceEur: (json['price_eur'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seller_id': sellerId,
        'title': title,
        'description': description,
        'category': category,
        'tags': tags,
        'price_eur': priceEur,
        'stock': stock,
        'active': active,
        'created_at': createdAt.toIso8601String(),
        if (imageUrl != null) 'image_url': imageUrl,
      };
}
