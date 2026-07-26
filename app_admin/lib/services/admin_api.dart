import '../models/agenda_appointment.dart';
import '../models/business_hours.dart';
import '../models/professional.dart';
import '../models/promotion.dart';
import '../models/service.dart';
import 'api_client.dart';

class LoginResult {
  const LoginResult({required this.accessToken, required this.role});

  final String accessToken;
  final String role;
}

/// Métodos tipados sobre os endpoints autenticados do backend — ver
/// backend/app/api/{auth,barbershop,admin}_routes.py para o contrato
/// exato.
class AdminApi {
  AdminApi(this._client);

  final ApiClient _client;

  Future<LoginResult> login({required String email, required String password}) async {
    final json = await _client.post('/v1/auth/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return LoginResult(accessToken: json['access_token'] as String, role: json['role'] as String);
  }

  // --- Agenda (RF-BAR-01/02) ---------------------------------------------

  Future<List<AgendaAppointment>> getDayAgenda(DateTime date) async {
    final json = await _client.get('/v1/barbershop/agenda/day', query: {
      'date': _formatDate(date),
    }) as List<dynamic>;
    return json.map((item) => AgendaAppointment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<AgendaAppointment>> getWeekAgenda(DateTime startDate) async {
    final json = await _client.get('/v1/barbershop/agenda/week', query: {
      'start_date': _formatDate(startDate),
    }) as List<dynamic>;
    return json.map((item) => AgendaAppointment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> confirmAppointment(String appointmentId) {
    return _client.post('/v1/barbershop/appointments/$appointmentId/confirm');
  }

  Future<void> cancelAppointment(String appointmentId, {String? reason}) {
    return _client.post('/v1/barbershop/appointments/$appointmentId/cancel', {'reason': reason});
  }

  // --- Bloqueios de horário (RF-BAR-05) -----------------------------------

  Future<void> createBlockedSlot({
    required String professionalId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) {
    return _client.post('/v1/barbershop/blocked-slots', {
      'professional_id': professionalId,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'reason': reason,
    });
  }

  Future<void> deleteBlockedSlot(String blockedSlotId) {
    return _client.delete('/v1/barbershop/blocked-slots/$blockedSlotId');
  }

  // --- Profissionais -------------------------------------------------------

  /// Só ativos — usado pelo seletor de bloqueio de horário. Acessível a
  /// staff e admin.
  Future<List<Professional>> getProfessionalsForStaff() async {
    final json = await _client.get('/v1/barbershop/professionals') as List<dynamic>;
    return json.map((item) => Professional.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Todos, incluindo inativos — usado na tela de cadastro (RF-ADM-01),
  /// que precisa poder reativar alguém. Admin only.
  Future<List<Professional>> getProfessionalsForAdmin() async {
    final json = await _client.get('/v1/admin/professionals') as List<dynamic>;
    return json.map((item) => Professional.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Professional> createProfessional({
    required String name,
    String? phone,
    List<String> serviceIds = const [],
  }) async {
    final json = await _client.post('/v1/admin/professionals', {
      'name': name,
      'phone': phone,
      'service_ids': serviceIds,
    }) as Map<String, dynamic>;
    return Professional.fromJson(json);
  }

  Future<Professional> updateProfessional(
    String id, {
    String? name,
    String? phone,
    bool? isActive,
    List<String>? serviceIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (isActive != null) body['is_active'] = isActive;
    if (serviceIds != null) body['service_ids'] = serviceIds;
    final json = await _client.put('/v1/admin/professionals/$id', body) as Map<String, dynamic>;
    return Professional.fromJson(json);
  }

  // --- Serviços -------------------------------------------------------------

  /// Endpoint público (não exige role) — usado para resolver `service_id`
  /// em nomes na tela de agenda, que staff também acessa.
  Future<List<Service>> getServicesForDisplay() async {
    final json = await _client.get('/v1/services') as List<dynamic>;
    return json.map((item) => Service.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// RF-ADM-02, admin only — inclui inativos, usado na tela de cadastro.
  Future<List<Service>> getServices() async {
    final json = await _client.get('/v1/admin/services') as List<dynamic>;
    return json.map((item) => Service.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Service> createService({
    required String name,
    required int durationMinutes,
    int? priceCents,
  }) async {
    final json = await _client.post('/v1/admin/services', {
      'name': name,
      'duration_minutes': durationMinutes,
      'price_cents': priceCents,
    }) as Map<String, dynamic>;
    return Service.fromJson(json);
  }

  Future<Service> updateService(
    String id, {
    String? name,
    int? durationMinutes,
    int? priceCents,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (durationMinutes != null) body['duration_minutes'] = durationMinutes;
    if (priceCents != null) body['price_cents'] = priceCents;
    if (isActive != null) body['is_active'] = isActive;
    final json = await _client.put('/v1/admin/services/$id', body) as Map<String, dynamic>;
    return Service.fromJson(json);
  }

  // --- Promoções (RF-ADM-04) ------------------------------------------------

  Future<List<Promotion>> getPromotions() async {
    final json = await _client.get('/v1/admin/promotions') as List<dynamic>;
    return json.map((item) => Promotion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Promotion> createPromotion({
    required String serviceId,
    required String name,
    required String discountType,
    required int discountValue,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final json = await _client.post('/v1/admin/promotions', {
      'service_id': serviceId,
      'name': name,
      'discount_type': discountType,
      'discount_value': discountValue,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
    }) as Map<String, dynamic>;
    return Promotion.fromJson(json);
  }

  Future<Promotion> updatePromotion(
    String id, {
    String? name,
    String? discountType,
    int? discountValue,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (discountType != null) body['discount_type'] = discountType;
    if (discountValue != null) body['discount_value'] = discountValue;
    if (startsAt != null) body['starts_at'] = startsAt.toIso8601String();
    if (endsAt != null) body['ends_at'] = endsAt.toIso8601String();
    if (isActive != null) body['is_active'] = isActive;
    final json = await _client.put('/v1/admin/promotions/$id', body) as Map<String, dynamic>;
    return Promotion.fromJson(json);
  }

  // --- Horário de funcionamento (RF-BAR-06 / RF-ADM-03) ---------------------

  Future<List<BusinessHoursDay>> getBusinessHours() async {
    final json = await _client.get('/v1/business-hours') as List<dynamic>;
    return json.map((item) => BusinessHoursDay.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<BusinessHoursDay>> updateBusinessHours(List<BusinessHoursDay> days) async {
    final json = await _client.put('/v1/business-hours', {
      'days': days.map((day) => day.toJson()).toList(),
    }) as List<dynamic>;
    return json.map((item) => BusinessHoursDay.fromJson(item as Map<String, dynamic>)).toList();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
