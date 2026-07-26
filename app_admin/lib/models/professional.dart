class Professional {
  const Professional({
    required this.id,
    required this.name,
    required this.isActive,
    this.phone,
  });

  final String id;
  final String name;
  final bool isActive;
  final String? phone;

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
      phone: json['phone'] as String?,
    );
  }
}
