import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import 'agenda_screen.dart';
import 'business_hours_screen.dart';
import 'professionals_screen.dart';
import 'promotions_screen.dart';
import 'services_screen.dart';

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.builder,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool adminOnly;
}

final List<_NavItem> _navItems = <_NavItem>[
  _NavItem(label: 'Agenda', icon: Icons.calendar_today, builder: (_) => const AgendaScreen()),
  _NavItem(
    label: 'Horário de funcionamento',
    icon: Icons.schedule,
    builder: (_) => const BusinessHoursScreen(),
  ),
  _NavItem(
    label: 'Profissionais',
    icon: Icons.badge,
    builder: (_) => const ProfessionalsScreen(),
    adminOnly: true,
  ),
  _NavItem(
    label: 'Serviços',
    icon: Icons.content_cut,
    builder: (_) => const ServicesScreen(),
    adminOnly: true,
  ),
  _NavItem(
    label: 'Promoções',
    icon: Icons.local_offer,
    builder: (_) => const PromotionsScreen(),
    adminOnly: true,
  ),
];

/// Um único app pros dois papéis (staff/admin) — a navegação mostra mais ou
/// menos itens conforme `AuthController.isAdmin` (ver ARCHITECTURE.md §3).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final items = _navItems.where((item) => !item.adminOnly || auth.isAdmin).toList();
    final selectedIndex = _selectedIndex.clamp(0, items.length - 1);
    final current = items[selectedIndex];

    return Scaffold(
      appBar: AppBar(title: Text(current.label)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carioca Barbearia',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    if (auth.email != null) Text(auth.email!, style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      auth.isAdmin ? 'Administrador' : 'Equipe',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      ListTile(
                        leading: Icon(items[i].icon),
                        title: Text(items[i].label),
                        selected: i == selectedIndex,
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.read<AuthController>().logout();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: current.builder(context),
    );
  }
}
