import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/agenda_appointment.dart';
import '../models/professional.dart';
import '../services/admin_api.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/future_loader.dart';
import '../widgets/status_badge.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedDay = _startOfDay(DateTime.now());
  late DateTime _weekStart = _startOfWeek(_selectedDay);

  /// Guardado no estado (não recriado a cada build) — um FutureBuilder
  /// novo a cada build reiniciaria a busca sempre que o widget
  /// reconstruísse por qualquer outro motivo. Reaproveitado tanto no
  /// corpo quanto no FAB, para não buscar os mesmos dados duas vezes.
  late Future<_AgendaLookups> _lookupsFuture;

  static DateTime _startOfDay(DateTime day) => DateTime(day.year, day.month, day.day);
  static DateTime _startOfWeek(DateTime day) => day.subtract(Duration(days: day.weekday % 7));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lookupsFuture = _loadLookups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reloadLookups() => setState(() => _lookupsFuture = _loadLookups());

  Future<_AgendaLookups> _loadLookups() async {
    final api = context.read<AuthController>().api;
    final professionals = await api.getProfessionalsForStaff();
    final services = await api.getServicesForDisplay();
    return _AgendaLookups(
      professionalNames: {for (final professional in professionals) professional.id: professional.name},
      serviceNames: {for (final service in services) service.id: service.name},
      professionals: professionals,
    );
  }

  Future<void> _openBlockDialog(_AgendaLookups lookups) async {
    final api = context.read<AuthController>().api;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _BlockSlotDialog(professionals: lookups.professionals, api: api),
    );
    if (created == true) _reloadLookups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            tabs: const [Tab(text: 'Dia'), Tab(text: 'Semana')],
          ),
          Expanded(
            child: FutureBuilder<_AgendaLookups>(
              future: _lookupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(snapshot.error.toString(), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: _reloadLookups, child: const Text('Tentar novamente')),
                        ],
                      ),
                    ),
                  );
                }

                final lookups = snapshot.data!;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _DayView(
                      date: _selectedDay,
                      lookups: lookups,
                      onDateChanged: (date) => setState(() => _selectedDay = date),
                    ),
                    _WeekView(
                      startDate: _weekStart,
                      lookups: lookups,
                      onWeekChanged: (date) => setState(() => _weekStart = date),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<_AgendaLookups>(
        future: _lookupsFuture,
        builder: (context, snapshot) {
          final lookups = snapshot.data;
          return FloatingActionButton.extended(
            onPressed: lookups == null ? null : () => _openBlockDialog(lookups),
            icon: const Icon(Icons.block),
            label: const Text('Bloquear horário'),
          );
        },
      ),
    );
  }
}

class _AgendaLookups {
  const _AgendaLookups({
    required this.professionalNames,
    required this.serviceNames,
    required this.professionals,
  });

  final Map<String, String> professionalNames;
  final Map<String, String> serviceNames;
  final List<Professional> professionals;
}

class _DayView extends StatefulWidget {
  const _DayView({required this.date, required this.lookups, required this.onDateChanged});

  final DateTime date;
  final _AgendaLookups lookups;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  Key _reloadToken = UniqueKey();

