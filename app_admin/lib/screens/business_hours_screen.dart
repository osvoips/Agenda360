import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/business_hours.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';

/// RF-BAR-06 / RF-ADM-03 — mesmo endpoint, acessível a staff e admin.
class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  late Future<List<BusinessHoursDay>> _future;

  /// Estado editável local, populado quando `_future` resolve pela
  /// primeira vez — depois disso a tela renderiza a partir daqui, não do
  /// snapshot do FutureBuilder, pra permitir edição sem refazer a busca.
  List<BusinessHoursDay>? _days;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BusinessHoursDay>> _load() async {
    final api = context.read<AuthController>().api;
    final days = await api.getBusinessHours();
    days.sort((a, b) => a.weekday.compareTo(b.weekday));
    _days = List.of(days);
    return days;
  }

  void _reload() {
    setState(() {
      _days = null;
      _future = _load();
    });
  }

  void _updateDay(int index, BusinessHoursDay updated) {
    setState(() => _days![index] = updated);
  }

  Future<void> _save() async {
    final days = _days;
    if (days == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = context.read<AuthController>().api;
      final saved = await api.updateBusinessHours(days);
      saved.sort((a, b) => a.weekday.compareTo(b.weekday));
      setState(() => _days = List.of(saved));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horário de funcionamento atualizado.')),
        );
      }
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Não foi possível conectar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<BusinessHoursDay>>(
        future: _future,
        builder: (context, snapshot) {
          if (_days == null) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _reload, child: const Text('Tentar novamente')),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final days = _days!;
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _DayRow(
                      day: days[index],
                      onChanged: (updated) => _updateDay(index, updated),
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onChanged});

  final BusinessHoursDay day;
  final ValueChanged<BusinessHoursDay> onChanged;

  Future<void> _pickTime(BuildContext context, {required bool isOpen}) async {
    final initial = (isOpen ? day.opensAt : day.closesAt) ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    onChanged(isOpen ? day.copyWith(opensAt: picked) : day.copyWith(closesAt: picked));
  }

  @override
  Widget build(BuildContext context) {
    final opensAt = day.opensAt ?? const TimeOfDay(hour: 9, minute: 0);
    final closesAt = day.closesAt ?? const TimeOfDay(hour: 18, minute: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(day.weekdayLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: day.isClosed
                ? Text(
                    'Fechado',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                  )
                : Row(
                    children: [
                      TextButton(
                        onPressed: () => _pickTime(context, isOpen: true),
                        child: Text(opensAt.format(context)),
                      ),
                      const Text('–'),
                      TextButton(
                        onPressed: () => _pickTime(context, isOpen: false),
                        child: Text(closesAt.format(context)),
                      ),
                    ],
                  ),
          ),
          Switch(
            value: !day.isClosed,
            onChanged: (isOpen) {
              onChanged(
                day.copyWith(
                  isClosed: !isOpen,
                  opensAt: day.opensAt ?? const TimeOfDay(hour: 9, minute: 0),
                  closesAt: day.closesAt ?? const TimeOfDay(hour: 18, minute: 0),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
