import 'package:godsense/application/ai/ai_model_selection_controller.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';

const freeModel = AiModelInfo(
  id: 'kilo-auto/free',
  name: 'Kilo Auto',
  providerId: 'kilo',
  isFree: true,
);
const paidModel = AiModelInfo(
  id: 'paid-model',
  name: 'Premium',
  providerId: 'other',
  isFree: false,
);
const catalogFixture = [
  AiProviderInfo(
    id: 'kilo',
    name: 'Kilo',
    connected: true,
    models: [freeModel],
  ),
  AiProviderInfo(
    id: 'other',
    name: 'Other',
    connected: true,
    models: [paidModel],
  ),
];

class MemoryModelPreferences implements AiModelPreferences {
  final values = <String, String>{};
  @override
  Future<String?> read(String runtimeId) async => values[runtimeId];
  @override
  Future<void> write(String runtimeId, String modelKey) async {
    values[runtimeId] = modelKey;
  }
}

class ReadyModelSelection extends AiModelSelectionController {
  ReadyModelSelection()
    : super(
        runtimeId: 'kilo',
        loadProviders: () async => catalogFixture,
        preferences: MemoryModelPreferences(),
      ) {
    state = const AiModelSelectionState(
      providers: catalogFixture,
      selected: freeModel,
    );
  }
}
