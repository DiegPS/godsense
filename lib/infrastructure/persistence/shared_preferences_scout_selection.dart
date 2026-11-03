import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/league/scout_selection_store.dart';

class SharedPreferencesScoutSelection implements ScoutSelectionStore {
  const SharedPreferencesScoutSelection();

  static const storageKey = 'scout.selected_profile.v1';

  @override
  Future<ScoutProfileKey?> load() async {
    final values = (await SharedPreferences.getInstance()).getStringList(
      storageKey,
    );
    if (values == null || values.length != 2 || values.any((v) => v.isEmpty)) {
      return null;
    }
    return (puuid: values[0], platform: values[1]);
  }

  @override
  Future<void> save(ScoutProfileKey? key) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = key == null
        ? await preferences.remove(storageKey)
        : await preferences.setStringList(storageKey, [
            key.puuid,
            key.platform,
          ]);
    if (!saved) throw StateError('No se pudo guardar el perfil de Scout.');
  }
}
