import 'dart:math' as math;

import 'package:cybertranspay/models/globe_transfer.dart';
import 'package:cybertranspay/models/route_quote.dart';
import 'package:cybertranspay/services/api_client.dart';
import 'package:flutter/material.dart';

enum _DraftSide { from, to }

class GlobeTransferScreen extends StatefulWidget {
  const GlobeTransferScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<GlobeTransferScreen> createState() => _GlobeTransferScreenState();
}

class _GlobeTransferScreenState extends State<GlobeTransferScreen> {
  TransferDraft _draft = TransferDraft(
    fromCountry: transferCountries.first,
    toCountry: transferCountries[1],
    fromCurrency: transferCountries.first.currency,
    toCurrency: transferCountries[1].currency,
  );
  _DraftSide _activeSide = _DraftSide.from;
  bool _loading = false;
  bool _refreshingTransfer = false;
  String? _executingRouteId;
  String? _error;
  String? _transferError;
  String? _transferStatusMessage;
  bool? _apiHealthy;
  List<RouteQuote> _routes = [];
  QuoteResponse? _lastQuote;
  TransferResponse? _lastTransfer;

  TransferProgress get _progress =>
      TransferProgress.fromStatus(_lastTransfer?.status);

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

  void _selectCountry(TransferCountry country) {
    setState(() {
      _error = null;
      _transferError = null;
      _transferStatusMessage = null;
      _lastTransfer = null;
      if (_activeSide == _DraftSide.from) {
        _draft = _draft.withFromCountry(country);
        _activeSide = _DraftSide.to;
      } else {
        _draft = _draft.withToCountry(country);
        _activeSide = _DraftSide.from;
      }
    });
  }

  Future<void> _openFromDialog() async {
    final result = await showDialog<_FromSelection>(
      context: context,
      builder: (context) => _FromDialog(draft: _draft),
    );
    if (result == null) return;
    setState(() {
      _draft = _draft.copyWith(
        fromCountry: result.country,
        fromCurrency: result.currency,
        amount: result.amount,
      );
      _activeSide = _DraftSide.to;
      _error = null;
      _transferError = null;
      _lastTransfer = null;
    });
  }

  Future<void> _openToDialog() async {
    final result = await showDialog<_ToSelection>(
      context: context,
      builder: (context) => _ToDialog(draft: _draft),
    );
    if (result == null) return;
    setState(() {
      _draft = _draft.copyWith(
        toCountry: result.country,
        toCurrency: result.currency,
      );
      _activeSide = _DraftSide.from;
      _error = null;
      _transferError = null;
      _lastTransfer = null;
    });
  }

  Future<void> _fetchQuote() async {
    if (!_draft.canRequestQuote) {
      setState(() => _error = 'Выберите страны, валюты и корректную сумму');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _transferError = null;
      _transferStatusMessage = null;
      _lastTransfer = null;
    });

