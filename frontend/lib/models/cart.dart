import 'package:cybertranspay/models/product.dart';

class CartItem {
  CartItem({required this.product, required this.quantity});

  final Product product;
  int quantity;

  double get lineTotal => product.priceEur * quantity;

  Map<String, dynamic> toOrderJson() => {
        'product_id': product.id,
        'quantity': quantity,
      };
}

class Cart {
  Cart() : _items = [];

  final List<CartItem> _items;

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotalEur => _items.fold(0.0, (sum, i) => sum + i.lineTotal);

  bool get isEmpty => _items.isEmpty;

  void add(Product product, {int quantity = 1}) {
    final existing = _items.where((i) => i.product.id == product.id);
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
  }

  void remove(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    final existing = _items.where((i) => i.product.id == productId);
    if (existing.isNotEmpty) {
      existing.first.quantity = quantity;
    }
  }

  void clear() => _items.clear();
}
