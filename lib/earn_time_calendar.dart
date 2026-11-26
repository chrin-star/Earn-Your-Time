import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'earn_time_view.dart';

enum EarnCalendarSection { calendar, records, achievements }

/// Monthly productivity calendar backed by the daily snapshots stored natively.
class EarnTimeCalendarView extends StatefulWidget {
  const EarnTimeCalendarView({super.key, required this.controller, this.section = EarnCalendarSection.calendar});
  final EarnTimeController controller;
  final EarnCalendarSection section;

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
    widget.controller.loadAppUsage();
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.insights_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.section == EarnCalendarSection.calendar ? 'Tu progreso' : widget.section == EarnCalendarSection.records ? 'Récords personales' : 'Sistema de logros', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
                    const SizedBox(height: 3),
                    Text(widget.section == EarnCalendarSection.calendar ? 'Calendario de productividad' : widget.section == EarnCalendarSection.records ? 'Tus mejores resultados' : 'Insignias que puedes desbloquear',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.section == EarnCalendarSection.records) ...[
              _personalRecords(context, data),
            ] else if (widget.section == EarnCalendarSection.achievements) ...[
              _achievements(context, data),
            ] else ...[
              _weeklyOverview(context, data),
              const SizedBox(height: 12),
              _monthlyOverview(context, data),
              const SizedBox(height: 12),
              _appUsageOverview(context),
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
                onPressed: widget.controller.busy ? null : () async {
                  await widget.controller.refresh();
                  await widget.controller.loadAppUsage();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ),
            ],
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



