class AgendaAppointment {
  const AgendaAppointment({
    required this.id,
    required this.professionalId,
    required this.serviceId,
    required this.clientName,
    required this.clientPhone,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String professionalId;
  final String serviceId;
  final String clientName;
  final String clientPhone;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  factory AgendaAppointment.fromJson(Map<String, dynamic> json) {
    return AgendaAppointment(
      id: json['id'] as String,
      professionalId: json['professional_id'] as String,
      serviceId: json['service_id'] as String,
      clientName: json['client_name'] as String,
      clientPhone: json['client_phone'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String,
    );
  }
}
