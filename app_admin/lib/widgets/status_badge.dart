import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static const Map<String, String> _labels = {
    'scheduled': 'Agendado',
    'confirmed': 'Confirmado',
    'cancelled': 'Cancelado',
    'completed': 'Concluído',
    'no_show': 'Não compareceu',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color = switch (status) {
      'cancelled' => Theme.of(context).hintColor,
      'confirmed' => AppColors.success,
      'no_show' => AppColors.pending,
      _ => colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labels[status] ?? status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
