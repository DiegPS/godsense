enum LcuCapabilityId {
  currentSummoner,
  gameflow,
  champSelect,
  matchHistoryList,
  matchDetails,
  matchTimeline,
  rankedCurrent,
  rankedByPuuid,
  patchVersion,
  runeWriting,
  itemSetWriting,
}

enum LcuCapabilityStatus {
  unknown,
  available,
  unavailable,
  temporarilyUnavailable,
}

enum LcuCapabilityReason {
  verified,
  requiresContext,
  requiresUserOperation,
  disconnected,
  unauthorized,
  transientFailure,
  ambiguousNotFound,
  incompatibleResponse,
  unsupported,
}

class LcuCapability {
  const LcuCapability({
    required this.id,
    required this.status,
    required this.reason,
    required this.checkedAt,
    this.clientVersion,
    this.httpStatus,
    this.detail,
  });

  factory LcuCapability.unknown(
    LcuCapabilityId id, {
    required LcuCapabilityReason reason,
    required DateTime checkedAt,
    String? detail,
  }) {
    return LcuCapability(
      id: id,
      status: LcuCapabilityStatus.unknown,
      reason: reason,
      checkedAt: checkedAt,
      detail: detail,
    );
  }

  final LcuCapabilityId id;
  final LcuCapabilityStatus status;
  final LcuCapabilityReason reason;
  final DateTime checkedAt;
  final String? clientVersion;
  final int? httpStatus;
  final String? detail;

  bool get isAvailable => status == LcuCapabilityStatus.available;
}

class LcuCapabilities {
  LcuCapabilities(Iterable<LcuCapability> capabilities)
    : _values = Map.unmodifiable({
        for (final capability in capabilities) capability.id: capability,
      });

  final Map<LcuCapabilityId, LcuCapability> _values;

  LcuCapability operator [](LcuCapabilityId id) =>
      _values[id] ??
      LcuCapability.unknown(
        id,
        reason: LcuCapabilityReason.requiresContext,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        detail: 'Capability has not been evaluated.',
      );

  Iterable<LcuCapability> get values => _values.values;

  bool get canLoadAccount => this[LcuCapabilityId.currentSummoner].isAvailable;

  bool get canRunLiveCoach => this[LcuCapabilityId.gameflow].isAvailable;

  bool get canUseChampSelect => this[LcuCapabilityId.champSelect].isAvailable;

  bool get canSyncNewMatches =>
      this[LcuCapabilityId.matchHistoryList].isAvailable &&
      this[LcuCapabilityId.matchDetails].status !=
          LcuCapabilityStatus.unavailable;

  bool get canLoadRanked =>
      this[LcuCapabilityId.rankedCurrent].isAvailable ||
      this[LcuCapabilityId.rankedByPuuid].isAvailable;

  LcuCapabilities replace(LcuCapability capability) =>
      LcuCapabilities([..._values.values, capability]);
}
