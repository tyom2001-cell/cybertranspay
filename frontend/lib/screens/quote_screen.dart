import 'package:cybertranspay/models/route_quote.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:flutter/material.dart';

const _countries = <_CorridorCountry>[
  _CorridorCountry(
    code: 'US',
    name: 'США',
    flag: '🇺🇸',
    currency: 'USD',
    position: Offset(0.21, 0.44),
  ),
  _CorridorCountry(
    code: 'EU',
    name: 'Еврозона',
    flag: '🇪🇺',
    currency: 'EUR',
    position: Offset(0.49, 0.39),
  ),
  _CorridorCountry(
    code: 'GB',
    name: 'Великобритания',
    flag: '🇬🇧',
    currency: 'GBP',
    position: Offset(0.46, 0.34),
  ),
  _CorridorCountry(
    code: 'PL',
    name: 'Польша',
    flag: '🇵🇱',
    currency: 'PLN',
    position: Offset(0.53, 0.36),
  ),
  _CorridorCountry(
    code: 'TR',
    name: 'Турция',
    flag: '🇹🇷',
    currency: 'TRY',
    position: Offset(0.57, 0.47),
  ),
  _CorridorCountry(
    code: 'AE',
    name: 'ОАЭ',
    flag: '🇦🇪',
    currency: 'AED',
    position: Offset(0.64, 0.55),
  ),
  _CorridorCountry(
    code: 'CN',
    name: 'Китай',
    flag: '🇨🇳',
    currency: 'CNY',
    position: Offset(0.74, 0.47),
  ),
  _CorridorCountry(
    code: 'JP',
    name: 'Япония',
    flag: '🇯🇵',
    currency: 'JPY',
    position: Offset(0.86, 0.45),
  ),
];

