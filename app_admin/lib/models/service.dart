class Service {
  const Service({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.isActive,
    this.priceCents,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final bool isActive;
  final int? priceCents;

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: json['duration_minutes'] as int,
      isActive: json['is_active'] as bool,
      priceCents: json['price_cents'] as int?,
    );
  }
}
