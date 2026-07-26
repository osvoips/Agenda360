class Appointment {
  const Appointment({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.serviceId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String clientId;
  final String professionalId;
  final String serviceId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      professionalId: json['professional_id'] as String,
      serviceId: json['service_id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String,
    );
  }
}

/// Agendamento guardado localmente neste aparelho (shared_preferences).
///
/// O backend não expõe "listar agendamentos por telefone" — não estava nos
/// requisitos do MVP (v1 não tem login). "Meus agendamentos" é, portanto,
/// só o que foi agendado a partir deste aparelho, igual a um número de
/// pedido guardado no navegador.
class SavedAppointment {
  const SavedAppointment({
    required this.id,
    required this.serviceName,
    required this.professionalName,
    required this.clientPhone,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String serviceName;
  final String professionalName;
  final String clientPhone;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  SavedAppointment copyWith({String? status}) {
    return SavedAppointment(
      id: id,
      serviceName: serviceName,
      professionalName: professionalName,
      clientPhone: clientPhone,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_name': serviceName,
      'professional_name': professionalName,
      'client_phone': clientPhone,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'status': status,
    };
  }

  factory SavedAppointment.fromJson(Map<String, dynamic> json) {
    return SavedAppointment(
      id: json['id'] as String,
      serviceName: json['service_name'] as String,
      professionalName: json['professional_name'] as String,
      clientPhone: json['client_phone'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String,
    );
  }
}
