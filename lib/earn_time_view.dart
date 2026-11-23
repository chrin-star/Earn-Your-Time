import 'package:flutter/foundation.dart';
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

class _EarnTimeViewState extends State<EarnTimeView> {
  final _search = TextEditingController();
  late Set<String> _productive;
  late Set<String> _distracting;
  late int _allowance;
  late int _numerator;
  late int _denominator;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _load();
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
    _loaded = data.isNotEmpty;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours} h ${minutes.toString().padLeft(2, '0')} min';
    if (minutes > 0) return '$minutes min';
    return '$secs s';
  }

  Future<void> _save() => widget.controller.configure(
    productive: _productive,
    distracting: _distracting,
    dailyAllowanceSeconds: _allowance,
    rewardNumerator: _numerator,
    rewardDenominator: _denominator,
  );

  void _setCategory(String package, EarnAppCategory category) {
    setState(() {
      _productive.remove(package);
      _distracting.remove(package);
      if (category == EarnAppCategory.productive) _productive.add(package);
      if (category == EarnAppCategory.distracting) _distracting.add(package);
    });
    _save();
  }

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
    final filtered = widget.apps.where((app) {
      final q = _search.text.toLowerCase();
      return app.label.toLowerCase().contains(q) ||
          app.package.toLowerCase().contains(q);
    }).toList();
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
                  ? 'El registro funciona en segundo plano con una notificación persistente.'
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
                        : usagePermission
                            ? c.start
                            : c.requestUsageAccess,
                    child: Text(usagePermission ? 'Iniciar' : 'Permitir'),
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
            title: const Text('Seguimiento en fase de prueba'),
            subtitle: const Text('Esta versión contabiliza el tiempo de las aplicaciones. El bloqueo automático al llegar a cero todavía no está implementado.'),
          ),
        ),
        const SizedBox(height: 12),
        Text('Configuración diaria', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Este es el saldo con el que comienzas cada día; el tiempo productivo se suma y el distractor se descuenta.'),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _allowance ~/ 60,
          decoration: const InputDecoration(
            labelText: 'Saldo base diario',
            border: OutlineInputBorder(),
          ),
          items: [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]
              .map((minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes minutos'),
                  ))
              .toList(),
          onChanged: c.busy ? null : (value) {
            if (value == null) return;
            setState(() => _allowance = value * 60);
            _save();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: '$_numerator:$_denominator',
          decoration: const InputDecoration(
            labelText: 'Recompensa por tiempo productivo',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '1:1', child: Text('1 min productivo = 1 min de saldo')),
            DropdownMenuItem(value: '1:2', child: Text('2 min productivos = 1 min de saldo')),
            DropdownMenuItem(value: '1:3', child: Text('3 min productivos = 1 min de saldo')),
            DropdownMenuItem(value: '1:4', child: Text('4 min productivos = 1 min de saldo')),
            DropdownMenuItem(value: '2:1', child: Text('1 min productivo = 2 min de saldo')),
          ],
          onChanged: c.busy ? null : (value) {
            if (value == null) return;
            final parts = value.split(':').map(int.parse).toList();
            setState(() { _numerator = parts[0]; _denominator = parts[1]; });
            _save();
          },
        ),
        const SizedBox(height: 20),
        Text('Clasifica tus aplicaciones', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Productivas generan saldo. Distractoras consumen saldo. Las ignoradas no cuentan.'),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Buscar aplicación',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No se encontraron aplicaciones.'),
          ),
        ...filtered.map((app) {
          final category = _productive.contains(app.package)
              ? EarnAppCategory.productive
              : _distracting.contains(app.package)
                  ? EarnAppCategory.distracting
                  : EarnAppCategory.ignored;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: app.icon == null
                ? const Icon(Icons.apps)
                : Image.memory(app.icon!, width: 36, height: 36),
            title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(switch (category) {
              EarnAppCategory.productive => 'Productiva',
              EarnAppCategory.distracting => 'Distractora',
              EarnAppCategory.ignored => 'Ignorada',
            }),
            trailing: PopupMenuButton<EarnAppCategory>(
              tooltip: 'Cambiar categoría',
              initialValue: category,
              onSelected: c.busy ? null : (value) => _setCategory(app.package, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: EarnAppCategory.ignored, child: Text('Ignorar')),
                PopupMenuItem(value: EarnAppCategory.productive, child: Text('Productiva')),
                PopupMenuItem(value: EarnAppCategory.distracting, child: Text('Distractora')),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: c.busy ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar estado'),
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
