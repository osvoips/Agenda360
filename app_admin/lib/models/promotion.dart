class Promotion {
  const Promotion({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  final String id;
  final String serviceId;
  final String name;

  /// 'percentage' ou 'fixed' — ver backend/app/schemas/promotion.py.
  final String discountType;
  final int discountValue;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      serviceId: json['service_id'] as String,
      name: json['name'] as String,
      discountType: json['discount_type'] as String,
      discountValue: json['discount_value'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      isActive: json['is_active'] as bool,
    );
  }
}
