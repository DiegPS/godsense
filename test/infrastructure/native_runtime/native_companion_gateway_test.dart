import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_runtime/native_companion_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reports a healthy in-process runtime without external services',
    () async {
      final gateway = NativeCompanionGateway();

      final health = await gateway.health();
      final coach = await const NativeCoachHealthGateway().health();

      expect(health['runtime'], 'in_process');
      expect(health['status'], 'ok');
      expect(coach['runtime'], 'in_process');
      expect(await const InProcessCompanionRuntime().ensureStarted(), isTrue);
      await gateway.closeAlerts();
    },
  );

  test('persists only supported UI settings locally', () async {
    final first = NativeCompanionGateway();
    await first.updateSettings({
      'language': 'es',
      'cadence': 'quiet',
      'overlay_hidden_panels': ['builds', 'gank'],
      'secret': 'must-not-persist',
    });
    await first.closeAlerts();

    final second = NativeCompanionGateway();
    final envelope = await second.settings();
    final settings = envelope['settings'] as Map;

    expect(settings['language'], 'es');
    expect(settings['cadence'], 'quiet');
    expect(settings['overlay_hidden_panels'], ['builds', 'gank']);
    expect(settings.containsKey('secret'), isFalse);
    await second.closeAlerts();
  });

  test('delivers in-memory overlay events without WebSocket IPC', () async {
    final gateway = NativeCompanionGateway();
    final received = gateway.alertEvents().first;

    gateway.publishAlert({'type': 'overlay_edit', 'edit': true});

    expect(await received, {'type': 'overlay_edit', 'edit': true});
    await gateway.closeAlerts();
  });

  test('never claims that local support data was uploaded', () async {
    final gateway = NativeCompanionGateway();

    expect((await gateway.createSupportBundle())['contains_secrets'], isFalse);
    expect((await gateway.reportSupport(note: 'note'))['uploaded'], isFalse);
    await gateway.closeAlerts();
  });
}
