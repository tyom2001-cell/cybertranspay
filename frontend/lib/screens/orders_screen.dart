import 'package:cybertranspay/models/order.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:cybertranspay/services/marketplace_client.dart';
import 'package:flutter/material.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.marketplace,
    required this.buyerId,
  });

  final MarketplaceClient marketplace;
  final String buyerId;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await widget.marketplace.listOrders(widget.buyerId);
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => Colors.orange,
      OrderStatus.paymentInitiated => Colors.blue,
      OrderStatus.settled => Colors.cyan,
      OrderStatus.fulfilled => Colors.greenAccent,
      OrderStatus.cancelled => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060816),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Мои заказы', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrders,
          ),
        ],
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
                          onPressed: _loadOrders,
                          child: const Text('Повторить')),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              color: Colors.white24, size: 64),
                          SizedBox(height: 16),
                          Text('Нет заказов',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 18)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order: _orders[i],
                          statusColor: _statusColor(_orders[i].status),
                        ),
                      ),
                    ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.statusColor});

  final Order order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Заказ #${order.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.title} × ${item.quantity}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(order.createdAt),
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Text(
                '${order.totalEur.toStringAsFixed(2)} €',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (order.transferId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Transfer: ${order.transferId!.substring(0, 8)}...',
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
