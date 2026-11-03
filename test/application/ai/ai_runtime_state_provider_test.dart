import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';

import 'ai_conversation_controller_test.dart' show FakeSupervisor;

class _ReadySupervisor extends FakeSupervisor {
  final changes = StreamController<AiRuntimeSupervisorState>.broadcast();
  @override
  Stream<AiRuntimeSupervisorState> get states => changes.stream;
}

void main() {
  test(
    'late subscriber immediately observes an already running AI engine',
    () async {
      final supervisor = _ReadySupervisor();
      final container = ProviderContainer(
        overrides: [aiRuntimeSupervisorProvider.overrideWithValue(supervisor)],
      );
      addTearDown(() async {
        container.dispose();
        await supervisor.changes.close();
      });
      final first = await container
          .read(aiRuntimeSupervisorStateProvider.future)
          .timeout(const Duration(seconds: 1));
      expect(first.isReady, isTrue);
      expect(first.endpoint?.pid, supervisor.state.endpoint?.pid);
      expect(supervisor.changes.hasListener, isTrue);
      final observed = <bool>[];
      container.listen(aiRuntimeSupervisorStateProvider, (_, next) {
        if (next.value != null) observed.add(next.value!.isReady);
      });
      supervisor.ready = false;
      supervisor.changes.add(supervisor.state);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(aiRuntimeSupervisorStateProvider).value?.isReady,
        isFalse,
      );
      expect(observed, contains(false));
    },
  );
}
