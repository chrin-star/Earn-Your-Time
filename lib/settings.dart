import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'focus_strings.dart';

/// Preferência de tema persistida no armazenamento nativo.
enum AppThemeMode {
  system('Automático', ThemeMode.system),
  light('Claro', ThemeMode.light),
  dark('Escuro', ThemeMode.dark);

  const AppThemeMode(this.label, this.themeMode);

  final String label;
  final ThemeMode themeMode;

  static AppThemeMode parse(String? value) => values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppThemeMode.system,
  );
}

abstract class SettingsPlatform {
  Future<bool> createBackup();
  Future<bool> restoreBackup();
  Future<String?> loadTheme();
  Future<void> saveTheme(String value);
  Future<String?> loadLanguage();
  Future<void> saveLanguage(String value);
}

class NativeSettingsPlatform implements SettingsPlatform {
  static const channel = MethodChannel('focusfeed/settings');

  @override
  Future<bool> createBackup() async => await channel.invokeMethod<bool>('createBackup') ?? false;

  @override
  Future<bool> restoreBackup() async => await channel.invokeMethod<bool>('restoreBackup') ?? false;

  @override
  Future<String?> loadTheme() => channel.invokeMethod<String>('loadTheme');

  @override
  Future<void> saveTheme(String value) =>
      channel.invokeMethod<void>('saveTheme', {'value': value});

  @override
  Future<String?> loadLanguage() =>
      channel.invokeMethod<String>('loadLanguage');

  @override
  Future<void> saveLanguage(String value) =>
      channel.invokeMethod<void>('saveLanguage', {'value': value});
}

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsPlatform? platform})
    : _platform = platform ?? NativeSettingsPlatform();

  final SettingsPlatform _platform;
  AppThemeMode _mode = AppThemeMode.system;
  AppLanguage _language = AppLanguage.spanish;
  bool _disposed = false;
  bool _languageChosen = false;

  AppThemeMode get mode => _mode;
  AppLanguage get language => _language;

  Future<void> load() => Future.wait([_loadTheme(), _loadLanguage()]);

  Future<void> _loadTheme() async {
    try {
      final value = await _platform.loadTheme();
      if (_disposed || value == null) return;
      _mode = AppThemeMode.parse(value);
      notifyListeners();
    } catch (_) {
      // Sem canal nativo (testes ou plataforma sem suporte): mantém o padrão.
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final value = await _platform.loadLanguage();
      if (_disposed || _languageChosen) return;
      _language = AppLanguage.parse(value);
      notifyListeners();
    } catch (_) {
      // Keep Brazilian Portuguese if the native preference cannot be read.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _languageChosen = true;
    if (language != _language) {
      _language = language;
      notifyListeners();
    }
    try {
      await _platform.saveLanguage(language.tag);
    } catch (_) {
      // The selection is still valid for the current run.
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _platform.saveTheme(mode.name);
    } catch (_) {
      // A preferência continua válida nesta execução mesmo sem persistência.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SettingsView extends StatelessWidget {
  Future<void> _copyPixKey(BuildContext context) async {
    var feedback = context.strings.text('Chave Pix copiada.');
    final failure = context.strings.text(
      'Não foi possível copiar a chave Pix.',
    );
    try {
      await Clipboard.setData(
        const ClipboardData(text: '81063e93-0c1b-4ddb-8a16-b9be68a75d4e'),
      );
    } on PlatformException {
      feedback = failure;
    } on MissingPluginException {
      feedback = failure;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(feedback)));
    }
  }

  Future<void> _openSponsors(BuildContext context) async {
    final failure = context.strings.text(
      'Não foi possível abrir o GitHub Sponsors.',
    );
    try {
      final opened = await launchUrl(
        Uri.parse('https://github.com/sponsors/alunoadsnoite'),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } on PlatformException {
      // Show the same feedback when no browser is available.
    } on MissingPluginException {
      // Some Flutter targets may not register a URL launcher.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  const SettingsView({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(strings.text('Idioma'), style: theme.textTheme.titleMedium),
          RadioGroup<AppLanguage>(
            groupValue: controller.language,
            onChanged: (value) {
              if (value != null) controller.setLanguage(value);
            },
            child: Column(
              children: [
                for (final language in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: language,
                    title: Text(language.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(strings.text('Aparência'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            strings.text(
              'Escolha o tema do aplicativo. O modo automático acompanha o sistema.',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            key: const Key('themeMode'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AppThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(strings.text('Claro')),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(strings.text('Escuro')),
              ),
              ButtonSegment(
                value: AppThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined),
                label: Text(strings.text('Auto')),
              ),
            ],
            selected: {controller.mode},
            onSelectionChanged: (selection) =>
                controller.setMode(selection.first),
          ),
          const SizedBox(height: 24),
          Text(
            strings.text('Mantén el seguimiento activo'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.battery_saver_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Importante en Xiaomi y Redmi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para evitar que el sistema pause el conteo: abre Ajustes > Aplicaciones > Administrar aplicaciones > Earn Your Time > Ahorro de batería y selecciona «Sin restricciones». Si tu teléfono ofrece «Inicio automático», permite también Earn Your Time.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En otros Android, permite el uso en segundo plano si el sistema lo solicita. No fuerces el cierre de la app ni retires los permisos de acceso al uso o de superposición mientras quieras que funcione. Android puede limitar los servicios en segundo plano según el fabricante.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            strings.text('Desenvolvedor'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valdenor Tavares', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const SelectableText('valdenor.sa@proton.me'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: 'valdenor.sa@proton.me'),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.text('E-mail copiado.')),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(strings.text('Copiar e-mail')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            strings.text('Apoie o desenvolvedor'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextButton.icon(
            onPressed: () => _copyPixKey(context),
            icon: const Icon(Icons.copy),
            label: Text(strings.text('Copiar chave Pix')),
          ),
          TextButton.icon(
            onPressed: () => _openSponsors(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('GitHub Sponsors'),
          ),
          const SizedBox(height: 24),
          Text('Copia de seguridad', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Guarda tu racha, historial, saldo, aplicaciones y ajustes en un archivo que puedes conservar en el teléfono o en Google Drive. Restaurar reemplaza los datos actuales.'),
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Crear copia de seguridad'),
                onPressed: () async {
                  try {
                    final ok = await NativeSettingsPlatform().createBackup();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Copia guardada.' : 'No se creó la copia.')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear la copia: $e')));
                  }
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Restaurar copia de seguridad'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('¿Restaurar copia?'),
                      content: const Text('Esto reemplazará el progreso y los ajustes actuales con los datos del archivo elegido. No se puede deshacer.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continuar')),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  try {
                    final ok = await NativeSettingsPlatform().restoreBackup();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Copia restaurada. Reinicia Earn Your Time para actualizar los datos.' : 'No se restauró la copia.')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al restaurar: $e')));
                  }
                },
              ),
            ]),
          )),
          const SizedBox(height: 24),
          Text(strings.text('Sobre'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                strings.text(
                  'Earn Your Time registra o uso das aplicações que você classifica, transforma tempo produtivo em saldo e ajuda a limitar apps de distração. O acompanhamento é local e o progresso fica salvo no aparelho.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