    try {
      final response = await widget.api.fetchQuote(
        QuoteRequest(
          fromAsset: _draft.fromCurrency!.toUpperCase(),
          toAsset: _draft.toCurrency!.toUpperCase(),
          amount: _draft.amount,
          preference: _draft.preference,
        ),
      );
      if (!mounted) return;
      setState(() {
        _lastQuote = response;
        _routes = response.routes;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _routes = [];
        _lastQuote = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось связаться с API: $e';
        _routes = [];
        _lastQuote = null;
        _loading = false;
      });
    }
  }

  Future<void> _createTransfer(RouteQuote route) async {
    final quote = _lastQuote;
    if (quote == null) {
      setState(() => _transferError = 'Сначала получите котировку маршрута');
      return;
    }

    setState(() {
      _executingRouteId = route.routeId;
      _transferError = null;
      _transferStatusMessage = null;
      _lastTransfer = null;
    });

    try {
      final transfer = await widget.api.createTransfer(
        CreateTransferRequest(quoteId: quote.quoteId, routeId: route.routeId),
      );
      if (!mounted) return;
      setState(() {
        _lastTransfer = transfer;
        _executingRouteId = null;
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
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Глобус переводов',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Icon(
                _apiHealthy == true
                    ? Icons.cloud_done
                    : _apiHealthy == false
                        ? Icons.cloud_off
                        : Icons.cloud_queue,
                color: _apiHealthy == true ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите направление на карте, затем запустите текущий поток котировок.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _DraftSummary(
            draft: _draft,
            activeSide: _activeSide,
            onSelectSide: (side) => setState(() => _activeSide = side),
            onEditFrom: _openFromDialog,
            onEditTo: _openToDialog,
          ),
          const SizedBox(height: 16),
          _GlobeCard(
            draft: _draft,
            activeSide: _activeSide,
            progress: _progress,
            onCountryTap: _selectCountry,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _fetchQuote,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.travel_explore),
                const SizedBox(width: 8),
                Text(_loading ? 'Загружаем...' : 'Получить котировку'),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          _ProgressCard(
            draft: _draft,
            progress: _progress,
            transfer: _lastTransfer,
            refreshing: _refreshingTransfer,
            statusMessage: _transferStatusMessage,
            onRefresh: _lastTransfer == null || _refreshingTransfer
                ? null
                : _refreshTransferStatus,
          ),
          const SizedBox(height: 16),
          if (_lastQuote != null) ...[
            Text(
              'Quote: ${_lastQuote!.quoteId} · курс '
              '${_lastQuote!.spotRate.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
          ],
          if (_transferError != null) ...[
            Text(
              _transferError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          if (_routes.isEmpty && !_loading && _error == null)
            const Text('Котировки маршрутов появятся здесь.'),
          ..._routes.map(
            (route) => _GlobeRouteCard(
              route: route,
              executing: _executingRouteId == route.routeId,
              onCreateTransfer: _executingRouteId == null
                  ? () => _createTransfer(route)
                  : null,
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        content,
        if (_progress.completed) const SuccessAuroraOverlay(),
      ],
    );
  }
}

class _DraftSummary extends StatelessWidget {
  const _DraftSummary({
    required this.draft,
    required this.activeSide,
    required this.onSelectSide,
    required this.onEditFrom,
    required this.onEditTo,
  });

  final TransferDraft draft;
  final _DraftSide activeSide;
  final ValueChanged<_DraftSide> onSelectSide;
  final VoidCallback onEditFrom;
  final VoidCallback onEditTo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<_DraftSide>(
              segments: const [
                ButtonSegment(
                  value: _DraftSide.from,
                  label: Text('Откуда'),
                  icon: Icon(Icons.upload),
                ),
                ButtonSegment(
                  value: _DraftSide.to,
                  label: Text('Куда'),
                  icon: Icon(Icons.download),
                ),
              ],
              selected: {activeSide},
              onSelectionChanged: (value) => onSelectSide(value.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CountryTile(
                    title: 'FromDialog',
                    country: draft.fromCountry,
                    currency: draft.fromCurrency,
                    amount: draft.amount,
                    selected: activeSide == _DraftSide.from,
                    onTap: onEditFrom,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CountryTile(
                    title: 'ToDialog',
                    country: draft.toCountry,
                    currency: draft.toCurrency,
                    amount: draft.amount,
                    selected: activeSide == _DraftSide.to,
                    onTap: onEditTo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.title,
    required this.country,
    required this.currency,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final TransferCountry? country;
  final String? currency;
  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.amber : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(country?.name ?? 'Выберите страну'),
            Text('${country?.iso2 ?? '--'} · ${currency ?? '--'}'),
            if (title == 'FromDialog')
              Text('Сумма: ${amount.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class _GlobeCard extends StatelessWidget {
  const _GlobeCard({
    required this.draft,
    required this.activeSide,
    required this.progress,
    required this.onCountryTap,
  });

  final TransferDraft draft;
  final _DraftSide activeSide;
  final TransferProgress progress;
  final ValueChanged<TransferCountry> onCountryTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeSide == _DraftSide.from
                  ? 'Клик по стране задаёт From'
                  : 'Клик по стране задаёт To',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1.35,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GlobePainter(
                            draft: draft,
                            progress: progress,
                          ),
                        ),
                      ),
                      for (final country in transferCountries)
                        _CountryMarker(
                          country: country,
                          position: _projectCountry(country, size),
                          selected: draft.fromCountry?.iso2 == country.iso2 ||
                              draft.toCountry?.iso2 == country.iso2,
                          isFrom: draft.fromCountry?.iso2 == country.iso2,
                          isTo: draft.toCountry?.iso2 == country.iso2,
                          onTap: () => onCountryTap(country),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryMarker extends StatelessWidget {
  const _CountryMarker({
    required this.country,
    required this.position,
    required this.selected,
    required this.isFrom,
    required this.isTo,
    required this.onTap,
  });

  final TransferCountry country;
  final Offset position;
  final bool selected;
  final bool isFrom;
  final bool isTo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isFrom
        ? 'F'
        : isTo
            ? 'T'
            : country.iso2;
    return Positioned(
      left: position.dx - 16,
      top: position.dy - 16,
      child: Tooltip(
        message: country.label,
        child: Semantics(
          button: true,
          label: 'Страна ${country.name}',
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.amber : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.indigo.shade900, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter({required this.draft, required this.progress});

  final TransferDraft draft;
  final TransferProgress progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.44;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final globePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.45),
        colors: [Color(0xFF3C6DF0), Color(0xFF10245C)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, globePaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [0.35, 0.65, 0.9]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * scale,
          height: radius * 2,
        ),
        gridPaint,
      );
    }
    for (final y in [-0.55, -0.25, 0.25, 0.55]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + radius * y),
          width: radius * 1.8,
          height: radius * 0.18,
        ),
        gridPaint,
      );
    }

    final from = draft.fromCountry;
    final to = draft.toCountry;
    if (from == null || to == null) return;

    final start = _projectCountry(from, size);
    final end = _projectCountry(to, size);
    final lift = math.max(42, (start - end).distance * 0.25);
    final control = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - lift,
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    final metric = path.computeMetrics().first;
    final progressPath =
        metric.extractPath(0, metric.length * progress.percent);
    canvas.drawPath(
      progressPath,
      Paint()
        ..color = progress.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    if (progress.failed) {
      final stop = metric.getTangentForOffset(metric.length * progress.percent);
      if (stop != null) {
        canvas.drawCircle(stop.position, 10, Paint()..color = Colors.redAccent);
        canvas.drawLine(
          stop.position + const Offset(-5, -5),
          stop.position + const Offset(5, 5),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
    return oldDelegate.draft != draft || oldDelegate.progress != progress;
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.draft,
    required this.progress,
    required this.transfer,
    required this.refreshing,
    required this.statusMessage,
    required this.onRefresh,
  });

  final TransferDraft draft;
  final TransferProgress progress;
  final TransferResponse? transfer;
  final bool refreshing;
  final String? statusMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Линия перевода',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              '${draft.fromCountry?.iso2 ?? '--'} ${draft.fromCurrency ?? '--'}'
              ' → ${draft.toCountry?.iso2 ?? '--'} ${draft.toCurrency ?? '--'}',
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.percent,
              color: progress.color,
              backgroundColor: Colors.white.withValues(alpha: 0.45),
              minHeight: 8,
            ),
            const SizedBox(height: 10),
            Text('${progress.label} · ${(progress.percent * 100).round()}%'),
            if (transfer != null) ...[
              const SizedBox(height: 10),
              Text('ID: ${transfer!.transferId}'),
              Text('Статус: ${transfer!.status}'),
              Text(
                'Сумма: ${transfer!.amount.toStringAsFixed(2)} '
                '${transfer!.fromAsset} → '
                '${transfer!.estimatedReceive.toStringAsFixed(2)} '
                '${transfer!.toAsset}',
              ),
              const SizedBox(height: 14),
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
            ],
            if (statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(statusMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobeRouteCard extends StatelessWidget {
  const _GlobeRouteCard({
    required this.route,
    required this.executing,
    required this.onCreateTransfer,
  });

  final RouteQuote route;
  final bool executing;
  final VoidCallback? onCreateTransfer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(route.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Rails: ${route.rails.join(' → ')}'),
            Text(
                'Комиссия: ${route.feePercent}% · ETA: ${route.etaMinutes} мин'),
            Text('Compliance: ${route.complianceScore}/100'),
            Text(
              'К получению: ${route.estimatedReceive.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onCreateTransfer,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (executing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.send),
                  const SizedBox(width: 8),
                  Text(executing ? 'Выполняем...' : 'Выполнить перевод'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FromSelection {
  const _FromSelection({
    required this.country,
    required this.currency,
    required this.amount,
  });

  final TransferCountry country;
  final String currency;
  final double amount;
}

class _ToSelection {
  const _ToSelection({required this.country, required this.currency});

  final TransferCountry country;
  final String currency;
}

class _FromDialog extends StatefulWidget {
  const _FromDialog({required this.draft});

  final TransferDraft draft;

  @override
  State<_FromDialog> createState() => _FromDialogState();
}

class _FromDialogState extends State<_FromDialog> {
  late TransferCountry _country;
  late String _currency;
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _country = widget.draft.fromCountry ?? transferCountries.first;
    _currency = widget.draft.fromCurrency ?? _country.currency;
    _amountController =
        TextEditingController(text: widget.draft.amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('FromDialog'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<TransferCountry>(
            initialValue: _country,
            decoration: const InputDecoration(labelText: 'Страна'),
            items: transferCountries
                .map((country) => DropdownMenuItem(
                      value: country,
                      child: Text(country.name),
                    ))
                .toList(),
            onChanged: (country) {
              if (country == null) return;
              setState(() {
                _country = country;
                _currency = country.currency;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Валюта'),
            items: supportedTransferCurrencies
                .map((currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ))
                .toList(),
            onChanged: (currency) => setState(() {
              _currency = currency ?? _country.currency;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Сумма'),
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text.trim());
            if (amount == null || amount <= 0) {
              setState(() => _error = 'Введите корректную сумму');
              return;
            }
            Navigator.of(context).pop(
              _FromSelection(
                country: _country,
                currency: _currency,
                amount: amount,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _ToDialog extends StatefulWidget {
  const _ToDialog({required this.draft});

  final TransferDraft draft;

  @override
  State<_ToDialog> createState() => _ToDialogState();
}

class _ToDialogState extends State<_ToDialog> {
  late TransferCountry _country;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _country = widget.draft.toCountry ?? transferCountries[1];
    _currency = widget.draft.toCurrency ?? _country.currency;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ToDialog'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<TransferCountry>(
            initialValue: _country,
            decoration: const InputDecoration(labelText: 'Страна'),
            items: transferCountries
                .map((country) => DropdownMenuItem(
                      value: country,
                      child: Text(country.name),
                    ))
                .toList(),
            onChanged: (country) {
              if (country == null) return;
              setState(() {
                _country = country;
                _currency = country.currency;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Валюта'),
            items: supportedTransferCurrencies
                .map((currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ))
                .toList(),
            onChanged: (currency) => setState(() {
              _currency = currency ?? _country.currency;
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ToSelection(country: _country, currency: _currency),
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class SuccessAuroraOverlay extends StatelessWidget {
  const SuccessAuroraOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.greenAccent.withValues(alpha: 0.26),
                Colors.lightBlueAccent.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Перевод завершён',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Offset _projectCountry(TransferCountry country, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = math.min(size.width, size.height) * 0.44;
  final x = center.dx + (country.longitude / 180) * radius * 0.92;
  final y = center.dy - (country.latitude / 90) * radius * 0.86;
  return Offset(x, y);
}