  void _reload() => setState(() => _reloadToken = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => widget.onDateChanged(widget.date.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: Text(
                  DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(widget.date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => widget.onDateChanged(widget.date.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureLoader<List<AgendaAppointment>>(
            key: ValueKey('${widget.date.toIso8601String()}-$_reloadToken'),
            future: () => api.getDayAgenda(widget.date),
            builder: (context, appointments) {
              if (appointments.isEmpty) {
                return const Center(child: Text('Nenhum agendamento neste dia.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: appointments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final appointment = appointments[index];
                  return _AppointmentCard(
                    appointment: appointment,
                    professionalName: widget.lookups.professionalNames[appointment.professionalId] ?? '—',
                    serviceName: widget.lookups.serviceNames[appointment.serviceId] ?? '—',
                    onChanged: _reload,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.professionalName,
    required this.serviceName,
    required this.onChanged,
  });

  final AgendaAppointment appointment;
  final String professionalName;
  final String serviceName;
  final VoidCallback onChanged;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _busy = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthController>().api.confirmAppointment(widget.appointment.id);
      widget.onChanged();
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível conectar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar agendamento?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Voltar')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(reasonController.text.trim()),
            child: const Text('Cancelar agendamento'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await context.read<AuthController>().api.cancelAppointment(
            widget.appointment.id,
            reason: reason.isEmpty ? null : reason,
          );
      widget.onChanged();
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível conectar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final canAct = appointment.status != 'cancelled' && appointment.status != 'completed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.Hm('pt_BR').format(appointment.startsAt),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                StatusBadge(status: appointment.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(appointment.clientName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${widget.serviceName} · ${widget.professionalName}'),
            Text(appointment.clientPhone, style: Theme.of(context).textTheme.bodySmall),
            if (canAct) ...[
              const SizedBox(height: 10),
              if (_busy)
                const Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (appointment.status == 'scheduled')
                      TextButton(onPressed: _confirm, child: const Text('Confirmar')),
                    TextButton(
                      onPressed: _cancel,
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.startDate, required this.lookups, required this.onWeekChanged});

  final DateTime startDate;
  final _AgendaLookups lookups;
  final ValueChanged<DateTime> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;
    final weekEnd = startDate.add(const Duration(days: 6));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onWeekChanged(startDate.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Text(
                  '${DateFormat('d MMM', 'pt_BR').format(startDate)} – '
                  '${DateFormat('d MMM', 'pt_BR').format(weekEnd)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onWeekChanged(startDate.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureLoader<List<AgendaAppointment>>(
            key: ValueKey(startDate.toIso8601String()),
            future: () => api.getWeekAgenda(startDate),
            builder: (context, appointments) {
              if (appointments.isEmpty) {
                return const Center(child: Text('Nenhum agendamento nesta semana.'));
              }

              final byDay = <DateTime, List<AgendaAppointment>>{};
              for (final appointment in appointments) {
                final day = DateTime(
                  appointment.startsAt.year,
                  appointment.startsAt.month,
                  appointment.startsAt.day,
                );
                byDay.putIfAbsent(day, () => []).add(appointment);
              }
              final days = byDay.keys.toList()..sort();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final day in days) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(
                        DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(day),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (final appointment in byDay[day]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Text(
                              DateFormat.Hm('pt_BR').format(appointment.startsAt),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            title: Text(appointment.clientName),
                            subtitle: Text(
                              '${lookups.serviceNames[appointment.serviceId] ?? '—'} · '
                              '${lookups.professionalNames[appointment.professionalId] ?? '—'}',
                            ),
                            trailing: StatusBadge(status: appointment.status),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BlockSlotDialog extends StatefulWidget {
  const _BlockSlotDialog({required this.professionals, required this.api});

  final List<Professional> professionals;
  final AdminApi api;

  @override
  State<_BlockSlotDialog> createState() => _BlockSlotDialogState();
}

class _BlockSlotDialogState extends State<_BlockSlotDialog> {
  Professional? _professional;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.professionals.isNotEmpty) {
      _professional = widget.professionals.first;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  DateTime _combine(TimeOfDay time) {
    return DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (_professional == null) {
      setState(() => _error = 'Nenhum profissional disponível.');
      return;
    }
    final startsAt = _combine(_startTime);
    final endsAt = _combine(_endTime);
    if (!endsAt.isAfter(startsAt)) {
      setState(() => _error = 'O horário final precisa ser depois do inicial.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.api.createBlockedSlot(
        professionalId: _professional!.id,
        startsAt: startsAt,
        endsAt: endsAt,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Não foi possível conectar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bloquear horário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.professionals.isEmpty)
              const Text('Nenhum profissional cadastrado.')
            else
              DropdownButtonFormField<Professional>(
                value: _professional,
                decoration: const InputDecoration(labelText: 'Profissional'),
                items: [
                  for (final professional in widget.professionals)
                    DropdownMenuItem(value: professional, child: Text(professional.name)),
                ],
                onChanged: (value) => setState(() => _professional = value),
              ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              trailing: Text(DateFormat("d 'de' MMM", 'pt_BR').format(_date)),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Início'),
              trailing: Text(_startTime.format(context)),
              onTap: () => _pickTime(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fim'),
              trailing: Text(_endTime.format(context)),
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Bloquear'),
        ),
      ],
    );
  }
}
