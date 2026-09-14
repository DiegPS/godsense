import 'dart:async';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AiModelPreferences
    implements runtime.AiModelSelectionStore {}

class AiModelSelectionState {
  const AiModelSelectionState({
    this.providers = const [],
    this.selected,
    this.loading = false,
    this.error,
    this.notice,
  });

  final List<runtime.AiProviderInfo> providers;
  final runtime.AiModelInfo? selected;
  final bool loading;
  final String? error;
  final String? notice;
}

/// Riverpod presentation adapter over dart_ai_runtime's model policy.
class AiModelSelectionController extends StateNotifier<AiModelSelectionState> {
  AiModelSelectionController({
    required String runtimeId,
    required Future<List<runtime.AiProviderInfo>> Function() loadProviders,
    required AiModelPreferences preferences,
  }) : _core = runtime.AiModelSelectionController(
         runtimeId: runtimeId,
         loadProviders: loadProviders,
         store: preferences,
       ),
       super(const AiModelSelectionState()) {
    _subscription = _core.states.listen(_apply);
  }

  final runtime.AiModelSelectionController _core;
  late final StreamSubscription<runtime.AiModelSelectionState> _subscription;

  String get runtimeId => _core.runtimeId;

  Future<void> refresh() async {
    await _core.refresh();
    if (mounted) _apply(_core.state);
  }

  Future<void> select(String modelKey) async {
    try {
      await _core.select(modelKey);
    } on ArgumentError {
      final model = state.providers
          .expand((provider) => provider.models)
          .where((candidate) => candidate.key == modelKey)
          .firstOrNull;
      if (model != null && mounted) {
        state = AiModelSelectionState(
          providers: state.providers,
          selected: model,
        );
      }
      return;
    }
    if (mounted) _apply(_core.state);
  }

  void _apply(runtime.AiModelSelectionState value) {
    if (!mounted) return;
    state = AiModelSelectionState(
      providers: value.providers,
      selected: value.selected,
      loading: value.loading,
      error: value.error?.toString(),
      notice: value.notice == 'The saved model is no longer available.'
          ? 'El modelo guardado ya no está disponible. Elige otro para continuar.'
          : value.notice,
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_core.dispose());
    super.dispose();
  }
}
