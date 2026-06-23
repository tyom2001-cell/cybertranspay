import 'package:cybertranspay/models/cart.dart';
import 'package:cybertranspay/models/order.dart';
import 'package:cybertranspay/models/route_quote.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:cybertranspay/services/marketplace_client.dart';
import 'package:flutter/material.dart';

enum _Step { details, payment, confirmation }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
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
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  _Step _step = _Step.details;

  // Step 1 — details
  final _countryCtrl = TextEditingController(text: 'DE');
  final _currencyCtrl = TextEditingController(text: 'EUR');
  final _promoCtrl = TextEditingController();

  // Step 2 — payment route
  Order? _order;
  QuoteResponse? _quote;
  RouteQuote? _selectedRoute;
  bool _loading = false;
  String? _error;

  // Step 3 — done
  Order? _confirmedOrder;

  @override
  void dispose() {
    _countryCtrl.dispose();
    _currencyCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.marketplace.createOrder(
        buyerId: widget.buyerId,
        cart: widget.cart,
        buyerCountry: _countryCtrl.text.trim().toUpperCase(),
        currency: _currencyCtrl.text.trim().toUpperCase(),
        promotionCode: _promoCtrl.text.trim().isEmpty
            ? null
            : _promoCtrl.text.trim(),
      );

      // Fetch quote from routing-engine for the total
      final quoteReq = QuoteRequest(
        fromAsset: _currencyCtrl.text.trim().toUpperCase(),
        toAsset: 'EUR',
        amount: order.totalEur,
        preference: 'cheapest',
      );
      final quote = await widget.api.fetchQuote(quoteReq);

      setState(() {
        _order = order;
        _quote = quote;
        _selectedRoute = quote.routes.isNotEmpty ? quote.routes.first : null;
        _step = _Step.payment;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmPayment() async {
    if (_order == null || _quote == null || _selectedRoute == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Record quote with marketplace
      final initiated = await widget.marketplace
          .initiatePayment(_order!.id, _quote!.quoteId);

      // Execute transfer via routing-engine
      final transfer = await widget.api.createTransfer(
        CreateTransferRequest(
          quoteId: _quote!.quoteId,
          routeId: _selectedRoute!.routeId,
        ),
      );

      // Confirm settlement with marketplace
      final confirmed = await widget.marketplace
          .confirmPayment(initiated.id, transfer.transferId);

      // Clear the cart
      widget.cart.clear();

      setState(() {
        _confirmedOrder = confirmed;
        _step = _Step.confirmation;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060816),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Оформление заказа',
            style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : switch (_step) {
              _Step.details => _buildDetailsStep(),
              _Step.payment => _buildPaymentStep(),
              _Step.confirmation => _buildConfirmationStep(),
            },
    );
  }

  Widget _buildDetailsStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Ваш заказ'),
          ...widget.cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.product.title} × ${item.quantity}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.lineTotal.toStringAsFixed(2)} €',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого:', style: TextStyle(color: Colors.white70)),
              Text(
                '≈${widget.cart.subtotalEur.toStringAsFixed(2)} €',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('Страна доставки (ISO 3166-1)'),
          TextField(
            controller: _countryCtrl,
            style: const TextStyle(color: Colors.white),
            maxLength: 2,
            decoration: const InputDecoration(
              hintText: 'DE, FR, IT...',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Валюта оплаты'),
          TextField(
            controller: _currencyCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'EUR, USDT, BTC...',
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Промо-код (необязательно)'),
          TextField(
            controller: _promoCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Введите код скидки',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 32),
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
              onPressed: _createOrder,
              child: const Text(
                'Продолжить к оплате',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStep() {
    final cs = Theme.of(context).colorScheme;
    final order = _order!;
    final quote = _quote!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Сумма к оплате'),
          _infoRow('Подытог', '${order.subtotalEur.toStringAsFixed(2)} €'),
          if (order.discountEur > 0)
            _infoRow(
              'Скидка (${order.promotionCode ?? ""})',
              '−${order.discountEur.toStringAsFixed(2)} €',
              valueColor: Colors.greenAccent,
            ),
          _infoRow(
            'НДС (${order.buyerCountry})',
            '+${order.vatEur.toStringAsFixed(2)} €',
          ),
          const Divider(color: Colors.white24, height: 20),
          _infoRow('Итого', '${order.totalEur.toStringAsFixed(2)} €',
              bold: true),
          const SizedBox(height: 24),
          _sectionTitle('Выберите маршрут оплаты'),
          ...quote.routes.map(
            (route) => _RouteCard(
              route: route,
              selected: _selectedRoute?.routeId == route.routeId,
              onTap: () => setState(() => _selectedRoute = route),
            ),
          ),
          if (quote.routes.isEmpty)
            const Text('Маршруты недоступны',
                style: TextStyle(color: Colors.red)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 32),
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
              onPressed:
                  _selectedRoute != null ? _confirmPayment : null,
              child: const Text(
                'Оплатить',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    final order = _confirmedOrder!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.greenAccent, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Заказ оплачен!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ID заказа: ${order.id}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (order.transferId != null)
              Text(
                'Transfer ID: ${order.transferId}',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );

  Widget _infoRow(String label, String value,
      {Color? valueColor, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final RouteQuote route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : Colors.white.withOpacity(0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    route.rails.join(' → '),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Комиссия ${route.feePercent.toStringAsFixed(2)}%',
                  style: TextStyle(color: cs.primary, fontSize: 12),
                ),
                Text(
                  '~${route.etaMinutes} мин',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? cs.primary : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}
