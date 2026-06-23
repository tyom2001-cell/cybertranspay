import 'package:cybertranspay/models/product.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:cybertranspay/services/marketplace_client.dart';
import 'package:flutter/material.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({
    super.key,
    required this.marketplace,
    required this.sellerId,
  });

  final MarketplaceClient marketplace;
  final String sellerId;

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  List<Product> _products = [];
  bool _loading = false;
  String? _error;

  // Add product form controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products =
          await widget.marketplace.listProducts(sellerId: widget.sellerId);
      if (mounted) setState(() => _products = products);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddProductDialog() async {
    _titleCtrl.clear();
    _descCtrl.clear();
    _categoryCtrl.clear();
    _priceCtrl.clear();
    _stockCtrl.text = '1';

    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddProductDialog(
        titleCtrl: _titleCtrl,
        descCtrl: _descCtrl,
        categoryCtrl: _categoryCtrl,
        priceCtrl: _priceCtrl,
        stockCtrl: _stockCtrl,
        onConfirm: (price, stock) async {
          await widget.marketplace.createProduct(
            sellerId: widget.sellerId,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            category: _categoryCtrl.text.trim(),
            priceEur: price,
            stock: stock,
          );
          await _loadProducts();
        },
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Кабинет продавца',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: cs.primary,
        icon: const Icon(Icons.add),
        label: const Text('Новый товар'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_outlined,
                              color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'У вас нет товаров',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 18),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _showAddProductDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить первый товар'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _products.length,
                      itemBuilder: (_, i) =>
                          _SellerProductCard(product: _products[i]),
                    ),
    );
  }
}

// ── Add product dialog ────────────────────────────────────────────────────────

class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({
    required this.titleCtrl,
    required this.descCtrl,
    required this.categoryCtrl,
    required this.priceCtrl,
    required this.stockCtrl,
    required this.onConfirm,
  });

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stockCtrl;
  final Future<void> Function(double price, int stock) onConfirm;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final price = double.tryParse(widget.priceCtrl.text.trim()) ?? 0;
    final stock = int.tryParse(widget.stockCtrl.text.trim()) ?? 0;

    if (widget.titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Введите название товара');
      return;
    }
    if (widget.categoryCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Введите категорию');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Введите корректную цену');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onConfirm(price, stock);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1323),
      title: const Text(
        'Добавить товар',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            _Field(ctrl: widget.titleCtrl, label: 'Название'),
            const SizedBox(height: 10),
            _Field(ctrl: widget.descCtrl, label: 'Описание', maxLines: 3),
            const SizedBox(height: 10),
            _Field(ctrl: widget.categoryCtrl, label: 'Категория'),
            const SizedBox(height: 10),
            _Field(
              ctrl: widget.priceCtrl,
              label: 'Цена (EUR)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _Field(
              ctrl: widget.stockCtrl,
              label: 'Остаток (шт.)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child:
              const Text('Отмена', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }
}

// ── Product card for seller list ──────────────────────────────────────────────

class _SellerProductCard extends StatelessWidget {
  const _SellerProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white38,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.category,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.priceEur.toStringAsFixed(2)} €',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Остаток: ${product.stock}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: product.active
                      ? Colors.greenAccent.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  product.active ? 'Активен' : 'Снят',
                  style: TextStyle(
                    color: product.active ? Colors.greenAccent : Colors.red,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
