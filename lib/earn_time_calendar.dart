import 'package:flutter/material.dart';

import 'earn_time_view.dart';

/// Monthly productivity calendar backed by the daily snapshots stored natively.
class EarnTimeCalendarView extends StatefulWidget {
  const EarnTimeCalendarView({super.key, required this.controller});
  final EarnTimeController controller;

  @override
  State<EarnTimeCalendarView> createState() => _EarnTimeCalendarViewState();
}

class _EarnTimeCalendarViewState extends State<EarnTimeCalendarView> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    return '$minutes min';
  }

  Map<String, dynamic> _recordFor(DateTime date, Map<String, dynamic> data) {
    final key = _key(date);
    if (key == data['dayKey']) {
      return {
        'dayKey': key,
        'productiveSeconds': data['productiveSeconds'] ?? 0,
        'earnedSeconds': data['earnedSeconds'] ?? 0,
        'distractingSeconds': data['distractingSeconds'] ?? 0,
        'goalSeconds': data['productivityGoalSeconds'] ?? 3600,
        'dailyAllowanceSeconds': data['dailyAllowanceSeconds'] ?? 1800,
      };
    }
    final history = (data['history'] as List?) ?? const [];
    for (final item in history) {
      if (item is Map && item['dayKey'] == key) {
        return Map<String, dynamic>.from(item);
      }
    }
    return {};
  }

  bool _hasActivity(Map<String, dynamic> record) =>
      ((record['productiveSeconds'] as num?)?.toInt() ?? 0) > 0 ||
      ((record['distractingSeconds'] as num?)?.toInt() ?? 0) > 0;

  double _progress(Map<String, dynamic> record) {
    if (record.isEmpty) return 0;
    final goal = (record['goalSeconds'] as num?)?.toDouble() ?? 3600;
    final productive = (record['productiveSeconds'] as num?)?.toDouble() ?? 0;
    if (goal <= 0) return 0;
    return (productive / goal).clamp(0.0, 1.0);
  }

  Color _dayColor(BuildContext context, Map<String, dynamic> record) {
    if (record.isEmpty || !_hasActivity(record)) return Theme.of(context).colorScheme.surfaceContainerHighest;
    final progress = _progress(record);
    if (progress >= 0.8) return Colors.green.shade600;
    if (progress >= 0.5) return Colors.lightGreen.shade700;
    if (progress >= 0.25) return Colors.orange.shade700;
    return Theme.of(context).colorScheme.error.withValues(alpha: 0.72);
  }

  String _rating(Map<String, dynamic> record) {
    if (record.isEmpty || !_hasActivity(record)) return 'Sin actividad';
    final progress = _progress(record);
    if (progress >= 0.8) return 'Excelente';
    if (progress >= 0.5) return 'Buen día';
    if (progress >= 0.25) return 'En progreso';
    return 'Por debajo de la meta';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final data = widget.controller.data;
        final selected = _recordFor(_selected, data);
        final firstWeekday = DateTime(_month.year, _month.month, 1).weekday - 1;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
        const monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
        final monthName = monthNames[_month.month - 1];
        final goalMinutes = ((data['productivityGoalSeconds'] as num?)?.toInt() ?? 3600) ~/ 60;
        final today = DateTime.now();
        final isFuture = DateTime(_selected.year, _selected.month, _selected.day)
            .isAfter(DateTime(today.year, today.month, today.day));
        final productive = (selected['productiveSeconds'] as num?)?.toInt() ?? 0;
        final distracting = (selected['distractingSeconds'] as num?)?.toInt() ?? 0;
        final earned = (selected['earnedSeconds'] as num?)?.toInt() ?? 0;
        final goal = (selected['goalSeconds'] as num?)?.toInt() ?? 3600;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text('Calendario de productividad',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Cada día se valora automáticamente según tu meta productiva.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            _weeklyOverview(context, data),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Mes anterior',
                          onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month - 1);
                          }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '$monthName ${_month.year}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mes siguiente',
                          onPressed: DateTime(_month.year, _month.month + 1)
                                  .isAfter(DateTime(today.year, today.month))
                              ? null
                              : () => setState(() {
                                    _month = DateTime(_month.year, _month.month + 1);
                                  }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                          .map((day) => Expanded(
                                child: Center(
                                  child: Text(day,
                                      style: Theme.of(context).textTheme.labelMedium),
                                ),
                              ))
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
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (context, index) {
                        final dayNumber = index - firstWeekday + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime(_month.year, _month.month, dayNumber);
                        final record = _recordFor(date, data);
                        final isSelected = _key(date) == _key(_selected);
                        final future = date.isAfter(DateTime(today.year, today.month, today.day));
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: future ? null : () => setState(() => _selected = date),
                          child: Container(
                            decoration: BoxDecoration(
                              color: future
                                  ? Theme.of(context).colorScheme.surface
                                  : _dayColor(context, record).withValues(alpha: _hasActivity(record) ? 1 : 0.35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                width: isSelected ? 2 : 0.7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$dayNumber',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: record.isNotEmpty
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface,
                                    )),
                                if (_hasActivity(record))
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _legend(context, Colors.green.shade600, '80–100%'),
                        _legend(context, Colors.lightGreen.shade700, '50–79%'),
                        _legend(context, Colors.orange.shade700, '25–49%'),
                        _legend(context, Theme.of(context).colorScheme.error.withValues(alpha: 0.72), '0–24%'),
                        _legend(context, Theme.of(context).colorScheme.surfaceContainerHighest, 'Sin datos'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Meta de referencia: $goalMinutes min productivos al día',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: selected.isEmpty || !_hasActivity(selected) || isFuture
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Día ${_selected.day}/${_selected.month}/${_selected.year}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          const Text('Todavía no hay actividad guardada para este día.'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Día ${_selected.day}/${_selected.month}/${_selected.year}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Text(_rating(selected),
                                  style: TextStyle(
                                    color: _dayColor(context, selected),
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(_duration(productive),
                              style: Theme.of(context).textTheme.headlineMedium),
                          const Text('Tiempo productivo'),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: goal <= 0 ? 0 : (productive / goal).clamp(0.0, 1.0),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 6),
                          Text('${(goal <= 0 ? 0 : productive * 100 / goal).round()}% de la meta diaria'),
                          const Divider(height: 24),
                          _detail('Tiempo ganado', _duration(earned)),
                          _detail('Tiempo en distracciones', _duration(distracting)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text('El historial se conserva en este dispositivo. Los días sin datos no se califican.',
                style: Theme.of(context).textTheme.bodySmall),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.controller.busy ? null : widget.controller.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, Map<String, dynamic>> _recordsByDate(
      Map<String, dynamic> data) {
    final records = <String, Map<String, dynamic>>{};
    final history = (data['history'] as List?) ?? const [];
    for (final item in history) {
      if (item is Map && item['dayKey'] is String) {
        records[item['dayKey'] as String] = Map<String, dynamic>.from(item);
      }
    }
    final todayKey = data['dayKey'];
    if (todayKey is String) {
      records[todayKey] = {
        'dayKey': todayKey,
        'productiveSeconds': data['productiveSeconds'] ?? 0,
        'earnedSeconds': data['earnedSeconds'] ?? 0,
        'distractingSeconds': data['distractingSeconds'] ?? 0,
        'goalSeconds': data['productivityGoalSeconds'] ?? 3600,
      };
    }
    return records;
  }

  int _productive(Map<String, dynamic>? record) =>
      (record?['productiveSeconds'] as num?)?.toInt() ?? 0;

  int _goal(Map<String, dynamic>? record) =>
      (record?['goalSeconds'] as num?)?.toInt() ?? 3600;

  int _currentStreak(Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    final todayRecord = records[_key(cursor)];
    // Today's streak remains alive while the day is still in progress.
    if (_productive(todayRecord) < _goal(todayRecord)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    for (var i = 0; i < 730; i++) {
      final record = records[_key(cursor)];
      if (record == null || _productive(record) < _goal(record)) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  MapEntry<String, int>? _bestDay(Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    if (records.isEmpty) return null;
    final best = records.entries
        .map((entry) => MapEntry(entry.key, _productive(entry.value)))
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return best.isEmpty ? null : best.first;
  }

  Widget _weeklyOverview(BuildContext context, Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => monday.add(Duration(days: index)));
    final weeklySeconds = days.fold<int>(
        0, (sum, day) => sum + _productive(records[_key(day)]));
    final completed = days
        .where((day) => !day.isAfter(today))
        .where((day) {
          final record = records[_key(day)];
          return record != null && _productive(record) >= _goal(record);
        }).length;
    final streak = _currentStreak(data);
    final best = _bestDay(data);
    final dateLabel = '${monday.day}/${monday.month} – ${days.last.day}/${days.last.month}';
    final goal = (data['productivityGoalSeconds'] as num?)?.toInt() ?? 3600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Esta semana',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text(dateLabel,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statMetric(context, _duration(weeklySeconds),
                      'Tiempo productivo'),
                ),
                Expanded(
                  child: _statMetric(context, '$completed/7',
                      'Días con meta'),
                ),
                Expanded(
                  child: _statMetric(context, '$streak',
                      'Racha actual'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((day) {
                  final record = records[_key(day)];
                  final seconds = _productive(record);
                  final progress = goal <= 0
                      ? 0.0
                      : (seconds / goal).clamp(0.0, 1.0);
                  final future = day.isAfter(today);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(seconds == 0 ? '' : '${(seconds / 60).round()}',
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 18,
                                height: future ? 2 : 8 + 42 * progress,
                                decoration: BoxDecoration(
                                  color: future
                                      ? Theme.of(context).colorScheme.outlineVariant
                                      : seconds >= goal
                                          ? Colors.green.shade600
                                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(['L', 'M', 'X', 'J', 'V', 'S', 'D'][day.weekday - 1],
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _statMetric(
                    context,
                    best == null ? '—' : _duration(best.value),
                    'Mejor día',
                    subtitle: best == null
                        ? 'Aún sin registros'
                        : best.key.split('-').reversed.join('/'),
                  ),
                ),
                Expanded(
                  child: _statMetric(context, '$goalMinutesLabel',
                      'Meta diaria'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('La racha cuenta días consecutivos que alcanzan la meta.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String get goalMinutesLabel => '${(60).toString()} min';

  Widget _statMetric(BuildContext context, String value, String label,
      {String? subtitle}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          if (subtitle != null)
            Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
        ],
      );

  Widget _legend(BuildContext context, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))],
        ),
      );
}
