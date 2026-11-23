import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_feed/main.dart';
import 'package:focus_feed/permissions.dart';
import 'package:focus_feed/session_controller.dart';
import 'package:focus_feed/settings.dart';

import 'fake_session_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const earnTimeChannel = MethodChannel('focusfeed/earn_time');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          FocusPermissions.channel,
          (_) async => {'supported': true, 'usage': true, 'overlay': true},
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(earnTimeChannel, (call) async {
          switch (call.method) {
            case 'status':
            case 'configure':
              return {
                'productiveSeconds': 0,
                'earnedSeconds': 0,
                'distractingSeconds': 0,
                'remainingSeconds': 1800,
                'dailyAllowanceSeconds': 1800,
                'rewardNumerator': 1,
                'rewardDenominator': 1,
                'productivePackages': <String>[],
                'distractingPackages': <String>[],
                'monitorRunning': false,
                'usagePermission': true,
                'overlayPermission': true,
              };
            case 'startMonitor':
            case 'stopMonitor':
              return true;
            default:
              return null;
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FocusPermissions.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(earnTimeChannel, null);
  });
  testWidgets('zero reward disables release while installed apps are shown', (
    tester,
  ) async {
    final native = FakeSessionPlatform();
    final c = SessionController(platform: native, poll: false);
    await tester.pumpWidget(FocusFeedApp(controller: c));
    await tester.pumpAndSettle();
    await _openFocus(tester);
    await tester.scrollUntilVisible(
      find.text('Desbloquear apps durante 0 min'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Desbloquear apps durante 0 min'),
    );
    expect(button.onPressed, isNull);
    await tester.scrollUntilVisible(
      find.text('Outro app'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.widgetWithText(CheckboxListTile, 'Outro app'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Outro app'));
    await tester.pumpAndSettle();
    expect(native.calls.last, 'select');
    expect(native.arguments.last, {
      'package': 'com.example.other',
      'selected': true,
    });
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'reopening displays restored paused timer and persisted fractions',
    (tester) async {
      final native = FakeSessionPlatform();
      native.progress['rewardSeconds'] = 312;
      native.progress['session']['phase'] = 'paused';
      native.progress['session']['focusRemainingSeconds'] = 900;
      native.progress['notice'] = 'Celular reiniciado.';
      final c = SessionController(platform: native, poll: false);
      await tester.pumpWidget(FocusFeedApp(controller: c));
      await tester.pumpAndSettle();
      await _openFocus(tester);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('Reanudar enfoque'), findsOneWidget);
      expect(find.text('Celular reiniciado.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Saldo: 5 min 12 s'), 200);
      expect(find.text('Saldo: 5 min 12 s'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('native reward expiry and failure to protect are visible', (
    tester,
  ) async {
    final native = FakeSessionPlatform();
    native.progress['session']['phase'] = 'reward';
    native.progress['session']['rewardRemainingSeconds'] = 12;
    final c = SessionController(platform: native, poll: false);
    await tester.pumpWidget(FocusFeedApp(controller: c));
    await tester.pumpAndSettle();
    await _openFocus(tester);
    await tester.scrollUntilVisible(find.text('Recompensa: 00:12'), 200);
    expect(find.text('Recompensa: 00:12'), findsOneWidget);
    native.progress['session']['phase'] = 'locked';
    native.monitor = false;
    await c.refresh();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('sessionStatus')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Bloqueo no disponible — comprueba los permisos y el servicio'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('failed initial read does not expose default balances/actions', (
    tester,
  ) async {
    final native = FakeSessionPlatform()..fail = 'initialize';
    final c = SessionController(platform: native, poll: false);
    await tester.pumpWidget(FocusFeedApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Volver a cargar'), findsOneWidget);
    expect(find.text('Iniciar enfoque'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('settings tab selects a theme and shows developer contact', (
    tester,
  ) async {
    final native = FakeSessionPlatform();
    final settings = SettingsController(platform: _FakeSettingsPlatform());
    final c = SessionController(platform: native, poll: false);
    await tester.pumpWidget(FocusFeedApp(controller: c, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Valdenor Tavares'), findsOneWidget);
    expect(find.text('valdenor.sa@proton.me'), findsOneWidget);
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(settings.mode, AppThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    c.dispose();
  });
  testWidgets('language switches without losing a paused session', (
    tester,
  ) async {
    final native = FakeSessionPlatform();
    native.progress['session']['phase'] = 'paused';
    native.progress['session']['focusRemainingSeconds'] = 900;
    native.progress['notice'] =
        'Foco concluído. Recompensa adicionada ao saldo.';
    final platform = _FakeSettingsPlatform();
    final settings = SettingsController(platform: platform);
    final controller = SessionController(platform: native, poll: false);
    await tester.pumpWidget(
      FocusFeedApp(controller: controller, settings: settings),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(platform.storedLanguage, 'en-US');
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(platform.storedLanguage, 'es-ES');
    await tester.tap(find.text('Enfoque'));
    await tester.pumpAndSettle();
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Reanudar enfoque'), findsOneWidget);
    expect(
      find.text('Enfoque completado. La recompensa se añadió al saldo.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    controller.dispose();
  });

  testWidgets('iOS exposes the native Screen Time picker', (tester) async {
    final native = FakeSessionPlatform()..platform = 'ios';
    final c = SessionController(platform: native, poll: false);
    await tester.pumpWidget(FocusFeedApp(controller: c));
    await tester.pumpAndSettle();
    await _openFocus(tester);
    await tester.scrollUntilVisible(
      find.text('Seleccionar apps en iOS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Seleccionar apps en iOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar apps en iOS'));
    await tester.pumpAndSettle();
    expect(native.calls.last, 'pickApps');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}

class _FakeSettingsPlatform implements SettingsPlatform {
  String? storedLanguage;

  @override
  Future<String?> loadLanguage() async => storedLanguage;

  @override
  Future<void> saveLanguage(String value) async => storedLanguage = value;

  String? stored;

  @override
  Future<String?> loadTheme() async => stored;

  @override
  Future<void> saveTheme(String value) async => stored = value;
}


Future<void> _openFocus(WidgetTester tester) async {
  await tester.tap(find.text('Enfoque'));
  await tester.pumpAndSettle();
}
