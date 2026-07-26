import 'package:flutter/material.dart';

/// Horário de funcionamento de um dia da semana.
///
/// `weekday` segue a convenção do backend (database/schema.sql):
/// 0 = domingo .. 6 = sábado — **não** é o `DateTime.weekday` do Dart
/// (que é 1 = segunda .. 7 = domingo).
class BusinessHoursDay {
  const BusinessHoursDay({
    required this.weekday,
    required this.isClosed,
    this.opensAt,
    this.closesAt,
  });

  final int weekday;
  final bool isClosed;
  final TimeOfDay? opensAt;
  final TimeOfDay? closesAt;

  static const List<String> weekdayLabels = [
    'Domingo',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
  ];

  String get weekdayLabel => weekdayLabels[weekday];

  BusinessHoursDay copyWith({
    bool? isClosed,
    TimeOfDay? opensAt,
    TimeOfDay? closesAt,
  }) {
    return BusinessHoursDay(
      weekday: weekday,
      isClosed: isClosed ?? this.isClosed,
      opensAt: opensAt ?? this.opensAt,
      closesAt: closesAt ?? this.closesAt,
    );
  }

  factory BusinessHoursDay.fromJson(Map<String, dynamic> json) {
    return BusinessHoursDay(
      weekday: json['weekday'] as int,
      isClosed: json['is_closed'] as bool,
      opensAt: _parseTime(json['opens_at'] as String?),
      closesAt: _parseTime(json['closes_at'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekday': weekday,
      'is_closed': isClosed,
      'opens_at': _formatTime(opensAt),
      'closes_at': _formatTime(closesAt),
    };
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}
