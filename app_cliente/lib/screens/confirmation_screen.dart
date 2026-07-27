import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../services/agenda_api.dart';
import '../services/api_client.dart';
import '../services/appointment_store.dart';
import '../state/booking_controller.dart';
import 'success_screen.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final _api = AgendaApi(ApiClient());
  final _store = AppointmentStore();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _confirm() async {
    final booking = context.read<BookingController>();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final appointment = await _api.createAppointment(
        clientName: booking.clientName!,
        clientPhone: booking.clientPhone!,
        serviceId: booking.selectedService!.id,
        professionalId: booking.selectedProfessional!.id,
        startsAt: booking.selectedSlot!,
      );

      await _store.save(SavedAppointment(
        id: appointment.id,
        serviceName: booking.selectedService!.name,
        professionalName: booking.selectedProfessional!.name,
        clientPhone: booking.clientPhone!,
        startsAt: appointment.startsAt,
        endsAt: appointment.endsAt,
        status: appointment.status,
      ));

      booking.confirmAppointment(appointment);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
      );
    } on ApiException catch (error) {
      final wasSlotTaken = error.statusCode == 409;
      setState(() {
        _submitting = false;
        _errorMessage = error.message;
      });
      if (wasSlotTaken && mounted) {
        // horário acabou de ser ocupado por outra pessoa — volta pra escolha de horário
        Navigator.of(context).pop();
      }
    } catch (_) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Não foi possível conectar. Verifique sua internet e tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    final service = booking.selectedService!;
    final professional = booking.selectedProfessional!;
    final slot = booking.selectedSlot!;
    final endsAt = slot.add(Duration(minutes: service.durationMinutes));
    // A API manda horário com offset explícito (ex.: -03:00), e o Dart
    // normaliza isso pra UTC internamente — sem converter de volta pra
    // local antes de formatar, a tela mostraria a hora errada (+3h no
    // horário de Brasília).
    final localSlot = slot.toLocal();
    final localEndsAt = endsAt.toLocal();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirme e agende')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Serviço', value: service.name),
                      _SummaryRow(label: 'Profissional', value: professional.name),
                      _SummaryRow(
                        label: 'Data',
                        value: DateFormat("EEE, d 'de' MMM", 'pt_BR').format(localSlot),
                      ),
                      _SummaryRow(
                        label: 'Horário',
                        value:
                            '${DateFormat.Hm('pt_BR').format(localSlot)} – ${DateFormat.Hm('pt_BR').format(localEndsAt)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Você pode cancelar pela tela "Meus agendamentos", respeitando o '
                'prazo mínimo definido pela barbearia.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: _submitting ? null : _confirm,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar agendamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
