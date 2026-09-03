import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_model_selection_controller.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';

import '../../support/ai_models.dart';

void main() {
  test(
    'connected catalog chooses free default and saves explicit selection',
    () async {
      final preferences = MemoryModelPreferences();
      final controller = AiModelSelectionController(
        runtimeId: 'kilo',
        loadProviders: () async => [
          ...catalogFixture,
          const AiProviderInfo(
            id: 'offline',
            name: 'Offline',
            connected: false,
            models: [paidModel],
          ),
        ],
        preferences: preferences,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.state.providers.map((p) => p.id), ['kilo', 'other']);
      expect(controller.state.selected, freeModel);
      await controller.select(paidModel.key);
      expect(controller.state.selected, paidModel);
      expect(preferences.values['kilo'], paidModel.key);
      await controller.select('invalid');
      expect(controller.state.selected, paidModel);
    },
  );

  test('each runtime restores its own selection', () async {
    final preferences = MemoryModelPreferences();
    preferences.values['opencode'] = paidModel.key;
    for (final runtime in ['opencode', 'kilo']) {
      final controller = AiModelSelectionController(
        runtimeId: runtime,
        loadProviders: () async => catalogFixture,
        preferences: preferences,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(
        controller.state.selected,
        runtime == 'opencode' ? paidModel : freeModel,
      );
    }
  });

  test('missing saved model does not silently replace it', () async {
    final preferences = MemoryModelPreferences()
      ..values['kilo'] = 'removed/model';
    final controller = AiModelSelectionController(
      runtimeId: 'kilo',
      loadProviders: () async => catalogFixture,
      preferences: preferences,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.selected, isNull);
    expect(controller.state.notice, contains('ya no está disponible'));
  });

  test('a paid-only catalog requires explicit choice', () async {
    final controller = AiModelSelectionController(
      runtimeId: 'opencode',
      loadProviders: () async => [catalogFixture.last],
      preferences: MemoryModelPreferences(),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.selected, isNull);
    await controller.select(paidModel.key);
    expect(controller.state.selected, paidModel);
  });

  test('late refresh cannot replace a newer catalog', () async {
    final first = Completer<List<AiProviderInfo>>();
    var count = 0;
    final controller = AiModelSelectionController(
      runtimeId: 'kilo',
      loadProviders: () =>
          ++count == 1 ? first.future : Future.value(catalogFixture),
      preferences: MemoryModelPreferences(),
    );
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    await controller.refresh();
    first.complete([]);
    await pending;
    expect(controller.state.selected, freeModel);
  });

  test('failure clears usable selection and refresh recovers', () async {
    var fail = true;
    final controller = AiModelSelectionController(
      runtimeId: 'kilo',
      loadProviders: () async {
        if (fail) throw StateError('offline');
        return catalogFixture;
      },
      preferences: MemoryModelPreferences(),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.error, contains('offline'));
    expect(controller.state.selected, isNull);
    fail = false;
    await controller.refresh();
    expect(controller.state.error, isNull);
    expect(controller.state.selected, freeModel);
  });
}
