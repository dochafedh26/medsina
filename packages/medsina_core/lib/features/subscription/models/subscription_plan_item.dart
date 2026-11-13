import 'package:equatable/equatable.dart';

class SubscriptionPlanItem extends Equatable {
  final String id;
  final String name;
  final String badge;
  final double priceYearly;
  final double priceMonthly;
  final String currency;
  final int discountPercent;
  final bool isActive;
  final List<String> features;
  final DateTime? updatedAt;

  const SubscriptionPlanItem({
    required this.id,
    required this.name,
    required this.badge,
    required this.priceYearly,
    required this.priceMonthly,
    this.currency = 'DZD',
    this.discountPercent = 0,
    this.isActive = true,
    this.features = const [],
    this.updatedAt,
  });

  factory SubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    List<String> feats = [];
    if (json['features'] != null && json['features'] is List) {
      feats = (json['features'] as List).map((e) => e.toString()).toList();
    }

    return SubscriptionPlanItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      badge: json['badge'] ?? '',
      priceYearly: (json['price_yearly'] as num?)?.toDouble() ?? 0.0,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'DZD',
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] ?? true,
      features: feats,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'badge': badge,
      'price_yearly': priceYearly,
      'price_monthly': priceMonthly,
      'currency': currency,
      'discount_percent': discountPercent,
      'is_active': isActive,
      'features': features,
    };
  }

  SubscriptionPlanItem copyWith({
    String? name,
    String? badge,
    double? priceYearly,
    double? priceMonthly,
    int? discountPercent,
    bool? isActive,
    List<String>? features,
  }) {
    return SubscriptionPlanItem(
      id: id,
      name: name ?? this.name,
      badge: badge ?? this.badge,
      priceYearly: priceYearly ?? this.priceYearly,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      currency: currency,
      discountPercent: discountPercent ?? this.discountPercent,
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        badge,
        priceYearly,
        priceMonthly,
        currency,
        discountPercent,
        isActive,
        features,
        updatedAt,
      ];
}
