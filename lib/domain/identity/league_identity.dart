extension type const Puuid._(String value) {
  factory Puuid(String value) => Puuid._(_required('PUUID', value));
}

extension type const PlatformId._(String value) {
  factory PlatformId(String value) =>
      PlatformId._(_required('platform ID', value).toUpperCase());
}

extension type const PatchKey._(String value) {
  factory PatchKey(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d+\.\d+$').hasMatch(normalized)) {
      throw FormatException('Patch key must use major.minor: $value');
    }
    return PatchKey._(normalized);
  }
}

extension type const ClientVersion._(String value) {
  factory ClientVersion(String value) =>
      ClientVersion._(_required('client version', value));
}

extension type const DataDragonVersion._(String value) {
  factory DataDragonVersion(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(normalized)) {
      throw FormatException(
        'Data Dragon version must use major.minor.build: $value',
      );
    }
    return DataDragonVersion._(normalized);
  }

  PatchKey get patchKey => PatchKey(value.split('.').take(2).join('.'));
}

extension type const LeagueLocale._(String value) {
  factory LeagueLocale(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^[a-z]{2}_[A-Z]{2}$').hasMatch(normalized)) {
      throw FormatException('League locale must use ll_CC: $value');
    }
    return LeagueLocale._(normalized);
  }
}

class MatchKey {
  const MatchKey({required this.platformId, required this.gameId});

  final PlatformId platformId;
  final int gameId;

  @override
  bool operator ==(Object other) =>
      other is MatchKey &&
      other.platformId == platformId &&
      other.gameId == gameId;

  @override
  int get hashCode => Object.hash(platformId, gameId);

  @override
  String toString() => '${platformId.value}:$gameId';
}

extension type const EntryId._(String value) {
  factory EntryId(String value) => EntryId._(_required('entry ID', value));
}

extension type const CaptureEpochId._(String value) {
  factory CaptureEpochId(String value) =>
      CaptureEpochId._(_required('capture epoch ID', value));
}

extension type const TransportGeneration(int value) {}

extension type const GameSessionGeneration(int value) {}

class GameTime implements Comparable<GameTime> {
  const GameTime._(this.milliseconds);

  factory GameTime(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative');
    }
    return GameTime._(elapsed.inMilliseconds);
  }

  final int milliseconds;

  Duration get elapsed => Duration(milliseconds: milliseconds);

  @override
  int compareTo(GameTime other) => milliseconds.compareTo(other.milliseconds);

  @override
  bool operator ==(Object other) =>
      other is GameTime && other.milliseconds == milliseconds;

  @override
  int get hashCode => milliseconds.hashCode;
}

String _required(String label, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError('$label must not be empty');
  return normalized;
}
