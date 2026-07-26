import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/professional.dart';
import '../models/service.dart';
import '../services/admin_api.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/future_loader.dart';

/// RF-ADM-01. A associação profissional↔serviço só é editável na
/// criação — `ProfessionalOut` não devolve `service_ids`, então editar
/// exigiria uma consulta extra pra saber o que já está vinculado; sem
/// isso, reenviar `service_ids` na edição arriscaria desvincular tudo por
/// engano. Reatribuir serviços de um profissional existente fica para
/// uma iteração futura.
class ProfessionalsScreen extends StatefulWidget {
  const ProfessionalsScreen({super.key});

  @override
  State<ProfessionalsScreen> createState() => _ProfessionalsScreenState();
}

class _ProfessionalsScreenState extends State<ProfessionalsScreen> {
  Key _listKey = UniqueKey();

  void _refresh() => setState(() => _listKey = UniqueKey());

  Future<void> _openDialog({Professional? existing}) async {
    final api = context.read<AuthController>().api;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProfessionalDialog(api: api, existing: existing),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;

    return Scaffold(
      body: FutureLoader<List<Professional>>(
        key: _listKey,
        future: api.getProfessionalsForAdmin,
        builder: (context, professionals) {
          if (professionals.isEmpty) {
            return const Center(child: Text('Nenhum profissional cadastrado ainda.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: professionals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final professional = professionals[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        professional.isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor,
                    foregroundColor: Colors.white,
                    child: Text(
                      professional.name.isEmpty ? '?' : professional.name.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(professional.name),
                  subtitle: Text(professional.isActive ? (professional.phone ?? 'Sem telefone') : 'Inativo'),
                  onTap: () => _openDialog(existing: professional),
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

class _ProfessionalDialog extends StatefulWidget {
  const _ProfessionalDialog({required this.api, this.existing});

  final AdminApi api;
  final Professional? existing;

  @override
  State<_ProfessionalDialog> createState() => _ProfessionalDialogState();
}

class _ProfessionalDialogState extends State<_ProfessionalDialog> {
  late final TextEditingController _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
  final Set<String> _selectedServiceIds = {};
  late bool _isActive = widget.existing?.isActive ?? true;
  List<Service>? _services;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditing) {
      _loadServices();
    }
  }

  Future<void> _loadServices() async {
    try {
      final services = await widget.api.getServices();
      if (mounted) setState(() => _services = services);
    } on ApiException {
      if (mounted) setState(() => _services = []);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final phone = _phoneController.text.trim();
      if (_isEditing) {
        await widget.api.updateProfessional(
          widget.existing!.id,
          name: name,
          phone: phone.isEmpty ? null : phone,
          isActive: _isActive,
        );
      } else {
        await widget.api.createProfessional(
          name: name,
          phone: phone.isEmpty ? null : phone,
          serviceIds: _selectedServiceIds.toList(),
        );
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
      title: Text(_isEditing ? 'Editar profissional' : 'Novo profissional'),
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
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
              keyboardType: TextInputType.phone,
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
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Serviços',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_services == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_services!.isEmpty)
                const Text('Nenhum serviço cadastrado ainda.')
              else
                ..._services!.map(
                  (service) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(service.name),
                    value: _selectedServiceIds.contains(service.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedServiceIds.add(service.id);
                        } else {
                          _selectedServiceIds.remove(service.id);
                        }
                      });
                    },
                  ),
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
