import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'session_controller.dart';

class EarnTimePlatform {
  static const channel = MethodChannel('focusfeed/earn_time');
  static const permissions = MethodChannel('focusfeed/permissions');

  Future<Map<String, dynamic>> invoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      method,
      arguments,
    );
    return result ?? <String, dynamic>{};
  }

  Future<void> requestUsageAccess() =>
      permissions.invokeMethod<void>('request', {'permission': 'usage'});

  Future<void> requestOverlayAccess() =>
      permissions.invokeMethod<void>('request', {'permission': 'overlay'});
}

class EarnTimeController extends ChangeNotifier {
  EarnTimeController({EarnTimePlatform? platform})
    : _platform = platform ?? EarnTimePlatform();

  final EarnTimePlatform _platform;
  Map<String, dynamic> data = {};
  bool busy = false;
  String? error;
  bool _disposed = false;

  bool get monitorRunning => data['monitorRunning'] == true;
  bool get usagePermission => data['usagePermission'] == true;
  bool get overlayPermission => data['overlayPermission'] == true;
  int value(String key, [int fallback = 0]) =>
      (data[key] as num?)?.toInt() ?? fallback;
  Set<String> packages(String key) =>
      Set<String>.from((data[key] as List?) ?? const <String>[]);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      data = await _platform.invoke('status');
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'No se pudo consultar Earn Your Time.';
    } catch (_) {
      error = 'No se pudo consultar Earn Your Time.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> configure({
    required Set<String> productive,
    required Set<String> distracting,
    required int dailyAllowanceSeconds,
    required int rewardNumerator,
    required int rewardDenominator,
  }) async {
    if (busy || _disposed) return;
    if (productive.intersection(distracting).isNotEmpty) {
      error = 'Una aplicación no puede estar en ambas categorías.';
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      await _platform.invoke('configure', {
        'productivePackages': productive.toList(),
        'distractingPackages': distracting.toList(),
        'dailyAllowanceSeconds': dailyAllowanceSeconds,
        'rewardNumerator': rewardNumerator,
        'rewardDenominator': rewardDenominator,
      });
      data = await _platform.invoke('status');
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'No se pudo guardar la configuración.';
    } catch (_) {
      error = 'No se pudo guardar la configuración.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> start() async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      await _platform.invoke('startMonitor');
      data = await _platform.invoke('status');
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'No se pudo iniciar el seguimiento.';
    } catch (_) {
      error = 'No se pudo iniciar el seguimiento.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> stop() async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      await _platform.invoke('stopMonitor');
      data = await _platform.invoke('status');
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'No se pudo detener el seguimiento.';
    } catch (_) {
      error = 'No se pudo detener el seguimiento.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> requestUsageAccess() async {
    try {
      await _platform.requestUsageAccess();
    } on PlatformException catch (e) {
      error = e.message ?? 'No se pudieron abrir los permisos.';
      _notify();
    } catch (_) {
      error = 'No se pudieron abrir los permisos.';
      _notify();
    }
  }

  Future<void> requestOverlayAccess() async {
    try {
      await _platform.requestOverlayAccess();
    } on PlatformException catch (e) {
      error = e.message ?? 'No se pudo abrir el permiso de superposición.';
      _notify();
    } catch (_) {
      error = 'No se pudo abrir el permiso de superposición.';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

enum EarnAppCategory { ignored, productive, distracting }

class EarnTimeView extends StatefulWidget {
  const EarnTimeView({
    super.key,
    required this.apps,
    required this.controller,
  });

  final List<InstalledApp> apps;
  final EarnTimeController controller;

  @override
  State<EarnTimeView> createState() => _EarnTimeViewState();
}

class _EarnTimeViewState extends State<EarnTimeView> with WidgetsBindingObserver {
  final _allowanceInput = TextEditingController();
  final _conversionInput = TextEditingController();
  String? _settingsError;
  late Set<String> _productive;
  late Set<String> _distracting;
  late int _allowance;
  late int _numerator;
  late int _denominator;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refresh();
    }
  }

  void _changed() {
    if (!mounted) return;
    final data = widget.controller.data;
    if (!_loaded && data.isNotEmpty) {
      _productive = widget.controller.packages('productivePackages');
      _distracting = widget.controller.packages('distractingPackages');
      _allowance = widget.controller.value('dailyAllowanceSeconds', 1800);
      _numerator = widget.controller.value('rewardNumerator', 1);
      _denominator = widget.controller.value('rewardDenominator', 1);
      _syncSettingsInputs();
      _loaded = true;
    }
    setState(() {});
  }

  Future<void> _load() async {
    await widget.controller.refresh();
    if (!mounted) return;
    final data = widget.controller.data;
    _productive = widget.controller.packages('productivePackages');
    _distracting = widget.controller.packages('distractingPackages');
    _allowance = widget.controller.value('dailyAllowanceSeconds', 1800);
    _numerator = widget.controller.value('rewardNumerator', 1);
    _denominator = widget.controller.value('rewardDenominator', 1);
    _syncSettingsInputs();
    _loaded = data.isNotEmpty;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    _allowanceInput.dispose();
    _conversionInput.dispose();
    super.dispose();
  }

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    if (minutes > 0) return '$minutes min';
    return '$secs s';
  }

  void _syncSettingsInputs() {
    _allowanceInput.text = (_allowance ~/ 60).toString();
    final conversion = _numerator / _denominator;
    var formatted = conversion.toStringAsFixed(2);
    while (formatted.contains('.') && formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    _conversionInput.text = formatted;
  }

  void _commitNumericSettings() {
    final minutes = int.tryParse(_allowanceInput.text.trim());
    final conversion = double.tryParse(_conversionInput.text.trim().replaceAll(',', '.'));
    if (minutes == null || minutes < 1 || minutes > 1440 ||
        conversion == null || !conversion.isFinite || conversion < 0.01 || conversion > 100 ||
        ((conversion * 100) - (conversion * 100).round()).abs() > 0.000001) {
      setState(() => _settingsError = 'Usa un saldo entre 1 y 1440 minutos y una conversión entre 0,01 y 100 minutos.');
      return;
    }
    // Store the custom decimal as an exact fraction with up to two decimal places.
    var numerator = (conversion * 100).round();
    var denominator = 100;
    var a = numerator;
    var b = denominator;
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    numerator ~/= a;
    denominator ~/= a;
    setState(() {
      _allowance = minutes * 60;
      _numerator = numerator;
      _denominator = denominator;
      _settingsError = null;
    });
    _save();
  }

  Future<void> _save() => widget.controller.configure(
    productive: _productive,
    distracting: _distracting,
    dailyAllowanceSeconds: _allowance,
    rewardNumerator: _numerator,
    rewardDenominator: _denominator,
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    if (!_loaded) {
      return Center(
        child: c.error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.error!),
                    TextButton(onPressed: _load, child: const Text('Reintentar')),
                  ],
                ),
              ),
      );
    }
    final remaining = c.value('remainingSeconds');
    final productiveSeconds = c.value('productiveSeconds');
    final earnedSeconds = c.value('earnedSeconds');
    final spentSeconds = c.value('distractingSeconds');
    final usagePermission = c.usagePermission;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text('Tu tiempo, tus reglas', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Usa aplicaciones productivas para ganar tiempo y gástalo en las distractoras.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo disponible', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(_duration(remaining), style: theme.textTheme.displaySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _metric('Productivo', productiveSeconds),
                    _metric('Ganado', earnedSeconds),
                    _metric('Gastado', spentSeconds),
                  ],
                ),
                const SizedBox(height: 8),
                Text('El saldo base y los contadores se reinician cada día.'),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(
              c.monitorRunning ? Icons.track_changes : Icons.pause_circle_outline,
              color: c.monitorRunning ? Colors.green : null,
            ),
            title: Text(c.monitorRunning ? 'Seguimiento activo' : 'Seguimiento detenido'),
            subtitle: Text(
              usagePermission
                  ? (c.overlayPermission
                      ? 'Seguimiento y bloqueo automático disponibles.'
                      : 'Falta el permiso para mostrar la pantalla de bloqueo sobre otras apps.')
                  : 'Necesitas permitir el acceso al uso de aplicaciones.',
            ),
            trailing: c.monitorRunning
                ? OutlinedButton(
                    onPressed: c.busy ? null : c.stop,
                    child: const Text('Detener'),
                  )
                : FilledButton(
                    onPressed: c.busy
                        ? null
                        : !usagePermission
                            ? c.requestUsageAccess
                            : !c.overlayPermission
                                ? c.requestOverlayAccess
                                : c.start,
                    child: Text(
                      !usagePermission
                          ? 'Permitir acceso'
                          : !c.overlayPermission
                              ? 'Activar bloqueo'
                              : 'Iniciar',
                    ),
                  ),
          ),
        ),
        if (c.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(c.error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (c.busy) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Bloqueo automático'),
            subtitle: const Text('Al llegar a cero, las apps distractoras mostrarán una pantalla encima de ellas. Requiere «Mostrar sobre otras aplicaciones». Es una barrera visual, no un bloqueo imposible de evadir en Android.'),
          ),
        ),
        const SizedBox(height: 12),
        Text('Configuración diaria', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Este es el saldo con el que comienzas cada día; el tiempo productivo se suma y el distractor se descuenta.'),
        const SizedBox(height: 8),
        TextField(
          controller: _allowanceInput,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Saldo base diario (minutos)',
            helperText: 'Puedes escribir cualquier valor entre 1 y 1440.',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitNumericSettings(),
        ),
        const SizedBox(height: 12),
        Text('Conversión de tiempo', style: theme.textTheme.titleMedium),
        const Text('Indica cuánto tiempo para distracciones ganas por cada minuto que usas una aplicación productiva.'),
        const SizedBox(height: 8),
        TextField(
          controller: _conversionInput,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Minutos de distracción por 1 minuto productivo',
            helperText: 'Ejemplos: 1 = 1 min, 2 = 2 min, 0,5 = 30 s. Admite hasta 2 decimales.',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitNumericSettings(),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: c.busy ? null : _commitNumericSettings,
          child: const Text('Guardar configuración'),
        ),
        if (_settingsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_settingsError!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }

  Widget _metric(String label, int seconds) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(_duration(seconds), style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}


/// Pestaña independiente para clasificar las aplicaciones instaladas.
class EarnTimeApplicationsView extends StatefulWidget {
  const EarnTimeApplicationsView({super.key, required this.apps, required this.controller});
  final List<InstalledApp> apps;
  final EarnTimeController controller;

  @override
  State<EarnTimeApplicationsView> createState() => _EarnTimeApplicationsViewState();
}

class _EarnTimeApplicationsViewState extends State<EarnTimeApplicationsView> {
  final _search = TextEditingController();
  EarnAppCategory? _filter;
  Set<String> _productive = {};
  Set<String> _distracting = {};
  int _allowance = 1800;
  int _numerator = 1;
  int _denominator = 1;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await widget.controller.refresh();
    if (!mounted) return;
    final c = widget.controller;
    _productive = c.packages('productivePackages');
    _distracting = c.packages('distractingPackages');
    _allowance = c.value('dailyAllowanceSeconds', 1800);
    _numerator = c.value('rewardNumerator', 1);
    _denominator = c.value('rewardDenominator', 1);
    _loaded = true;
    setState(() {});
  }

  Future<void> _setCategory(String package, EarnAppCategory category) async {
    if (widget.controller.busy || widget.controller.monitorRunning) return;
    final productive = Set<String>.from(_productive)..remove(package);
    final distracting = Set<String>.from(_distracting)..remove(package);
    if (category == EarnAppCategory.productive) productive.add(package);
    if (category == EarnAppCategory.distracting) distracting.add(package);
    setState(() {
      _productive = productive;
      _distracting = distracting;
    });
    await widget.controller.configure(
      productive: productive,
      distracting: distracting,
      dailyAllowanceSeconds: _allowance,
      rewardNumerator: _numerator,
      rewardDenominator: _denominator,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    if (!_loaded) {
      return Center(child: c.error == null
          ? const CircularProgressIndicator()
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(24), child: Text(c.error!)),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ]));
    }
    final query = _search.text.trim().toLowerCase();
    final apps = widget.apps.where((app) {
      final matchesQuery = app.label.toLowerCase().contains(query) || app.package.toLowerCase().contains(query);
      final category = _productive.contains(app.package)
          ? EarnAppCategory.productive
          : _distracting.contains(app.package)
              ? EarnAppCategory.distracting
              : EarnAppCategory.ignored;
      return matchesQuery && (_filter == null || category == _filter);
    }).toList()..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    EarnAppCategory categoryOf(InstalledApp app) => _productive.contains(app.package)
        ? EarnAppCategory.productive
        : _distracting.contains(app.package)
            ? EarnAppCategory.distracting
            : EarnAppCategory.ignored;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text('Tus aplicaciones', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Decide qué aplicaciones te ayudan a ganar tiempo y cuáles consumen tu saldo.'),
        const SizedBox(height: 16),
        if (c.monitorRunning)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Detén el seguimiento para editar categorías'),
              subtitle: Text('Así evitamos cambios de clasificación a mitad del conteo.'),
            ),
          ),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar aplicación',
            hintText: 'Nombre de la app',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(
              tooltip: 'Borrar búsqueda',
              onPressed: () { _search.clear(); setState(() {}); },
              icon: const Icon(Icons.close),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _categoryFilter('Todas', null),
            const SizedBox(width: 8),
            _categoryFilter('Productivas', EarnAppCategory.productive),
            const SizedBox(width: 8),
            _categoryFilter('Distractoras', EarnAppCategory.distracting),
            const SizedBox(width: 8),
            _categoryFilter('Ignoradas', EarnAppCategory.ignored),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _countChip('Productivas', _productive.length, theme.colorScheme.primary),
          const SizedBox(width: 8),
          _countChip('Distractoras', _distracting.length, theme.colorScheme.error),
        ]),
        const SizedBox(height: 8),
        if (apps.isEmpty)
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Icon(Icons.search_off, size: 32),
              const SizedBox(height: 8),
              Text(query.isEmpty ? 'No hay aplicaciones en esta categoría.' : 'No se encontraron aplicaciones.'),
            ]),
          ))
        else
          ...apps.map((app) {
            final category = categoryOf(app);
            final enabled = !c.busy && !c.monitorRunning;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                minVerticalPadding: 10,
                leading: app.icon == null
                    ? const CircleAvatar(child: Icon(Icons.apps))
                    : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(app.icon!, width: 42, height: 42)),
                title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(switch (category) {
                  EarnAppCategory.productive => 'Productiva · genera saldo',
                  EarnAppCategory.distracting => 'Distractora · consume saldo',
                  EarnAppCategory.ignored => 'Ignorada · no se cuenta',
                }),
                trailing: PopupMenuButton<EarnAppCategory>(
                  enabled: enabled,
                  tooltip: 'Cambiar categoría de ${app.label}',
                  initialValue: category,
                  onSelected: (value) => _setCategory(app.package, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: EarnAppCategory.productive, child: Text('Productiva')),
                    PopupMenuItem(value: EarnAppCategory.distracting, child: Text('Distractora')),
                    PopupMenuItem(value: EarnAppCategory.ignored, child: Text('Ignorar')),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: c.busy ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar lista de aplicaciones'),
        ),
      ],
    );
  }

  Widget _categoryFilter(String label, EarnAppCategory? value) => FilterChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  Widget _countChip(String label, int count, Color color) => Chip(
    avatar: CircleAvatar(radius: 10, backgroundColor: color, child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white))),
    label: Text(label),
  );
}

