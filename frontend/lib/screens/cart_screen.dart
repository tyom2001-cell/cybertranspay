import 'package:cybertranspay/models/cart.dart';
import 'package:cybertranspay/screens/checkout_screen.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:cybertranspay/services/marketplace_client.dart';
import 'package:flutter/material.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.cart,
    required this.marketplace,
    required this.api,
    required this.buyerId,
  });

  final Cart cart;
  final MarketplaceClient marketplace;
  final ApiClient api;
  final String buyerId;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  void _updateQuantity(String productId, int delta) {
    final item = widget.cart.items
        .where((i) => i.product.id == productId)
        .firstOrNull;
    if (item == null) return;
    setState(() {
      widget.cart.updateQuantity(productId, item.quantity + delta);
    });
  }

  void _remove(String productId) {
    setState(() => widget.cart.remove(productId));
  }

  void _goToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cart: widget.cart,
          marketplace: widget.marketplace,
          api: widget.api,
          buyerId: widget.buyerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = widget.cart.items;
    return Scaffold(
      backgroundColor: const Color(0xFF060816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060816),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Корзина', style: TextStyle(color: Colors.white)),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => widget.cart.clear()),
              child: const Text('Очистить',
                  style: TextStyle(color: Colors.white54)),
            ),
        ],
      ),
      body: widget.cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Корзина пуста',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.product.priceEur.toStringAsFixed(2)} € × ${item.quantity} = ${item.lineTotal.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _updateQuantity(item.product.id, 1),
                                  icon: const Icon(Icons.add,
                                      color: Colors.white70, size: 18),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _updateQuantity(item.product.id, -1),
                                  icon: const Icon(Icons.remove,
                                      color: Colors.white70, size: 18),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => _remove(item.product.id),
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildSummary(cs),
              ],
            ),
    );
  }

  Widget _buildSummary(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого:',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              Text(
                '${widget.cart.subtotalEur.toStringAsFixed(2)} €',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _goToCheckout,
              child: const Text(
                'Оформить заказ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
