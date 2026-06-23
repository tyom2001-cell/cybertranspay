import 'package:cybertranspay/models/cart.dart';
import 'package:cybertranspay/models/product.dart';
import 'package:flutter/material.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.cart,
  });

  final Product product;
  final Cart cart;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _addToCart() {
    widget.cart.add(widget.product, quantity: _quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_quantity}× «${widget.product.title}» добавлен в корзину',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = widget.product;
    return Scaffold(
      backgroundColor: const Color(0xFF060816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060816),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          product.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: product.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.white24,
                          size: 60,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white24,
                        size: 60,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            // Category chip
            Chip(
              label: Text(product.category),
              backgroundColor: cs.primary.withOpacity(0.15),
              labelStyle: TextStyle(color: cs.primary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              product.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Price
            Text(
              '${product.priceEur.toStringAsFixed(2)} €',
              style: TextStyle(
                color: cs.primary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            // Stock
            Text(
              product.inStock
                  ? 'В наличии: ${product.stock} шт.'
                  : 'Нет в наличии',
              style: TextStyle(
                color: product.inStock ? Colors.greenAccent : Colors.red,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              product.description,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.75), height: 1.5),
            ),
            if (product.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: product.tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),
            // Quantity selector
            if (product.inStock) ...[
              Row(
                children: [
                  const Text(
                    'Количество:',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white70),
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _quantity < product.stock
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _addToCart,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(
                    'Добавить в корзину (${(product.priceEur * _quantity).toStringAsFixed(2)} €)',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
