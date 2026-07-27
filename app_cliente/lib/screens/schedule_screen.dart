import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/agenda_api.dart';
import '../services/api_client.dart';
import '../state/booking_controller.dart';
import '../widgets/future_loader.dart';
import 'confirmation_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _daysAhead = 14;

  final _api = AgendaApi(ApiClient());
  late DateTime _selectedDate;
  late Future<List<DateTime>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadSlots();
  }

  void _loadSlots() {
    final booking = context.read<BookingController>();
    _slotsFuture = _api.getAvailability(
      professionalId: booking.selectedProfessional!.id,
      serviceId: booking.selectedService!.id,
      date: _selectedDate,
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _loadSlots();
    });
  }

  void _selectSlot(DateTime slot) {
    context.read<BookingController>().selectSlot(slot);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfirmationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(_daysAhead, (i) => today.add(Duration(days: i)))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toList();
    // Mostra o mês só no primeiro chip e sempre que ele mudar em relação
    // ao anterior — evita ambiguidade tipo "dia 7" sem saber se é deste
    // mês ou do próximo, sem poluir todos os 14 chips com o mês repetido.
    final showMonthAt = <bool>[
      for (var i = 0; i < days.length; i++) i == 0 || days[i].month != days[i - 1].month,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Escolha o horário')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = days[index];
                  return _DateChip(
                    date: day,
                    isSelected: day == _selectedDate,
                    showMonth: showMonthAt[index],
                    onTap: () => _selectDate(day),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureLoader<List<DateTime>>(
                key: ValueKey(_selectedDate),
                future: () => _slotsFuture,
                builder: (context, slots) {
                  if (slots.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Sem horários disponíveis neste dia. Tente outra data.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      return OutlinedButton(
                        onPressed: () => _selectSlot(slot),
                        // toLocal(): a API manda offset explícito e o Dart
                        // normaliza pra UTC ao dar parse — sem isso mostra
                        // a hora errada. O valor enviado pra API em
                        // _selectSlot continua o original (UTC), só a
                        // exibição precisa ser local.
                        child: Text(DateFormat.Hm('pt_BR').format(slot.toLocal())),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.showMonth,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool showMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthColor = isSelected ? Colors.white70 : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? colorScheme.primary : Theme.of(context).dividerColor),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat.E('pt_BR').format(date),
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date.day.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isSelected ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 1),
            // Só aparece no 1º chip e sempre que o mês mudar — evita
            // ambiguidade tipo "dia 7" sem saber de qual mês, sem repetir
            // o mês nos 14 chips.
            SizedBox(
              height: 11,
              child: showMonth
                  ? Text(
                      DateFormat.MMM('pt_BR').format(date),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: monthColor),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
