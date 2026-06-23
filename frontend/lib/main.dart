import 'package:cybertranspay/screens/globe_transfer_screen.dart';
import 'package:cybertranspay/screens/account_screen.dart';
import 'package:cybertranspay/screens/marketplace_screen.dart';
import 'package:cybertranspay/screens/orders_screen.dart';
import 'package:cybertranspay/screens/seller_dashboard_screen.dart';
import 'package:cybertranspay/screens/quote_screen.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:cybertranspay/services/auth_client.dart';
import 'package:cybertranspay/services/marketplace_client.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(CyberTransPayApp(
    api: ApiClient(),
    auth: AuthClient(),
    marketplace: MarketplaceClient(),
  ));
}

class CyberTransPayApp extends StatelessWidget {
  CyberTransPayApp({
    super.key,
    required this.api,
    AuthClient? auth,
    MarketplaceClient? marketplace,
  })  : auth = auth ?? AuthClient(),
        marketplace = marketplace ?? MarketplaceClient();

  final ApiClient api;
  final AuthClient auth;
  final MarketplaceClient marketplace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberTransPay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B61FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF060816),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF83F5FF)),
          ),
        ),
      ),
      home: HomeShell(api: api, auth: auth, marketplace: marketplace),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.api,
    required this.auth,
    required this.marketplace,
  });

  final ApiClient api;
  final AuthClient auth;
  final MarketplaceClient marketplace;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Placeholder buyer/seller IDs — in production these come from auth.
  static const String _demoUserId = 'demo-user-001';

  @override
  Widget build(BuildContext context) {
    final pages = [
      GlobeTransferScreen(api: widget.api),
      QuoteScreen(api: widget.api),
      MarketplaceScreen(
        marketplace: widget.marketplace,
        api: widget.api,
        buyerId: _demoUserId,
      ),
      OrdersScreen(
        marketplace: widget.marketplace,
        buyerId: _demoUserId,
      ),
      SellerDashboardScreen(
        marketplace: widget.marketplace,
        sellerId: _demoUserId,
      ),
      AccountScreen(auth: widget.auth),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public), label: 'Глобус'),
          NavigationDestination(icon: Icon(Icons.route), label: 'Маршруты'),
          NavigationDestination(
              icon: Icon(Icons.store), label: 'Магазин'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: 'Заказы'),
          NavigationDestination(
              icon: Icon(Icons.storefront), label: 'Продавец'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Кабинет'),
        ],
      ),
    );
  }
}
