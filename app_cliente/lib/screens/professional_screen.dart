import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/professional.dart';
import '../services/agenda_api.dart';
import '../services/api_client.dart';
import '../state/booking_controller.dart';
import '../widgets/future_loader.dart';
import 'schedule_screen.dart';

class ProfessionalScreen extends StatelessWidget {
  const ProfessionalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = context.read<BookingController>();
    final serviceId = booking.selectedService!.id;
    final api = AgendaApi(ApiClient());

    return Scaffold(
      appBar: AppBar(title: const Text('Escolha o profissional')),
      body: SafeArea(
        child: FutureLoader<List<Professional>>(
          future: () => api.getProfessionals(serviceId),
          builder: (context, professionals) {
            if (professionals.isEmpty) {
              return const Center(child: Text('Nenhum profissional disponível para este serviço.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: professionals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final professional = professionals[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: Text(professional.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(professional.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () {
                      context.read<BookingController>().selectProfessional(professional);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                      );
                    },
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
