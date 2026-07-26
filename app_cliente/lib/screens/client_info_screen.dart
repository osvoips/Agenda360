import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/booking_controller.dart';
import 'service_screen.dart';

class ClientInfoScreen extends StatefulWidget {
  const ClientInfoScreen({super.key});

  @override
  State<ClientInfoScreen> createState() => _ClientInfoScreenState();
}

class _ClientInfoScreenState extends State<ClientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    context.read<BookingController>().setClientInfo(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seus dados')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pra começar, como podemos te chamar?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Informe seu nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone (WhatsApp)'),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) {
                      return 'Informe um telefone válido, com DDD';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Usamos seu telefone só para confirmar e lembrar do seu horário.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _continue, child: const Text('Continuar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
