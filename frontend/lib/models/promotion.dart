enum PromotionKind { percentOff, fixedEur }

class Promotion {
  Promotion({
    required this.code,
    required this.kind,
    required this.value,
    required this.active,
    required this.uses,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
  });

  final String code;
  final PromotionKind kind;
  final double value;
  final bool active;
  final int uses;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxUses;

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        code: json['code'] as String,
        kind: json['kind'] == 'percent_off'
            ? PromotionKind.percentOff
            : PromotionKind.fixedEur,
        value: (json['value'] as num).toDouble(),
        active: json['active'] as bool,
        uses: (json['uses'] as num).toInt(),
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        maxUses: json['max_uses'] != null
            ? (json['max_uses'] as num).toInt()
            : null,
      );

  String get description {
    return kind == PromotionKind.percentOff
        ? '${value.toStringAsFixed(0)}% скидка'
        : '−${value.toStringAsFixed(2)} EUR';
  }
}

class ValidatePromotionResponse {
  ValidatePromotionResponse({
    required this.code,
    required this.valid,
    this.kind,
    this.value,
    this.reason,
  });

  final String code;
  final bool valid;
  final PromotionKind? kind;
  final double? value;
  final String? reason;

  factory ValidatePromotionResponse.fromJson(Map<String, dynamic> json) =>
      ValidatePromotionResponse(
        code: json['code'] as String,
        valid: json['valid'] as bool,
        kind: json['kind'] == null
            ? null
            : json['kind'] == 'percent_off'
                ? PromotionKind.percentOff
                : PromotionKind.fixedEur,
        value:
            json['value'] != null ? (json['value'] as num).toDouble() : null,
        reason: json['reason'] as String?,
      );
}
