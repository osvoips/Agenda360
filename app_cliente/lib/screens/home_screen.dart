import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/agenda_api.dart';
import '../services/api_client.dart';
import '../state/booking_controller.dart';
import '../widgets/future_loader.dart';
import 'client_info_screen.dart';
import 'my_appointments_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = AgendaApi(ApiClient());

    return Scaffold(
      body: SafeArea(
        child: FutureLoader(
          future: api.getTenant,
          builder: (context, tenant) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(tenant.displayName),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tenant.displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agende seu horário em menos de 30 segundos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      context.read<BookingController>().reset();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ClientInfoScreen()),
                      );
                    },
                    child: const Text('Agendar horário'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
                      );
                    },
                    child: const Text('Já tenho um agendamento'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
