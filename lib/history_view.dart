import 'package:flutter/material.dart';

import 'day_key.dart';
import 'rewards.dart';
import 'session_controller.dart';

/// Calendario independiente para las sesiones de Foco.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.state, required this.now});

  final SessionView state;
  final DateTime now;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late DateTime _month;
  late DateTime _selected;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.now.year, widget.now.month);
    _selected = _day(widget.now);
  }

  @override
  void didUpdateWidget(covariant HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_day(oldWidget.now).isAtSameMomentAs(_day(widget.now))) {
      _selected = _day(widget.now);
      _month = DateTime(widget.now.year, widget.now.month);
    }
  }

  int _value(DateTime day) => widget.state.history[localDayKey(day)] ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _day(widget.now);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
    final monthName = MaterialLocalizations.of(context).formatMonthYear(_month);
    final values = List.generate(daysInMonth, (i) => _value(DateTime(_month.year, _month.month, i + 1)));
    final monthTotal = values.fold<int>(0, (a, b) => a + b);
    final activeDays = values.where((v) => v > 0).length;
    final allTime = widget.state.history.values.fold<int>(0, (a, b) => a + b);
    final selectedValue = _value(_selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.timer_rounded, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendario de Foco', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Tus sesiones completadas por día', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _metric(context, 'Este mes', rewardLabel(monthTotal))),
            const SizedBox(width: 8),
            Expanded(child: _metric(context, 'Días activos', '$activeDays')),
            const SizedBox(width: 8),
            Expanded(child: _metric(context, 'Total', rewardLabel(allTime))),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mes anterior',
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(monthName, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: 'Mes siguiente',
                      onPressed: DateTime(_month.year, _month.month + 1).isAfter(DateTime(today.year, today.month))
                          ? null
                          : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                      .map((d) => Expanded(child: Center(child: Text(d, style: theme.textTheme.labelMedium))))
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cellCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final number = index - firstWeekday + 1;
                    if (number < 1 || number > daysInMonth) return const SizedBox.shrink();
                    final date = DateTime(_month.year, _month.month, number);
                    final value = _value(date);
                    final future = date.isAfter(today);
                    final active = value > 0;
                    final selected = _day(date).isAtSameMomentAs(_selected);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: future ? null : () => setState(() => _selected = date),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: active
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                                )
                              : null,
                          color: active ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                            width: selected ? 2 : 0.7,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$number', style: TextStyle(
                              fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                              color: active ? Colors.white : theme.colorScheme.onSurface,
                            )),
                            if (active)
                              Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: theme.colorScheme.tertiary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Día con sesiones', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 16),
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Sin sesiones', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selected.day}/${_selected.month}/${_selected.year}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(rewardLabel(selectedValue), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                Text(
                  selectedValue > 0 ? 'Tiempo total de sesiones completadas' : 'No hay sesiones completadas en este día.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
}
