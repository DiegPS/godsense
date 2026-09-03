// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_runtime_api_models.dart';

abstract interface class AiModelPreferences {
  Future<String?> read(String runtimeId);
  Future<void> write(String runtimeId, String modelKey);
}

class AiModelSelectionState {
  const AiModelSelectionState({
    this.providers = const [],
    this.selected,
    this.loading = false,
    this.error,
    this.notice,
  });

  final List<AiProviderInfo> providers;
  final AiModelInfo? selected;
  final bool loading;
  final String? error;
  final String? notice;
}

class AiModelSelectionController extends StateNotifier<AiModelSelectionState> {
  AiModelSelectionController({
    required this.runtimeId,
    required Future<List<AiProviderInfo>> Function() loadProviders,
    required AiModelPreferences preferences,
  }) : _loadProviders = loadProviders,
       _preferences = preferences,
       super(const AiModelSelectionState());

  final String runtimeId;
  final Future<List<AiProviderInfo>> Function() _loadProviders;
  final AiModelPreferences _preferences;
  int _revision = 0;
  Future<void> _saving = Future.value();

  Future<void> refresh() async {
    final revision = ++_revision;
    final previous = state.selected;
    state = AiModelSelectionState(
      loading: true,
      providers: state.providers,
      selected: previous,
    );
    try {
      final catalog = await _loadProviders();
      String? saved;
      String? notice;
      try {
        await _saving;
        saved = await _preferences.read(runtimeId);
      } catch (_) {
        notice = 'No se pudo leer la selección guardada.';
      }
      if (!mounted || revision != _revision) return;
      final providers =
          catalog
              .where(
                (provider) => provider.connected && provider.models.isNotEmpty,
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final models = providers.expand((provider) => provider.models).toList();
      AiModelInfo? selected;
      final preferredKey = previous?.key ?? saved;
      for (final model in models) {
        if (model.key == preferredKey) selected = model;
      }
      if (selected == null && preferredKey != null) {
        notice = 'El modelo guardado ya no está disponible. Elige otro para continuar.';
      } else if (selected == null) {
        // Never silently move a first-time user to a paid model.
        final free = models.where((model) => model.isFree).toList()
          ..sort((a, b) {
            if (a.key == b.key) return 0;
            if (a.providerId == 'kilo' && a.id == 'kilo-auto/free') return -1;
            if (b.providerId == 'kilo' && b.id == 'kilo-auto/free') return 1;
            if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
            return a.name.compareTo(b.name);
          });
        selected = free.firstOrNull;
      }
      state = AiModelSelectionState(
        providers: providers,
        selected: selected,
        notice: notice,
      );
    } catch (error) {
      if (mounted && revision == _revision) {
        state = AiModelSelectionState(
          error: 'No se pudieron cargar los modelos. $error',
        );
      }
    }
  }

  Future<void> select(String modelKey) async {
    if (state.loading) return;
    final model = state.providers
        .expand((provider) => provider.models)
        .where((model) => model.key == modelKey)
        .firstOrNull;
    if (model == null) return;
    final revision = ++_revision;
    state = AiModelSelectionState(providers: state.providers, selected: model);
    final save = _saving.then((_) => _preferences.write(runtimeId, modelKey));
    _saving = save.catchError((Object _) {});
    try {
      await save;
    } catch (_) {
      if (mounted && revision == _revision) {
        state = AiModelSelectionState(
          providers: state.providers,
          selected: model,
          notice: 'Modelo seleccionado, pero no se pudo guardar para el próximo inicio.',
        );
      }
    }
  }
}
