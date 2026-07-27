import '../models/appointment.dart';
import '../models/professional.dart';
import '../models/service.dart';
import '../models/tenant_branding.dart';
import 'api_client.dart';

/// Métodos tipados sobre os endpoints públicos do backend — ver
/// backend/app/api/client_routes.py para o contrato exato.
class AgendaApi {
  AgendaApi(this._client);

  final ApiClient _client;

  Future<TenantBranding> getTenant() async {
    final json = await _client.get('/v1/tenant') as Map<String, dynamic>;
    return TenantBranding.fromJson(json);
  }

  Future<List<Service>> getServices() async {
    final json = await _client.get('/v1/services') as List<dynamic>;
    return json.map((item) => Service.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Professional>> getProfessionals(String serviceId) async {
    final json = await _client.get('/v1/professionals', query: {'service_id': serviceId}) as List<dynamic>;
    return json.map((item) => Professional.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<DateTime>> getAvailability({
    required String professionalId,
    required String serviceId,
    required DateTime date,
  }) async {
    final json = await _client.get('/v1/availability', query: {
      'professional_id': professionalId,
      'service_id': serviceId,
      'date': _formatDate(date),
    }) as Map<String, dynamic>;
    final slots = json['slots'] as List<dynamic>;
    return slots.map((slot) => DateTime.parse(slot as String)).toList();
  }

  Future<Appointment> createAppointment({
    required String clientName,
    required String clientPhone,
    required String serviceId,
    required String professionalId,
    required DateTime startsAt,
  }) async {
    final json = await _client.post('/v1/appointments', {
      'client_name': clientName,
      'client_phone': clientPhone,
      'service_id': serviceId,
      'professional_id': professionalId,
      // toUtc() garante um offset explícito ('Z') na string enviada,
      // não importa se startsAt já veio em UTC (normal, vindo da
      // disponibilidade) ou foi convertido pra local em algum ponto —
      // sem isso o backend pode interpretar a hora errada.
      'starts_at': startsAt.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return Appointment.fromJson(json);
  }

  Future<Appointment> cancelAppointment({
    required String appointmentId,
    required String phone,
  }) async {
    final json = await _client.post('/v1/appointments/$appointmentId/cancel', {
      'phone': phone,
    }) as Map<String, dynamic>;
    return Appointment.fromJson(json);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
