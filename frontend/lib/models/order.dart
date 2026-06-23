class OrderItem {
  OrderItem({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPriceEur,
    required this.lineTotalEur,
  });

  final String productId;
  final String title;
  final int quantity;
  final double unitPriceEur;
  final double lineTotalEur;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'] as String,
        title: json['title'] as String,
        quantity: (json['quantity'] as num).toInt(),
        unitPriceEur: (json['unit_price_eur'] as num).toDouble(),
        lineTotalEur: (json['line_total_eur'] as num).toDouble(),
      );
}

enum OrderStatus {
  pending,
  paymentInitiated,
  settled,
  fulfilled,
  cancelled;

  static OrderStatus fromString(String s) {
    switch (s) {
      case 'payment_initiated':
        return OrderStatus.paymentInitiated;
      case 'settled':
        return OrderStatus.settled;
      case 'fulfilled':
        return OrderStatus.fulfilled;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Ожидает оплаты';
      case OrderStatus.paymentInitiated:
        return 'Оплата инициирована';
      case OrderStatus.settled:
        return 'Оплачен';
      case OrderStatus.fulfilled:
        return 'Выполнен';
      case OrderStatus.cancelled:
        return 'Отменён';
    }
  }
}

class Order {
  Order({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.subtotalEur,
    required this.discountEur,
    required this.vatEur,
    required this.totalEur,
    required this.currency,
    required this.status,
    required this.buyerCountry,
    required this.createdAt,
    required this.updatedAt,
    this.quoteId,
    this.transferId,
    this.promotionCode,
  });

  final String id;
  final String buyerId;
  final List<OrderItem> items;
  final double subtotalEur;
  final double discountEur;
  final double vatEur;
  final double totalEur;
  final String currency;
  final OrderStatus status;
  final String buyerCountry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? quoteId;
  final String? transferId;
  final String? promotionCode;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        buyerId: json['buyer_id'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotalEur: (json['subtotal_eur'] as num).toDouble(),
        discountEur: (json['discount_eur'] as num).toDouble(),
        vatEur: (json['vat_eur'] as num).toDouble(),
        totalEur: (json['total_eur'] as num).toDouble(),
        currency: json['currency'] as String,
        status: OrderStatus.fromString(json['status'] as String),
        buyerCountry: json['buyer_country'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        quoteId: json['quote_id'] as String?,
        transferId: json['transfer_id'] as String?,
        promotionCode: json['promotion_code'] as String?,
      );
}
