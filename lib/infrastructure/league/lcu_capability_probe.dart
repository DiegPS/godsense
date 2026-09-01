import '../../domain/league/lcu_capabilities.dart';
import 'lcu_probe_transport.dart';

class LcuProbeContext {
  const LcuProbeContext({
    this.puuid,
    this.gameId,
    this.gameflowPhase,
    this.clientVersion,
  });

  final String? puuid;
  final int? gameId;
  final String? gameflowPhase;
  final String? clientVersion;
}

class LcuCapabilityProbe {
  LcuCapabilityProbe({required this.transport, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LcuProbeTransport transport;
  final DateTime Function() _now;

  Future<LcuCapabilities> probe([
    LcuProbeContext context = const LcuProbeContext(),
  ]) async {
    final checkedAt = _now().toUtc();
    final capabilities = <LcuCapability>[
      await _probeRead(
        LcuCapabilityId.currentSummoner,
        '/lol-summoner/v1/current-summoner',
        checkedAt,
        context.clientVersion,
      ),
      await _probeRead(
        LcuCapabilityId.gameflow,
        '/lol-gameflow/v1/gameflow-phase',
        checkedAt,
        context.clientVersion,
      ),
      await _probeRead(
        LcuCapabilityId.patchVersion,
        '/lol-patch/v1/game-version',
        checkedAt,
        context.clientVersion,
      ),
      await _probeRead(
        LcuCapabilityId.rankedCurrent,
        '/lol-ranked/v1/current-ranked-stats',
        checkedAt,
        context.clientVersion,
      ),
      await _probeRuneRecommendations(checkedAt, context.clientVersion),
    ];

    if (context.gameflowPhase == 'ChampSelect') {
      capabilities.add(
        await _probeRead(
          LcuCapabilityId.champSelect,
          '/lol-champ-select/v1/session',
          checkedAt,
          context.clientVersion,
        ),
      );
    } else {
      capabilities.add(
        _requiresContext(
          LcuCapabilityId.champSelect,
          checkedAt,
          'Champ Select is not active.',
        ),
      );
    }

    final puuid = context.puuid;
    if (puuid == null || puuid.isEmpty) {
      capabilities
        ..add(
          _requiresContext(
            LcuCapabilityId.matchHistoryList,
            checkedAt,
            'A current account PUUID is required.',
          ),
        )
        ..add(
          _requiresContext(
            LcuCapabilityId.rankedByPuuid,
            checkedAt,
            'A current account PUUID is required.',
          ),
        );
    } else {
      capabilities
        ..add(
          await _probeRead(
            LcuCapabilityId.matchHistoryList,
            '/lol-match-history/v1/products/lol/$puuid/matches?begIndex=0&endIndex=1',
            checkedAt,
            context.clientVersion,
          ),
        )
        ..add(
          await _probeRead(
            LcuCapabilityId.rankedByPuuid,
            '/lol-ranked/v1/ranked-stats/$puuid',
            checkedAt,
            context.clientVersion,
          ),
        );
    }

    final gameId = context.gameId;
    if (gameId == null) {
      capabilities
        ..add(
          _requiresContext(
            LcuCapabilityId.matchDetails,
            checkedAt,
            'A known match ID is required.',
          ),
        )
        ..add(
          _requiresContext(
            LcuCapabilityId.matchTimeline,
            checkedAt,
            'A known match ID is required.',
          ),
        );
    } else {
      capabilities
        ..add(
          await _probeRead(
            LcuCapabilityId.matchDetails,
            '/lol-match-history/v1/games/$gameId',
            checkedAt,
            context.clientVersion,
          ),
        )
        ..add(
          await _probeRead(
            LcuCapabilityId.matchTimeline,
            '/lol-match-history/v1/game-timelines/$gameId',
            checkedAt,
            context.clientVersion,
          ),
        );
    }

    capabilities
      ..add(
        LcuCapability.unknown(
          LcuCapabilityId.runeWriting,
          reason: LcuCapabilityReason.requiresUserOperation,
          checkedAt: checkedAt,
          detail: 'Confirmed only by an explicit rune import operation.',
        ),
      )
      ..add(
        LcuCapability.unknown(
          LcuCapabilityId.itemSetWriting,
          reason: LcuCapabilityReason.requiresUserOperation,
          checkedAt: checkedAt,
          detail: 'Confirmed only by an explicit item-set import operation.',
        ),
      );

    return LcuCapabilities(capabilities);
  }

  Future<LcuCapability> _probeRead(
    LcuCapabilityId id,
    String path,
    DateTime checkedAt,
    String? clientVersion,
  ) async {
    final response = await transport.getDetailed(path);
    if (response.isSuccess) {
      return LcuCapability(
        id: id,
        status: LcuCapabilityStatus.available,
        reason: LcuCapabilityReason.verified,
        checkedAt: checkedAt,
        clientVersion: clientVersion,
        httpStatus: response.statusCode,
      );
    }

    return _fromFailure(id, response, checkedAt, clientVersion);
  }

  LcuCapability _fromFailure(
    LcuCapabilityId id,
    LcuProbeResponse response,
    DateTime checkedAt,
    String? clientVersion,
  ) {
    final status = switch (response.failureKind) {
      LcuProbeFailureKind.disconnected ||
      LcuProbeFailureKind.timeout ||
      LcuProbeFailureKind.serverError =>
        LcuCapabilityStatus.temporarilyUnavailable,
      LcuProbeFailureKind.unauthorized =>
        LcuCapabilityStatus.temporarilyUnavailable,
      LcuProbeFailureKind.clientError ||
      LcuProbeFailureKind.invalidPayload => LcuCapabilityStatus.unknown,
      null => LcuCapabilityStatus.unknown,
    };
    final reason = switch (response.failureKind) {
      LcuProbeFailureKind.disconnected => LcuCapabilityReason.disconnected,
      LcuProbeFailureKind.unauthorized => LcuCapabilityReason.unauthorized,
      LcuProbeFailureKind.timeout ||
      LcuProbeFailureKind.serverError => LcuCapabilityReason.transientFailure,
      LcuProbeFailureKind.clientError when response.statusCode == 404 =>
        LcuCapabilityReason.ambiguousNotFound,
      LcuProbeFailureKind.clientError => LcuCapabilityReason.unsupported,
      LcuProbeFailureKind.invalidPayload =>
        LcuCapabilityReason.incompatibleResponse,
      null => LcuCapabilityReason.incompatibleResponse,
    };
    return LcuCapability(
      id: id,
      status: status,
      reason: reason,
      checkedAt: checkedAt,
      clientVersion: clientVersion,
      httpStatus: response.statusCode,
      detail: response.error,
    );
  }

  Future<LcuCapability> _probeRuneRecommendations(
    DateTime checkedAt,
    String? clientVersion,
  ) async {
    const id = LcuCapabilityId.runeRecommendationsRead;
    final response = await transport.getDetailed(
      '/lol-perks/v1/recommended-pages/champion/103/'
      'position/MIDDLE/map/11',
    );
    if (!response.isSuccess) {
      return _fromFailure(id, response, checkedAt, clientVersion);
    }
    final body = response.body;
    final valid =
        body is List &&
        body.whereType<Map>().any(
          (item) =>
              item['recommendationChampionId'] == 103 &&
              item['position']?.toString().toUpperCase() == 'MIDDLE' &&
              item['perks'] is List &&
              (item['perks'] as List).length == 9,
        );
    if (!valid) {
      return LcuCapability(
        id: id,
        status: LcuCapabilityStatus.unknown,
        reason: LcuCapabilityReason.incompatibleResponse,
        checkedAt: checkedAt,
        clientVersion: clientVersion,
        httpStatus: response.statusCode,
        detail: 'Rune recommender returned no compatible recommendation.',
      );
    }
    return LcuCapability(
      id: id,
      status: LcuCapabilityStatus.available,
      reason: LcuCapabilityReason.verified,
      checkedAt: checkedAt,
      clientVersion: clientVersion,
      httpStatus: response.statusCode,
    );
  }

  LcuCapability _requiresContext(
    LcuCapabilityId id,
    DateTime checkedAt,
    String detail,
  ) {
    return LcuCapability.unknown(
      id,
      reason: LcuCapabilityReason.requiresContext,
      checkedAt: checkedAt,
      detail: detail,
    );
  }
}