  Widget _achievements(BuildContext context, Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    final totalProductive = records.values.fold<int>(
        0, (sum, record) => sum + _productive(record));
    final activeDays = records.values
        .where((record) =>
            _productive(record) > 0 ||
            ((record['distractingSeconds'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final longest = _longestStreak(data);
    final completedDays = records.values
        .where((record) =>
            _productive(record) > 0 &&
            _productive(record) >= _goal(record))
        .length;
    final achievements = <({String title, String description, IconData icon, bool unlocked})>[
      (title: 'Primer paso', description: 'Registra tu primer día', icon: Icons.flag_rounded, unlocked: activeDays >= 1),
      (title: 'Una hora de enfoque', description: 'Acumula 1 hora productiva', icon: Icons.timer_rounded, unlocked: totalProductive >= 3600),
      (title: 'Diez horas', description: 'Acumula 10 horas productivas', icon: Icons.bolt_rounded, unlocked: totalProductive >= 36000),
      (title: 'Cien horas', description: 'Acumula 100 horas productivas', icon: Icons.workspace_premium_rounded, unlocked: totalProductive >= 360000),
      (title: 'Meta cumplida', description: 'Alcanza tu meta diaria', icon: Icons.check_circle_rounded, unlocked: completedDays >= 1),
      (title: 'Constancia', description: 'Cumple la meta 3 días seguidos', icon: Icons.local_fire_department_rounded, unlocked: longest >= 3),
      (title: 'Una semana fuerte', description: 'Cumple la meta 7 días seguidos', icon: Icons.military_tech_rounded, unlocked: longest >= 7),
      (title: 'Cinco días activos', description: 'Usa Earn Your Time 5 días', icon: Icons.calendar_month_rounded, unlocked: activeDays >= 5),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Sistema de logros',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text('${achievements.where((item) => item.unlocked).length}/${achievements.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Insignias que se desbloquean automáticamente al alcanzar objetivos.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: achievements.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.42,
              ),
              itemBuilder: (context, index) {
                final item = achievements[index];
                final color = item.unlocked
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.unlocked
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.unlocked
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.unlocked ? item.icon : Icons.lock_outline_rounded,
                          color: color, size: 24),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: color)),
                            const SizedBox(height: 3),
                            Text(item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _appUsageOverview(BuildContext context) {
    final controller = widget.controller;
    final items = controller.appUsage;
    final productive = items
        .where((item) => item['category'] == 'productive')
        .fold<int>(0, (sum, item) => sum + ((item['seconds'] as num?)?.toInt() ?? 0));
    final distracting = items
        .where((item) => item['category'] == 'distracting')
        .fold<int>(0, (sum, item) => sum + ((item['seconds'] as num?)?.toInt() ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Historial de aplicaciones',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Actualizar historial',
                  onPressed: controller.appUsageLoading ? null : controller.loadAppUsage,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text('Uso registrado por Android durante los últimos 7 días.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (controller.appUsageLoading)
              const LinearProgressIndicator()
            else if (controller.appUsageError != null)
              Text(controller.appUsageError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error))
            else if (items.isEmpty)
              Text(
                'Todavía no hay uso disponible para las aplicaciones que clasificaste. Comprueba que el permiso de acceso al uso esté activado.',
                style: Theme.of(context).textTheme.bodyMedium)
            else ...[
              Row(
                children: [
                  Expanded(child: _statMetric(context, _duration(productive), 'Productivas')),
                  Expanded(child: _statMetric(context, _duration(distracting), 'Distractoras')),
                ],
              ),
              const Divider(height: 22),
              ...items.take(8).map((item) {
                final isProductive = item['category'] == 'productive';
                final color = isProductive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error;
                final seconds = (item['seconds'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: item['icon'] is Uint8List
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  item['icon'] as Uint8List,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                      Icons.apps_rounded, size: 18, color: color),
                                ),
                              )
                            : Icon(Icons.apps_rounded, size: 18, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['label']?.toString() ?? 'Aplicación',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700)),
                            Text(isProductive ? 'Productiva' : 'Distractora',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
                          ],
                        ),
                      ),
                      Text(_duration(seconds),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }),
              if (items.length > 8)
                Text('Mostrando las 8 aplicaciones con más uso.',
                    style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthlyOverview(BuildContext context, Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    final prefix = _key(DateTime(_month.year, _month.month, 1)).substring(0, 7);
    final monthRecords = records.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value)
        .toList();
    final productive = monthRecords.fold<int>(
        0, (sum, record) => sum + _productive(record));
    final distracting = monthRecords.fold<int>(
        0,
        (sum, record) =>
            sum + ((record['distractingSeconds'] as num?)?.toInt() ?? 0));
    final earned = monthRecords.fold<int>(
        0,
        (sum, record) =>
            sum + ((record['earnedSeconds'] as num?)?.toInt() ?? 0));
    final activeDays = monthRecords
        .where((record) =>
            _productive(record) > 0 ||
            ((record['distractingSeconds'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final completedDays = monthRecords
        .where((record) =>
            _productive(record) > 0 &&
            _productive(record) >= _goal(record))
        .length;
    final tracked = productive + distracting;
    final productiveShare = tracked == 0 ? 0.0 : productive / tracked;
    final average = activeDays == 0 ? 0 : productive ~/ activeDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_month_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Resumen del mes',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text('${_month.month}/${_month.year}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statMetric(context, _duration(productive),
                      'Tiempo productivo'),
                ),
                Expanded(
                  child: _statMetric(context, '$activeDays',
                      'Días con actividad'),
                ),
                Expanded(
                  child: _statMetric(context, '$completedDays',
                      'Metas alcanzadas'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: productiveShare,
                minHeight: 9,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(productiveShare * 100).round()}% del tiempo registrado fue productivo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 22),
            _detail('Promedio por día activo', _duration(average)),
            _detail('Tiempo ganado', _duration(earned)),
            _detail('Tiempo en distracciones', _duration(distracting)),
            if (activeDays == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Aún no hay actividad registrada en este mes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _longestStreak(Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    final entries = records.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    var longest = 0;
    var current = 0;
    DateTime? previous;
    for (final entry in entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;
      final productive = _productive(entry.value);
      final reachedGoal = productive > 0 && productive >= _goal(entry.value);
      if (!reachedGoal) {
        current = 0;
        previous = null;
        continue;
      }
      if (previous != null && date.difference(previous).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      previous = date;
    }
    return longest;
  }

  Widget _personalRecords(BuildContext context, Map<String, dynamic> data) {
    final records = _recordsByDate(data);
    final best = _bestDay(data);
    final totalProductive = records.values.fold<int>(
        0, (sum, record) => sum + _productive(record));
    final activeDays = records.values
        .where((record) =>
            _productive(record) > 0 ||
            ((record['distractingSeconds'] as num?)?.toInt() ?? 0) > 0)
        .length;
    final longest = _longestStreak(data);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Tus récords personales',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            Row(
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
                  child: _statMetric(context, '$longest días',
                      'Racha más larga'),
                ),
              ],
            ),
            const Divider(height: 22),
            _detail('Tiempo productivo acumulado',
                _duration(totalProductive)),
            _detail('Días con actividad', '$activeDays'),
            Text(
              'Los récords se calculan únicamente con los días que tienen datos guardados.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
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
                  child: _statMetric(context, _duration(goal),
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
