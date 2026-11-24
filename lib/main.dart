import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'focus_strings.dart';
import 'earn_time_view.dart';
import 'earn_time_calendar.dart';

import 'history_view.dart';
import 'permissions.dart';
import 'rewards.dart';
import 'session_controller.dart';
import 'settings.dart';

ThemeData _buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF28A9C7),
    brightness: brightness,
    surface: brightness == Brightness.dark
        ? const Color(0xFF102126)
        : const Color(0xFFEAF7FA),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: brightness == Brightness.dark
          ? const Color(0xFF1A3036)
          : const Color(0xFFF9FEFF),
      elevation: brightness == Brightness.dark ? 1 : 2,
      shadowColor: const Color(0xFF4AAFC3).withValues(alpha: 0.16),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? const Color(0xFF203941)
          : const Color(0xFFDFF1F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF142A31)
          : const Color(0xFFF4FCFE),
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      )),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      indicator: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

void main() => runApp(const FocusFeedApp());

class FocusFeedApp extends StatefulWidget {
  const FocusFeedApp({super.key, this.now, this.controller, this.settings});

  final DateTime Function()? now;
  final SessionController? controller;
  final SettingsController? settings;

  @override
  State<FocusFeedApp> createState() => _FocusFeedAppState();
}

class _FocusFeedAppState extends State<FocusFeedApp> {
  late final SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? SettingsController();
    unawaited(_settings.load());
  }

  @override
  void dispose() {
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _settings,
    builder: (context, _) => MaterialApp(
      title: 'Earn Your Time',
      locale: _settings.language.locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: const [
        FocusStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(Brightness.light),
      darkTheme: _buildAppTheme(Brightness.dark),
      themeMode: _settings.mode.themeMode,
      home: FocusScreen(
        now: widget.now,
        controller: widget.controller,
        settings: _settings,
      ),
    ),
  );
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({
    super.key,
    this.now,
    this.controller,
    required this.settings,
  });

  final DateTime Function()? now;
  final SessionController? controller;
  final SettingsController settings;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  late final SessionController _controller;
  late final EarnTimeController _earnTime;
  int? _rewardChoice;
  String _search = '';
  int _index = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? SessionController(now: widget.now);
    _earnTime = EarnTimeController();
    _controller.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _controller.setForeground(resumed);
    if (resumed) {
      unawaited(_controller.refresh());
      unawaited(_earnTime.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _earnTime.dispose();
    _searchController.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  String _time(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> _stop() async {
    final phase = _controller.state?.phase;
    if (phase == null || phase == 'idle') return;
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Parar a sessão?')),
        content: Text(
          strings.text(
            'O tempo restante será descartado. Uma recompensa já usada não é devolvida.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('Continuar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('Parar')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final c = _controller;
    final s = c.state;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('FocusFeed')),
        body: Center(
          child: c.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(strings.text(c.error!)),
                    ),
                    TextButton(
                      onPressed: c.busy ? null : c.initialize,
                      child: Text(strings.text('Tentar carregar novamente')),
                    ),
                  ],
                ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.hourglass_bottom_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Earn Your Time'),
                Text(
                  [
                    'Tu espacio de productividad',
                    'Gestiona tus aplicaciones',
                    strings.text('Foco'),
                    'Tu progreso',
                    strings.text('Ajustes'),
                  ][_index],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (_index) {
          0 => EarnTimeView(apps: c.apps, controller: _earnTime),
          1 => EarnTimeApplicationsView(apps: c.apps, controller: _earnTime),
          2 => _focusTab(context, c, s),
          3 => DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                        tabs: const [
                          Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Calendario'),
                          Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: 'Récords'),
                          Tab(icon: Icon(Icons.workspace_premium_outlined, size: 18), text: 'Logros'),
                          Tab(icon: Icon(Icons.timer_outlined, size: 18), text: 'Foco'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        EarnTimeCalendarView(controller: _earnTime, section: EarnCalendarSection.calendar),
                        EarnTimeCalendarView(controller: _earnTime, section: EarnCalendarSection.records),
                        EarnTimeCalendarView(controller: _earnTime, section: EarnCalendarSection.achievements),
                        HistoryView(state: s, now: c.now),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _ => SettingsView(controller: widget.settings, notificationsEnabled: s.notificationsEnabled, onConfigureNotifications: c.busy ? null : c.notifications),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined),
            selectedIcon: const Icon(Icons.timer),
            label: strings.text('Foco'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: strings.text('Ajustes'),
          ),
        ],
      ),
    );
  }

  Widget _focusTab(BuildContext context, SessionController c, SessionView s) {
    final strings = context.strings;
    final cap = s.balance > 86400 ? 86400 : s.balance;
    final amounts = <int>{
      if (cap >= 60) 60,
      if (cap >= 300) 300,
      if (cap >= 600) 600,
      if (cap >= 900) 900,
      if (cap >= 1800) 1800,
      if (cap > 0) cap,
    }.toList()..sort();
    final chosen = amounts.contains(_rewardChoice)
        ? _rewardChoice!
        : amounts.isEmpty
        ? 0
        : amounts.last;
    final idle = s.phase == 'idle';
    final catalog = c.apps
        .where((app) => app.label.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final status = switch (s.phase) {
      'reward' => strings.text('Recompensa ativa — redes liberadas'),
      'paused' => strings.text('Foco pausado — bloqueio desativado'),
      'focus' || 'locked' =>
        s.blocking
            ? strings.text('Bloqueio ativo')
            : strings.text(
                'Bloqueio indisponível — verifique permissões e serviço',
              ),
      _ => strings.text('Pronto para focar'),
    };
    final progress = (1 - s.focusRemaining / s.focusTotal).clamp(0.0, 1.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
          children: [
            Text(
              strings.text('Uma sessão de cada vez.'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              strings.text('Foco concluído hoje: {0}', [
                rewardLabel(c.focusToday),
              ]),
            ),
            Text(
              strings.text('Recompensa ao concluir: {0}', [
                rewardLabel(
                  RewardWallet.earnedSeconds(Duration(seconds: s.focusTotal)),
                ),
              ]),
            ),
            Text(status, key: const Key('sessionStatus')),
            if (s.notice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(strings.text(s.notice)),
              ),
            if (c.error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        strings.text(c.error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: c.busy ? null : c.refresh,
                        child: Text(strings.text('Verificar novamente')),
                      ),
                    ],
                  ),
                ),
              ),
            if (c.busy) const LinearProgressIndicator(),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              key: ValueKey(s.focusTotal),
              initialValue: s.focusTotal,
              decoration: InputDecoration(
                labelText: strings.text('Duração do foco'),
                border: const OutlineInputBorder(),
              ),
              items: [60, 300, 900, 1500, 2700, 3600]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text(
                        strings.text(
                          seconds == 60 ? '{0} minuto' : '{0} minutos',
                          [seconds ~/ 60],
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: idle && !c.busy
                  ? (value) {
                      if (value != null) unawaited(c.duration(value));
                    }
                  : null,
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 244,
                height: 244,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                padding: const EdgeInsets.all(17),
                child: Semantics(
                  label: strings.text('Progresso do foco'),
                  value: '${(progress * 100).round()}%',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.self_improvement_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 25),
                          const SizedBox(height: 8),
                          Semantics(
                            label: strings.text('Tempo restante de foco'),
                            value: _time(s.focusRemaining),
                            child: Text(
                              _time(s.focusRemaining),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${(progress * 100).round()}% completado',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: !c.busy && !['focus', 'reward'].contains(s.phase)
                      ? c.start
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    s.phase == 'paused' ||
                            (s.phase == 'locked' && s.focusRemaining > 0)
                        ? strings.text('Retomar Foco')
                        : strings.text('Iniciar Foco'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: !c.busy && s.phase == 'focus' ? c.pause : null,
                  icon: const Icon(Icons.pause),
                  label: Text(strings.text('Pausar')),
                ),
                OutlinedButton.icon(
                  onPressed: !c.busy && !idle ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: Text(strings.text('Parar')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('Saldo: {0}', [rewardLabel(s.balance)]),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      strings.text(
                        'Ganhe 20% do tempo de cada foco concluído.',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.text(
                        'Liberar redes pausa um foco ativo. Sem foco ativo, os apps escolhidos ficam bloqueados até Parar.',
                      ),
                      style: TextStyle(fontSize: 12),
                    ),
                    if (s.phase == 'reward')
                      Text(
                        strings.text('Recompensa: {0}', [
                          _time(s.rewardRemaining),
                        ]),
                        style: Theme.of(context).textTheme.headlineMedium,
                      )
                    else ...[
                      if (s.balance == 0)
                        Text(
                          strings.text(
                            'Sem saldo. Conclua um foco para liberar as redes.',
                          ),
                        ),
                      if (amounts.isNotEmpty)
                        DropdownButton<int>(
                          key: const Key('rewardAmount'),
                          value: chosen,
                          items: amounts
                              .map(
                                (seconds) => DropdownMenuItem(
                                  value: seconds,
                                  child: Text(rewardLabel(seconds)),
                                ),
                              )
                              .toList(),
                          onChanged: c.busy
                              ? null
                              : (value) =>
                                    setState(() => _rewardChoice = value),
                        ),
                      FilledButton(
                        onPressed: chosen > 0 && !c.busy
                            ? () => c.reward(chosen)
                            : null,
                        child: Text(
                          strings.text('Liberar Redes por {0}', [
                            rewardLabel(chosen),
                          ]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              strings.text('Apps selecionados para bloqueio'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (s.platform == 'ios') ...[
              Text(
                strings.text('{0} itens selecionados pelo Screen Time', [
                  s.selectionCount,
                ]),
              ),
              OutlinedButton(
                onPressed: idle && !c.busy ? c.pickApps : null,
                child: Text(strings.text('Selecionar apps no iOS')),
              ),
            ] else ...[
              TextField(
                key: const Key('appSearch'),
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: strings.text('Buscar apps instalados'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              if (catalog.isEmpty)
                Text(
                  strings.text(
                    'Nenhum app encontrado. Atualize após instalar um app.',
                  ),
                ),
              ...catalog.map(
                (app) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: app.icon != null
                      ? Image.memory(app.icon!, width: 36, height: 36)
                      : const Icon(Icons.apps),
                  title: Text(app.label),
                  value: s.apps[app.package] ?? false,
                  onChanged: idle && !c.busy
                      ? (value) => c.select(app.package, value ?? false)
                      : null,
                ),
              ),
              TextButton(
                onPressed: idle && !c.busy ? c.initialize : null,
                child: Text(strings.text('Atualizar apps instalados')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
