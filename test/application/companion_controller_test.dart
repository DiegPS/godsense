import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/domain/companion_gateway.dart';

void main() {
  test('refreshes from source changes without periodic UI polling', () async {
    final gateway = _CountingCompanionGateway();
    final controller = CompanionController(gateway);

    await controller.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(gateway.fastCalls, 4);
    expect(gateway.coachingCalls, 1);
    expect(gateway.healthCalls, 1);
    expect(gateway.settingsCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(gateway.fastCalls, 4);
    expect(gateway.coachingCalls, 1);
    expect(gateway.healthCalls, 1);
    expect(gateway.settingsCalls, 1);

    controller.refreshFromSource();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(gateway.fastCalls, 8);
    expect(gateway.coachingCalls, 2);
    expect(gateway.healthCalls, 2);
    expect(gateway.settingsCalls, 1);

    controller.dispose();
  });
}

class _CountingCompanionGateway implements CompanionGateway {
  int fastCalls = 0;
  int coachingCalls = 0;
  int healthCalls = 0;
  int settingsCalls = 0;

  @override
  Future<Map<String, dynamic>> health() async {
    healthCalls++;
    return {
      'status': 'ok',
      'game_detected': false,
      'degraded': false,
      'components': <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> coaching() async {
    coachingCalls++;
    return const {};
  }

  @override
  Future<Map<String, dynamic>> coachingStatus() async {
    fastCalls++;
    return const {};
  }

  @override
  Future<List<Map<String, dynamic>>> directives() async {
    fastCalls++;
    return const [];
  }

  @override
  Future<Map<String, dynamic>> lobbyHealth() async {
    fastCalls++;
    return const {};
  }

  @override
  Future<Map<String, dynamic>> lobbyState() async {
    fastCalls++;
    return const {'phase': 'NO_LCU'};
  }

  @override
  Future<Map<String, dynamic>> settings() async {
    settingsCalls++;
    return const {'settings': <String, dynamic>{}};
  }

  @override
  Stream<Map<String, dynamic>> alertEvents() => const Stream.empty();

  @override
  Future<void> closeAlerts() async {}

  @override
  Future<Map<String, dynamic>> generateLobbyBrief(String candidate) async =>
      const {};

  @override
  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> patch,
  ) async => const {};
}
