import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';

/// Persistência local de "meus agendamentos" — ver a nota em
/// lib/models/appointment.dart sobre por que isso vive no aparelho e não
/// no backend.
class AppointmentStore {
  static const _storageKey = 'agenda360.saved_appointments';

  Future<List<SavedAppointment>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const <String>[];
    final appointments = raw
        .map((item) => SavedAppointment.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    appointments.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return appointments;
  }

  Future<void> save(SavedAppointment appointment) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    raw.add(jsonEncode(appointment.toJson()));
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> updateStatus(String appointmentId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    final updated = raw.map((item) {
      final decoded = SavedAppointment.fromJson(jsonDecode(item) as Map<String, dynamic>);
      if (decoded.id == appointmentId) {
        return jsonEncode(decoded.copyWith(status: status).toJson());
      }
      return item;
    }).toList();
    await prefs.setStringList(_storageKey, updated);
  }
}
