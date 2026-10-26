import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_provider_connection_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/presentation/coach/shared/ai_provider_connections.dart';

import '../../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;
import '../../support/ai_models.dart';

void main() {
  late _Auth auth;
  Future<void> boot(WidgetTester tester, {bool ready = true}) async {
    auth = _Auth();
    final supervisor = FakeSupervisor(ready: ready);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (_) => Stream.value(supervisor.state),
          ),
          aiProviderConnectionProvider.overrideWith((_) => auth),
          aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
        ],
        child: const MaterialApp(home: Scaffold(body: AiProviderConnections())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'API key dialog masks input, cancellation is harmless and disconnect works',
    (tester) async {
      await boot(tester);
      await tester.tap(find.text('API key'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
      await tester.enterText(find.byType(TextField), 'synthetic-secret');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(auth.keys, isEmpty);
      await tester.tap(find.text('API key'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();
      expect(auth.keys, isEmpty);
      await tester.tap(find.text('API key'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'synthetic-secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.keys, [('synthetic', 'synthetic-secret')]);
      expect(find.text('Cuenta conectada'), findsOneWidget);
      expect(find.text('synthetic-secret'), findsNothing);
      await tester.tap(find.text('Desconectar'));
      await tester.pumpAndSettle();
      expect(auth.disconnections, ['synthetic']);
      expect(find.text('API key'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'OAuth requires a nonempty code and returns only submitted input',
    (tester) async {
      await boot(tester);
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(auth.begins, 1);
      expect(find.text('Synthetic authorization instructions'), findsOneWidget);
      await tester.tap(find.text('Introducir código y conectar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Introduce el código.'), findsOneWidget);
      expect(auth.codes, isEmpty);
      await tester.enterText(find.byType(TextFormField), 'synthetic-code');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(auth.codes, ['synthetic-code']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('stopped runtime does not expose authentication controls', (
    tester,
  ) async {
    await boot(tester, ready: false);
    expect(
      find.text('Inicia un motor para conectar cuentas de modelos.'),
      findsOneWidget,
    );
    expect(find.text('API key'), findsNothing);
    expect(find.text('Entrar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Auth extends AiProviderConnectionController {
  _Auth() : super(client: null) {
    _publish();
  }
  final keys = <(String, String)>[];
  final disconnections = <String>[];
  final codes = <String?>[];
  int begins = 0;
  static const methods = [
    AiAuthMethod(
      providerId: 'synthetic',
      type: 'api',
      label: 'API key',
      index: 0,
    ),
    AiAuthMethod(
      providerId: 'synthetic',
      type: 'oauth',
      label: 'OAuth',
      index: 1,
    ),
  ];
  void _publish({bool connected = false}) => state = AiProviderConnectionState(
    methods: methods,
    connected: connected ? {'synthetic'} : {},
  );
  @override
  Future<void> connectApiKey(String providerId, String apiKey) async {
    keys.add((providerId, apiKey));
    _publish(connected: true);
  }

  @override
  Future<void> disconnect(String providerId) async {
    disconnections.add(providerId);
    _publish();
  }

  @override
  Future<void> beginOAuth(
    AiAuthMethod method, {
    Map<String, String> inputs = const {},
  }) async {
    begins++;
    state = const AiProviderConnectionState(
      methods: methods,
      instructions: 'Synthetic authorization instructions',
      authorizationMethod: 'code',
    );
  }

  @override
  Future<void> completeOAuth({String? code}) async {
    codes.add(code);
    _publish(connected: true);
  }
}
