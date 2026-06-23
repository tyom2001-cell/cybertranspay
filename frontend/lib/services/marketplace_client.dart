import 'dart:convert';

import 'package:cybertranspay/config.dart';
import 'package:cybertranspay/models/cart.dart';
import 'package:cybertranspay/models/order.dart';
import 'package:cybertranspay/models/product.dart';
import 'package:cybertranspay/models/promotion.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:http/http.dart' as http;

class MarketplaceClient {
  MarketplaceClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.marketplaceBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ── Catalog ────────────────────────────────────────────────────────────────

  Future<List<Product>> listProducts({
    String? category,
    String? query,
    String? sellerId,
    double? minPriceEur,
    double? maxPriceEur,
    bool? inStock,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (query != null) params['query'] = query;
    if (sellerId != null) params['seller_id'] = sellerId;
    if (minPriceEur != null) params['min_price_eur'] = '$minPriceEur';
    if (maxPriceEur != null) params['max_price_eur'] = '$maxPriceEur';
    if (inStock != null) params['in_stock'] = '$inStock';

    final uri = Uri.parse('$_baseUrl/v1/marketplace/products')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri, headers: _headers);
    _checkStatus(res, 'list products');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['products'] as List<dynamic>)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> getProduct(String id) async {
    final uri = Uri.parse('$_baseUrl/v1/marketplace/products/$id');
    final res = await _client.get(uri, headers: _headers);
    _checkStatus(res, 'get product');
    return Product.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<String>> listCategories() async {
    final uri = Uri.parse('$_baseUrl/v1/marketplace/categories');
    final res = await _client.get(uri, headers: _headers);
    _checkStatus(res, 'list categories');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['categories'] as List<dynamic>).cast<String>();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  Future<Order> createOrder({
    required String buyerId,
    required Cart cart,
    required String buyerCountry,
    String currency = 'EUR',
    String? promotionCode,
  }) async {
    final body = jsonEncode({
      'buyer_id': buyerId,
      'items': cart.items.map((i) => i.toOrderJson()).toList(),
      'buyer_country': buyerCountry,
      'currency': currency,
      if (promotionCode != null) 'promotion_code': promotionCode,
    });
    final uri = Uri.parse('$_baseUrl/v1/marketplace/orders');
    final res = await _client.post(uri, headers: _headers, body: body);
    _checkStatus(res, 'create order');
    return Order.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Order> getOrder(String orderId) async {
    final uri = Uri.parse('$_baseUrl/v1/marketplace/orders/$orderId');
    final res = await _client.get(uri, headers: _headers);
    _checkStatus(res, 'get order');
    return Order.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<Order>> listOrders(String buyerId) async {
    final uri = Uri.parse('$_baseUrl/v1/marketplace/orders')
        .replace(queryParameters: {'buyer_id': buyerId});
    final res = await _client.get(uri, headers: _headers);
    _checkStatus(res, 'list orders');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['orders'] as List<dynamic>)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> initiatePayment(String orderId, String quoteId) async {
    final body = jsonEncode({'quote_id': quoteId});
    final uri = Uri.parse('$_baseUrl/v1/marketplace/orders/$orderId/pay');
    final res = await _client.post(uri, headers: _headers, body: body);
    _checkStatus(res, 'initiate payment');
    return Order.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Order> confirmPayment(String orderId, String transferId) async {
    final body = jsonEncode({'transfer_id': transferId});
    final uri = Uri.parse('$_baseUrl/v1/marketplace/orders/$orderId/confirm');
    final res = await _client.post(uri, headers: _headers, body: body);
    _checkStatus(res, 'confirm payment');
    return Order.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Order> cancelOrder(String orderId) async {
    final uri = Uri.parse('$_baseUrl/v1/marketplace/orders/$orderId/cancel');
    final res = await _client.post(uri, headers: _headers);
    _checkStatus(res, 'cancel order');
    return Order.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Promotions ─────────────────────────────────────────────────────────────

  Future<ValidatePromotionResponse> validatePromotion(String code) async {
    final body = jsonEncode({'code': code});
    final uri = Uri.parse('$_baseUrl/v1/marketplace/promotions/validate');
    final res = await _client.post(uri, headers: _headers, body: body);
    _checkStatus(res, 'validate promotion');
    return ValidatePromotionResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<Product> createProduct({
    required String sellerId,
    required String title,
    required String description,
    required String category,
    required double priceEur,
    required int stock,
    List<String> tags = const [],
    String? imageUrl,
  }) async {
    final body = jsonEncode({
      'seller_id': sellerId,
      'title': title,
      'description': description,
      'category': category,
      'price_eur': priceEur,
      'stock': stock,
      'tags': tags,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    final uri = Uri.parse('$_baseUrl/v1/marketplace/products');
    final res = await _client.post(uri, headers: _headers, body: body);
    _checkStatus(res, 'create product');
    return Product.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── VAT ────────────────────────────────────────────────────────────────────

  Future<double> getVatRate(String countryCode) async {
    final uri =
        Uri.parse('$_baseUrl/v1/marketplace/vat/$countryCode');
    final res = await _client.get(uri, headers: _headers);
    _checkStatus(res, 'get VAT rate');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['rate'] as num).toDouble();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _checkStatus(http.Response res, String operation) {
    if (res.statusCode >= 400) {
      String message = '$operation failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['error'] != null) {
          message = body['error'] as String;
        }
      } catch (_) {}
      throw ApiException(message, statusCode: res.statusCode);
    }
  }
}
