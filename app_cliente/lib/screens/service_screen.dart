import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service.dart';
import '../services/agenda_api.dart';
import '../services/api_client.dart';
import '../state/booking_controller.dart';
import '../widgets/future_loader.dart';
import 'professional_screen.dart';

class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = AgendaApi(ApiClient());

    return Scaffold(
      appBar: AppBar(title: const Text('Escolha o serviço')),
      body: SafeArea(
        child: FutureLoader<List<Service>>(
          future: api.getServices,
          builder: (context, services) {
            if (services.isEmpty) {
              return const Center(child: Text('Nenhum serviço disponível no momento.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final service = services[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Chip(label: Text('${service.durationMinutes} min')),
                    onTap: () {
                      context.read<BookingController>().selectService(service);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfessionalScreen()),
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