class _CorridorCountry {
  const _CorridorCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.position,
  });

  final String code;
  final String name;
  final String flag;
  final String currency;
  final Offset position;

  String get label => '$flag $name · $currency';
}

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final _amountController = TextEditingController(text: '1000');
  final _recipientController = TextEditingController();
  String? _fromCountryCode;
  String? _toCountryCode;
  String _preference = 'cheapest';
  bool _loading = false;
  String? _executingRouteId;
  bool _refreshingTransfer = false;
  String? _error;
  String? _transferError;
  String? _transferStatusMessage;
  List<RouteQuote> _routes = [];
  QuoteResponse? _lastQuote;
  TransferResponse? _lastTransfer;
  RouteQuote? _selectedRoute;
  String? _confirmedRecipient;
  bool? _apiHealthy;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    try {
      final ok = await widget.api.checkHealth();
      if (mounted) setState(() => _apiHealthy = ok);
    } catch (_) {
      if (mounted) setState(() => _apiHealthy = false);
    }
  }

  _CorridorCountry? get _fromCountry => _countryByCode(_fromCountryCode);
  _CorridorCountry? get _toCountry => _countryByCode(_toCountryCode);

  _CorridorCountry? _countryByCode(String? code) {
    if (code == null) return null;
    for (final country in _countries) {
      if (country.code == code) return country;
    }
    return null;
  }

  void _clearQuoteState() {
    _error = null;
    _transferError = null;
    _transferStatusMessage = null;
    _routes = [];
    _lastQuote = null;
    _lastTransfer = null;
    _selectedRoute = null;
    _confirmedRecipient = null;
  }

  void _setFromCountry(String? code) {
    setState(() {
      _fromCountryCode = code;
      _clearQuoteState();
    });
  }

  void _setToCountry(String? code) {
    setState(() {
      _toCountryCode = code;
      _clearQuoteState();
    });
  }

  void _selectCountryFromMap(_CorridorCountry country) {
    if (_fromCountryCode == country.code) return;
    if (_toCountryCode == country.code) return;

    setState(() {
      if (_fromCountryCode == null) {
        _fromCountryCode = country.code;
      } else {
        _toCountryCode = country.code;
      }
      _clearQuoteState();
    });
  }

  Future<void> _fetchQuote() async {
    final fromCountry = _fromCountry;
    final toCountry = _toCountry;
    if (fromCountry == null || toCountry == null) {
      setState(() => _error = 'Выберите, откуда и куда отправляются деньги');
      return;
    }
    if (fromCountry.code == toCountry.code) {
      setState(() => _error = 'Выберите две разные страны');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Введите корректную сумму');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _transferError = null;
      _transferStatusMessage = null;
      _lastTransfer = null;
      _selectedRoute = null;
      _confirmedRecipient = null;
    });

    try {
      final response = await widget.api.fetchQuote(
        QuoteRequest(
          fromAsset: fromCountry.currency,
          toAsset: toCountry.currency,
          amount: amount,
          preference: _preference,
        ),
      );
      if (!mounted) return;
      setState(() {
        _routes = response.routes;
        _lastQuote = response;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _routes = [];
        _lastQuote = null;
        _lastTransfer = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось связаться с API: $e';
        _loading = false;
        _routes = [];
        _lastQuote = null;
        _lastTransfer = null;
      });
    }
  }

  void _selectRoute(RouteQuote route) {
    setState(() {
      _selectedRoute = route;
      _transferError = null;
      _transferStatusMessage = null;
      _lastTransfer = null;
      _confirmedRecipient = null;
    });
  }

  Future<void> _createTransfer() async {
    final quote = _lastQuote;
    final route = _selectedRoute;
    if (quote == null) {
      setState(() => _transferError = 'Сначала получите котировку маршрута');
      return;
    }
    if (route == null) {
      setState(() => _transferError = 'Выберите маршрут для перевода');
      return;
    }

    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() => _transferError = 'Укажите получателя');
      return;
    }

    setState(() {
      _executingRouteId = route.routeId;
      _transferError = null;
      _transferStatusMessage = null;
      _lastTransfer = null;
      _confirmedRecipient = recipient;
    });

    try {
      final transfer = await widget.api.createTransfer(
        CreateTransferRequest(
          quoteId: quote.quoteId,
          routeId: route.routeId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _lastTransfer = transfer;
        _executingRouteId = null;
        _selectedRoute = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _transferError = e.message;
        _executingRouteId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transferError = 'Не удалось выполнить перевод: $e';
        _executingRouteId = null;
      });
    }
  }

  Future<void> _refreshTransferStatus() async {
    final transfer = _lastTransfer;
    if (transfer == null) return;

    setState(() {
      _refreshingTransfer = true;
      _transferError = null;
      _transferStatusMessage = null;
    });

    try {
      final refreshed = await widget.api.getTransfer(transfer.transferId);
      if (!mounted) return;
      setState(() {
        _lastTransfer = refreshed;
        _refreshingTransfer = false;
        _transferStatusMessage = 'Статус обновлён';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _transferError = e.message;
        _refreshingTransfer = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transferError = 'Не удалось обновить статус: $e';
        _refreshingTransfer = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromCountry = _fromCountry;
    final toCountry = _toCountry;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF060816),
            Color(0xFF0C1230),
            Color(0xFF11163B),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            _HeroHeader(apiHealthy: _apiHealthy),
            const SizedBox(height: 16),
            _FlatEarthSelector(
              fromCountry: fromCountry,
              toCountry: toCountry,
              onCountryTap: _selectCountryFromMap,
            ),
            const SizedBox(height: 16),
            _GlassPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CountryDropdown(
                          key: const ValueKey('from-country-field'),
                          value: _fromCountryCode,
                          label: 'Откуда',
                          hint: 'Выберите страну',
                          onChanged: _setFromCountry,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CountryDropdown(
                          key: const ValueKey('to-country-field'),
                          value: _toCountryCode,
                          label: 'Куда',
                          hint: 'Выберите страну',
                          onChanged: _setToCountry,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _preference,
                    decoration: const InputDecoration(
                      labelText: 'Приоритет',
                      prefixIcon: Icon(Icons.tune),
                    ),
                    dropdownColor: const Color(0xFF101735),
                    items: const [
                      DropdownMenuItem(
                          value: 'cheapest', child: Text('Дешевле')),
                      DropdownMenuItem(
                          value: 'fastest', child: Text('Быстрее')),
                      DropdownMenuItem(
                        value: 'compliant',
                        child: Text('Compliance'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _preference = v ?? 'cheapest'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _fetchQuote,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Подобрать маршрут'),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(message: _error!, isError: true),
            ],
            const SizedBox(height: 20),
            if (_routes.isEmpty && !_loading && _error == null)
              const _StatusBanner(
                message: 'Выберите страны на карте или в полях маршрута.',
              ),
            if (_lastQuote != null) ...[
              _QuoteSummary(_lastQuote!, fromCountry!, toCountry!),
              const SizedBox(height: 12),
            ],
            if (_transferError != null) ...[
              _StatusBanner(message: _transferError!, isError: true),
              const SizedBox(height: 8),
            ],
            if (_selectedRoute != null && _lastTransfer == null) ...[
              _TransferConfirmation(
                route: _selectedRoute!,
                amount: double.tryParse(_amountController.text.trim()) ?? 0,
                fromCountry: fromCountry!,
                toCountry: toCountry!,
                recipientController: _recipientController,
                confirming: _executingRouteId == _selectedRoute!.routeId,
                onConfirm: _executingRouteId == null ? _createTransfer : null,
                onCancel: _executingRouteId == null
                    ? () => setState(() => _selectedRoute = null)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            if (_lastTransfer != null) ...[
              _TransferReceipt(
                _lastTransfer!,
                recipient: _confirmedRecipient,
                refreshing: _refreshingTransfer,
                statusMessage: _transferStatusMessage,
                onRefresh: _refreshingTransfer ? null : _refreshTransferStatus,
              ),
              const SizedBox(height: 12),
            ],
            ..._routes.map(
              (route) => _RouteCard(
                route,
                selected: _selectedRoute?.routeId == route.routeId,
                executing: _executingRouteId == route.routeId,
                onSelect: _executingRouteId == null
                    ? () => _selectRoute(route)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.apiHealthy});

  final bool? apiHealthy;

  @override
  Widget build(BuildContext context) {
    final statusColor = apiHealthy == true
        ? const Color(0xFF5EF7C8)
        : apiHealthy == false
            ? const Color(0xFFFF8E8E)
            : const Color(0xFFFFD36E);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Маршрут платежа',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Плоская карта, быстрый выбор страны и валюты.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.3),
                blurRadius: 18,
              ),
            ],
          ),
          child: Icon(
            apiHealthy == true
                ? Icons.cloud_done
                : apiHealthy == false
                    ? Icons.cloud_off
                    : Icons.cloud_queue,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64D8FF).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FlatEarthSelector extends StatelessWidget {
  const _FlatEarthSelector({
    required this.fromCountry,
    required this.toCountry,
    required this.onCountryTap,
  });

  final _CorridorCountry? fromCountry;
  final _CorridorCountry? toCountry;
  final ValueChanged<_CorridorCountry> onCountryTap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: SizedBox(
        height: 230,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FlatEarthPainter(
                      fromCountry: fromCountry,
                      toCountry: toCountry,
                    ),
                  ),
                ),
                for (final country in _countries)
                  Positioned(
                    left: country.position.dx * constraints.maxWidth - 25,
                    top: country.position.dy * constraints.maxHeight - 25,
                    child: _CountryMarker(
                      country: country,
                      selectedAsFrom: country.code == fromCountry?.code,
                      selectedAsTo: country.code == toCountry?.code,
                      onTap: () => onCountryTap(country),
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 10,
                  child: Text(
                    'Развертка Земли',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FlatEarthPainter extends CustomPainter {
  _FlatEarthPainter({required this.fromCountry, required this.toCountry});

  final _CorridorCountry? fromCountry;
  final _CorridorCountry? toCountry;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final spacePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B1028), Color(0xFF101C44)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      spacePaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var x = 0.12; x < 1; x += 0.18) {
      canvas.drawLine(
        Offset(size.width * x, 18),
        Offset(size.width * x, size.height - 18),
        gridPaint,
      );
    }
    for (var y = 0.2; y < 1; y += 0.2) {
      canvas.drawLine(
        Offset(14, size.height * y),
        Offset(size.width - 14, size.height * y),
        gridPaint,
      );
    }

    final landPaint = Paint()
      ..color = const Color(0xFF263A5D).withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = const Color(0xFF58D7FF).withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    for (final path in _landPaths(size)) {
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, landPaint);
    }

    if (fromCountry != null && toCountry != null) {
      final start = _point(size, fromCountry!.position);
      final end = _point(size, toCountry!.position);
      final control = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2 - 52,
      );
      final route = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      final routeGlow = Paint()
        ..color = const Color(0xFF71F6FF).withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final routePaint = Paint()
        ..color = const Color(0xFF85F4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(route, routeGlow);
      canvas.drawPath(route, routePaint);
    }
  }

  List<Path> _landPaths(Size size) {
    Path path(List<Offset> points) {
      final out = Path()
        ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final point in points.skip(1)) {
        out.lineTo(point.dx * size.width, point.dy * size.height);
      }
      return out..close();
    }

    return [
      path(const [
        Offset(0.10, 0.32),
        Offset(0.24, 0.24),
        Offset(0.33, 0.36),
        Offset(0.28, 0.52),
        Offset(0.18, 0.60),
        Offset(0.09, 0.49),
      ]),
      path(const [
        Offset(0.30, 0.58),
        Offset(0.38, 0.63),
        Offset(0.34, 0.82),
        Offset(0.27, 0.75),
      ]),
      path(const [
        Offset(0.42, 0.29),
        Offset(0.58, 0.27),
        Offset(0.67, 0.42),
        Offset(0.61, 0.59),
        Offset(0.48, 0.54),
        Offset(0.40, 0.42),
      ]),
      path(const [
        Offset(0.60, 0.34),
        Offset(0.82, 0.28),
        Offset(0.92, 0.45),
        Offset(0.80, 0.64),
        Offset(0.63, 0.55),
      ]),
      path(const [
        Offset(0.72, 0.72),
        Offset(0.85, 0.70),
        Offset(0.90, 0.82),
        Offset(0.78, 0.88),
      ]),
    ];
  }

  Offset _point(Size size, Offset normalized) =>
      Offset(size.width * normalized.dx, size.height * normalized.dy);

  @override
  bool shouldRepaint(covariant _FlatEarthPainter oldDelegate) {
    return oldDelegate.fromCountry != fromCountry ||
        oldDelegate.toCountry != toCountry;
  }
}

class _CountryMarker extends StatelessWidget {
  const _CountryMarker({
    required this.country,
    required this.selectedAsFrom,
    required this.selectedAsTo,
    required this.onTap,
  });

  final _CorridorCountry country;
  final bool selectedAsFrom;
  final bool selectedAsTo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedAsFrom || selectedAsTo;
    final color = selectedAsFrom
        ? const Color(0xFF68F8FF)
        : selectedAsTo
            ? const Color(0xFFA985FF)
            : Colors.white.withValues(alpha: 0.76);

    return Tooltip(
      message: country.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 54 : 48,
          height: selected ? 54 : 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF111936).withValues(alpha: selected ? 0.94 : 0.76),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: selected ? 1.7 : 1),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 17)),
              Text(
                country.currency,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final String? value;
  final String label;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.public),
      ),
      dropdownColor: const Color(0xFF101735),
      items: _countries
          .map(
            (country) => DropdownMenuItem(
              value: country.code,
              child: Text(country.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? Theme.of(context).colorScheme.error : const Color(0xFF7DEAFF);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: TextStyle(color: isError ? color : Colors.white70),
      ),
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary(this.quote, this.fromCountry, this.toCountry);

  final QuoteResponse quote;
  final _CorridorCountry fromCountry;
  final _CorridorCountry toCountry;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${fromCountry.flag} ${fromCountry.currency} → '
            '${toCountry.flag} ${toCountry.currency}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quote: ${quote.quoteId} · expires: '
            '${quote.expiresAt.toLocal().toIso8601String().substring(0, 16)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Курс: ${quote.spotRate.toStringAsFixed(4)} (${quote.rateSource})'
            '${quote.livePricing ? ' · live' : ''}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF83F5FF),
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard(
    this.route, {
    required this.selected,
    required this.executing,
    required this.onSelect,
  });
  final RouteQuote route;
  final bool selected;
  final bool executing;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? const Color(0xFF83F5FF)
              : Colors.white.withValues(alpha: 0.12),
          width: selected ? 1.6 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: const Color(0xFF83F5FF).withValues(alpha: 0.18),
              blurRadius: 22,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text('ID: ${route.routeId}', style: _mutedText),
            Text('Rails: ${route.rails.join(' → ')}', style: _mutedText),
            const SizedBox(height: 8),
            Text('Комиссия: ${route.feePercent}%', style: _mutedText),
            Text('ETA: ${route.etaMinutes} мин', style: _mutedText),
            Text('Compliance: ${route.complianceScore}/100', style: _mutedText),
            Text(
              'К получению: ${route.estimatedReceive.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF83F5FF),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSelect,
              icon: executing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(selected ? Icons.check_circle : Icons.touch_app),
              label: Text(
                executing
                    ? 'Выполняем...'
                    : selected
                        ? 'Маршрут выбран'
                        : 'Выбрать маршрут',
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _mutedText => const TextStyle(color: Colors.white70);
}

class _TransferConfirmation extends StatelessWidget {
  const _TransferConfirmation({
    required this.route,
    required this.amount,
    required this.fromCountry,
    required this.toCountry,
    required this.recipientController,
    required this.confirming,
    required this.onConfirm,
    required this.onCancel,
  });

  final RouteQuote route;
  final double amount;
  final _CorridorCountry fromCountry;
  final _CorridorCountry toCountry;
  final TextEditingController recipientController;
  final bool confirming;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final fee = amount * route.feePercent / 100;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Подтверждение перевода',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('recipient-field'),
            controller: recipientController,
            decoration: const InputDecoration(
              labelText: 'Получатель',
              hintText: 'Имя, IBAN или wallet',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          _ConfirmRow('Направление',
              '${fromCountry.flag} ${fromCountry.currency} → ${toCountry.flag} ${toCountry.currency}'),
          _ConfirmRow('Маршрут', route.label),
          _ConfirmRow(
              'Сумма', '${amount.toStringAsFixed(2)} ${fromCountry.currency}'),
          _ConfirmRow('Комиссия',
              '${fee.toStringAsFixed(2)} ${fromCountry.currency} (${route.feePercent}%)'),
          _ConfirmRow('К получению',
              '${route.estimatedReceive.toStringAsFixed(2)} ${toCountry.currency}',
              accent: true),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Отменить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(confirming ? 'Подтверждаем...' : 'Подтвердить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow(this.label, this.value, {this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: accent ? const Color(0xFF83F5FF) : Colors.white,
                fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferReceipt extends StatelessWidget {
  const _TransferReceipt(
    this.transfer, {
    required this.recipient,
    required this.refreshing,
    required this.statusMessage,
    required this.onRefresh,
  });

  final TransferResponse transfer;
  final String? recipient;
  final bool refreshing;
  final String? statusMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17342F).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF5EF7C8).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5EF7C8).withValues(alpha: 0.12),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Перевод создан',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text('ID: ${transfer.transferId}', style: _mutedText),
            Text('Статус: ${transfer.status}', style: _mutedText),
            Text('Маршрут: ${transfer.routeId}', style: _mutedText),
            if (recipient != null)
              Text('Получатель: $recipient', style: _mutedText),
            Text(
              'Сумма: ${transfer.amount.toStringAsFixed(2)} '
              '${transfer.fromAsset} → ${transfer.estimatedReceive.toStringAsFixed(2)} '
              '${transfer.toAsset}',
              style: _mutedText,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(refreshing ? 'Обновляем...' : 'Обновить статус'),
            ),
            if (statusMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                statusMessage!,
                style: const TextStyle(color: Color(0xFF5EF7C8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle get _mutedText => const TextStyle(color: Colors.white70);
}
