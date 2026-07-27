import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../services/agenda_api.dart';
import '../services/api_client.dart';
import '../services/appointment_store.dart';
import '../widgets/future_loader.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final _store = AppointmentStore();
  final _api = AgendaApi(ApiClient());
  Key _listKey = UniqueKey();

  void _refresh() {
    setState(() {
      _listKey = UniqueKey();
    });
  }

  Future<void> _cancel(SavedAppointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar agendamento?'),
        content: Text('${appointment.serviceName} — ${_formatWhen(appointment.startsAt)}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar agendamento'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.cancelAppointment(appointmentId: appointment.id, phone: appointment.clientPhone);
      await _store.updateStatus(appointment.id, 'cancelled');
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento cancelado.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar. Tente novamente.')),
      );
    }
  }

  String _formatWhen(DateTime dateTime) {
    // dateTime vem com offset explícito da API/armazenamento local — sem
    // toLocal() mostraria o horário errado (Dart normaliza pra UTC ao
    // fazer parse de uma string com offset).
    return DateFormat("EEE, d 'de' MMM 'às' HH:mm", 'pt_BR').format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus agendamentos')),
      body: SafeArea(
        child: FutureLoader<List<SavedAppointment>>(
          key: _listKey,
          future: _store.list,
          builder: (context, appointments) {
            if (appointments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhum agendamento feito por este aparelho ainda.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: appointments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final appointment = appointments[index];
                final isCancelled = appointment.status == 'cancelled';
                final canCancel = !isCancelled && appointment.startsAt.isAfter(DateTime.now());

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                appointment.serviceName,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            _StatusBadge(status: appointment.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('com ${appointment.professionalName}'),
                        Text(_formatWhen(appointment.startsAt)),
                        if (canCancel) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () => _cancel(appointment),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  static const _labels = {
    'scheduled': 'Agendado',
    'confirmed': 'Confirmado',
    'cancelled': 'Cancelado',
    'completed': 'Concluído',
    'no_show': 'Não compareceu',
  };

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == 'cancelled';
    final colorScheme = Theme.of(context).colorScheme;
    final color = isCancelled ? Theme.of(context).hintColor : colorScheme.primary;

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
