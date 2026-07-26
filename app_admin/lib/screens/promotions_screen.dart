import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/promotion.dart';
import '../models/service.dart';
import '../services/admin_api.dart';
import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/future_loader.dart';

/// RF-ADM-04.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  Key _listKey = UniqueKey();

  void _refresh() => setState(() => _listKey = UniqueKey());

  Future<void> _openDialog({Promotion? existing}) async {
    final api = context.read<AuthController>().api;
    final services = await api.getServices();
    if (!context.mounted) return;
    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre um serviço antes de criar uma promoção.')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PromotionDialog(api: api, services: services, existing: existing),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;

    return Scaffold(
      body: FutureLoader<List<Promotion>>(
        key: _listKey,
        future: api.getPromotions,
        builder: (context, promotions) {
          if (promotions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma promoção cadastrada ainda.\nCrie uma para destacar um serviço no app do cliente.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: promotions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final promotion = promotions[index];
              final discountLabel = promotion.discountType == 'percentage'
                  ? '${promotion.discountValue}% off'
                  : 'R\$ ${(promotion.discountValue / 100).toStringAsFixed(2)} off';
              final statusLabel = promotion.isActive ? '' : ' · Inativa';
              return Card(
                child: ListTile(
                  title: Text(promotion.name),
                  subtitle: Text(
                    '$discountLabel · ${DateFormat('d MMM', 'pt_BR').format(promotion.startsAt)} a '
                    '${DateFormat('d MMM', 'pt_BR').format(promotion.endsAt)}$statusLabel',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDialog(existing: promotion),
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

class _PromotionDialog extends StatefulWidget {
  const _PromotionDialog({required this.api, required this.services, this.existing});

  final AdminApi api;
  final List<Service> services;
  final Promotion? existing;

  @override
  State<_PromotionDialog> createState() => _PromotionDialogState();
}

class _PromotionDialogState extends State<_PromotionDialog> {
  late final TextEditingController _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _valueController = TextEditingController(
    text: widget.existing != null ? _initialValueText(widget.existing!) : '',
  );
  late Service _service = widget.services.firstWhere(
    (service) => service.id == widget.existing?.serviceId,
    orElse: () => widget.services.first,
  );
  late String _discountType = widget.existing?.discountType ?? 'percentage';
  late DateTime _startsAt = widget.existing?.startsAt ?? DateTime.now();
  late DateTime _endsAt = widget.existing?.endsAt ?? DateTime.now().add(const Duration(days: 7));
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  static String _initialValueText(Promotion promotion) {
    if (promotion.discountType == 'percentage') return promotion.discountValue.toString();
    return (promotion.discountValue / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startsAt : _endsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome da promoção.');
      return;
    }
    final rawValue = double.tryParse(_valueController.text.trim().replaceAll(',', '.'));
    if (rawValue == null || rawValue < 0) {
      setState(() => _error = 'Informe um valor de desconto válido.');
      return;
    }
    if (_discountType == 'percentage' && rawValue > 100) {
      setState(() => _error = 'Desconto percentual não pode passar de 100%.');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _error = 'A data final precisa ser depois da inicial.');
      return;
    }

    final discountValue = _discountType == 'percentage' ? rawValue.round() : (rawValue * 100).round();

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await widget.api.updatePromotion(
          widget.existing!.id,
          name: name,
          discountType: _discountType,
          discountValue: discountValue,
          startsAt: _startsAt,
          endsAt: _endsAt,
          isActive: _isActive,
        );
      } else {
        await widget.api.createPromotion(
          serviceId: _service.id,
          name: name,
          discountType: _discountType,
          discountValue: discountValue,
          startsAt: _startsAt,
          endsAt: _endsAt,
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
      title: Text(_isEditing ? 'Editar promoção' : 'Nova promoção'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEditing)
              DropdownButtonFormField<Service>(
                value: _service,
                decoration: const InputDecoration(labelText: 'Serviço'),
                items: [
                  for (final service in widget.services)
                    DropdownMenuItem(value: service, child: Text(service.name)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _service = value);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Serviço: ${_service.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome da promoção'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _discountType,
              decoration: const InputDecoration(labelText: 'Tipo de desconto'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Percentual (%)')),
                DropdownMenuItem(value: 'fixed', child: Text('Valor fixo (R\$)')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _discountType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: _discountType == 'percentage' ? 'Desconto (%)' : 'Desconto (R\$)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('De'),
              trailing: Text(DateFormat("d 'de' MMM", 'pt_BR').format(_startsAt)),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Até'),
              trailing: Text(DateFormat("d 'de' MMM", 'pt_BR').format(_endsAt)),
              onTap: () => _pickDate(isStart: false),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativa'),
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
