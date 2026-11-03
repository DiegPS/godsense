typedef ScoutProfileKey = ({String puuid, String platform});

abstract interface class ScoutSelectionStore {
  Future<ScoutProfileKey?> load();
  Future<void> save(ScoutProfileKey? key);
}