/// Resumen de lo que ha ocurrido hoy en Earn Your Time.
class EarnTimeStatsView extends StatelessWidget {
  const EarnTimeStatsView({super.key, required this.controller});
  final EarnTimeController controller;

  String _duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h} h ${m.toString().padLeft(2, '0')} min';
    if (m > 0) return '${m} min';
    return '${s} s';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final productive = c.value('productiveSeconds');
        final earned = c.value('earnedSeconds');
        final spent = c.value('distractingSeconds');
        final remaining = c.value('remainingSeconds');
        final total = productive + spent;
        final productivity = total == 0 ? 0.0 : productive / total;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Tu actividad de hoy', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Un resumen del tiempo registrado por Earn Your Time.'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Saldo disponible'),
                  const SizedBox(height: 4),
                  Text(_duration(remaining), style: theme.textTheme.displaySmall),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: productivity.clamp(0.0, 1.0), minHeight: 8),
                  const SizedBox(height: 8),
                  Text('${(productivity * 100).round()}% del tiempo registrado fue productivo'),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            _statCard(context, 'Tiempo productivo', _duration(productive), Icons.work_outline),
            _statCard(context, 'Tiempo ganado', _duration(earned), Icons.add_circle_outline),
            _statCard(context, 'Tiempo gastado en distracciones', _duration(spent), Icons.hourglass_bottom),
            const SizedBox(height: 12),
            Card(child: ListTile(
              leading: Icon(c.monitorRunning ? Icons.track_changes : Icons.pause_circle_outline,
                  color: c.monitorRunning ? Colors.green : null),
              title: Text(c.monitorRunning ? 'Seguimiento activo' : 'Seguimiento detenido'),
              subtitle: Text(c.monitorRunning ? 'Los contadores se actualizan automáticamente.' : 'Inicia el seguimiento para registrar tu actividad.'),
            )),
            const SizedBox(height: 8),
            Text('Los datos mostrados corresponden al día actual. El historial de sesiones de Foco está en la pestaña Foco/Histórico.', style: theme.textTheme.bodySmall),
            if (c.error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c.error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: c.busy ? null : c.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar estadísticas'),
            )),
          ],
        );
      },
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
