import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service.dart';
import '../services/admin_api.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/future_loader.dart';

/// RF-ADM-02.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  Key _listKey = UniqueKey();

  void _refresh() => setState(() => _listKey = UniqueKey());

  Future<void> _openDialog({Service? existing}) async {
    final api = context.read<AuthController>().api;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServiceDialog(api: api, existing: existing),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;

    return Scaffold(
      body: FutureLoader<List<Service>>(
        key: _listKey,
        future: api.getServices,
        builder: (context, services) {
          if (services.isEmpty) {
            return const Center(child: Text('Nenhum serviço cadastrado ainda.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final service = services[index];
              final priceLabel =
                  service.priceCents != null ? ' · R\$ ${(service.priceCents! / 100).toStringAsFixed(2)}' : '';
              final statusLabel = service.isActive ? '' : ' · Inativo';
              return Card(
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Text('${service.durationMinutes} min$priceLabel$statusLabel'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDialog(existing: service),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({required this.api, this.existing});

  final AdminApi api;
  final Service? existing;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  late final TextEditingController _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _durationController =
      TextEditingController(text: widget.existing != null ? widget.existing!.durationMinutes.toString() : '');
  late final TextEditingController _priceController = TextEditingController(
    text: widget.existing?.priceCents != null ? (widget.existing!.priceCents! / 100).toStringAsFixed(2) : '',
  );
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome do serviço.');
      return;
    }
    if (duration == null || duration <= 0) {
      setState(() => _error = 'Informe uma duração válida, em minutos.');
      return;
    }

    final priceText = _priceController.text.trim().replaceAll(',', '.');
    int? priceCents;
    if (priceText.isNotEmpty) {
      final priceValue = double.tryParse(priceText);
      if (priceValue == null || priceValue < 0) {
        setState(() => _error = 'Informe um preço válido, ou deixe em branco.');
        return;
      }
      priceCents = (priceValue * 100).round();
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await widget.api.updateService(
          widget.existing!.id,
          name: name,
          durationMinutes: duration,
          priceCents: priceCents,
          isActive: _isActive,
        );
      } else {
        await widget.api.createService(name: name, durationMinutes: duration, priceCents: priceCents);
      }
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
      title: Text(_isEditing ? 'Editar serviço' : 'Novo serviço'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duração (minutos)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Preço em R\$ (opcional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
