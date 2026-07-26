class TenantBranding {
  const TenantBranding({
    required this.slug,
    required this.displayName,
    required this.minCancelNoticeMinutes,
    this.logoUrl,
    this.iconUrl,
    this.primaryColor,
    this.secondaryColor,
  });

  final String slug;
  final String displayName;
  final int minCancelNoticeMinutes;
  final String? logoUrl;
  final String? iconUrl;
  final String? primaryColor;
  final String? secondaryColor;

  factory TenantBranding.fromJson(Map<String, dynamic> json) {
    return TenantBranding(
      slug: json['slug'] as String,
      displayName: json['display_name'] as String,
      minCancelNoticeMinutes: json['min_cancel_notice_minutes'] as int,
      logoUrl: json['logo_url'] as String?,
      iconUrl: json['icon_url'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
    );
  }
}
