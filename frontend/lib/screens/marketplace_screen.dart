import 'package:cybertranspay/models/cart.dart';
import 'package:cybertranspay/models/product.dart';
import 'package:cybertranspay/screens/cart_screen.dart';
import 'package:cybertranspay/screens/product_detail_screen.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:cybertranspay/services/marketplace_client.dart';
import 'package:flutter/material.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    super.key,
    required this.marketplace,
    required this.api,
    required this.buyerId,
  });

  final MarketplaceClient marketplace;
  final ApiClient api;
  final String buyerId;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final Cart _cart = Cart();
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedCategory;
  List<String> _categories = [];
  List<Product> _products = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await widget.marketplace.listCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await widget.marketplace.listProducts(
        category: _selectedCategory,
        query: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        inStock: true,
      );
      if (mounted) setState(() => _products = products);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cart: _cart,
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
    return Scaffold(
      backgroundColor: const Color(0xFF060816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060816),
        title: const Text(
          'Маркетплейс',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: _openCart,
              ),
              if (_cart.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_cart.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Поиск товаров...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon:
              Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchCtrl.clear();
                    _loadProducts();
                  },
                )
              : null,
        ),
        onSubmitted: (_) => _loadProducts(),
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Все'),
              selected: _selectedCategory == null,
              onSelected: (_) {
                setState(() => _selectedCategory = null);
                _loadProducts();
              },
            ),
          ),
          ..._categories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat),
                selected: _selectedCategory == cat,
                onSelected: (_) {
                  setState(
                    () => _selectedCategory =
                        _selectedCategory == cat ? null : cat,
                  );
                  _loadProducts();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'Товары не найдены',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _products.length,
        itemBuilder: (_, i) => _ProductCard(
          product: _products[i],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: _products[i],
                  cart: _cart,
                ),
              ),
            );
            setState(() {});
          },
          onAddToCart: () {
            _cart.add(_products[i]);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('«${_products[i].title}» добавлен в корзину'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.white24,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.priceEur.toStringAsFixed(2)} €',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: cs.primary.withOpacity(0.2),
                        foregroundColor: cs.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: product.inStock ? onAddToCart : null,
                      child: Text(
                        product.inStock ? 'В корзину' : 'Нет в наличии',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
