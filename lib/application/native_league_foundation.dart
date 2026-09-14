import 'dart:async';
import 'dart:io';

import '../domain/identity/league_identity.dart';
import '../domain/journal/journal_models.dart';
import '../domain/league/account_context.dart';
import '../domain/league/game_session.dart';
import '../domain/league/lcu_capabilities.dart';
import '../domain/league/local_scout.dart';
import '../domain/tactical/tactical_models.dart';
import '../domain/vision/vision_observation.dart';
import '../infrastructure/league/lcu_capability_probe.dart';
import '../infrastructure/league/lcu_current_account_source.dart';
import '../infrastructure/league/lcu_probe_transport.dart';
import '../infrastructure/persistence/drift_account_context_repository.dart';
import '../infrastructure/persistence/drift_journal_repository.dart';
import '../infrastructure/persistence/drift_local_scout_repository.dart';
import '../infrastructure/persistence/godsense_database.dart'
    hide AccountContextState;
import '../infrastructure/persistence/journal_payload_codec.dart';
import '../infrastructure/persistence/local_data_manager.dart';
import 'account_context_coordinator.dart';
import 'game_session_coordinator.dart';
import 'live_client_journal_adapter.dart';
import 'local_scout_sync_service.dart';
import 'tactical_advice_journal_adapter.dart';
import 'vision_journal_adapter.dart';

export '../infrastructure/persistence/local_data_manager.dart'
    show LocalDataRetentionResult;

const _accountReconciliationInterval = Duration(seconds: 30);
const _capabilityReconciliationInterval = Duration(minutes: 5);

class NativeLeagueFoundationState {
  const NativeLeagueFoundationState({
    required this.account,
    required this.capabilities,
    required this.gameSession,
    this.lastScoutSync,
    this.lastError,
  });

  factory NativeLeagueFoundationState.initial(DateTime now) {
    return NativeLeagueFoundationState(
      account: const AccountContextState.initial(),
      capabilities: LcuCapabilities([
        for (final id in LcuCapabilityId.values)
          LcuCapability.unknown(
            id,
            reason: LcuCapabilityReason.requiresContext,
            checkedAt: now.toUtc(),
            detail: 'Native League foundation has not initialized.',
          ),
      ]),
      gameSession: const GameSessionState(),
    );
  }

  final AccountContextState account;
  final LcuCapabilities capabilities;
  final GameSessionState gameSession;
  final LocalScoutSyncResult? lastScoutSync;
  final String? lastError;
}

class NativeLeagueFoundation {
  NativeLeagueFoundation({
    required this.client,
    Future<GodSenseDatabase> Function()? databaseFactory,
    DateTime Function()? now,
    String? captureEpochId,
  }) : _databaseFactory = databaseFactory ?? openGodSenseDatabase,
       _now = now ?? DateTime.now,
       _captureEpochId = CaptureEpochId(
         captureEpochId ??
             '$pid-${DateTime.now().toUtc().microsecondsSinceEpoch}',
       ),
       _state = NativeLeagueFoundationState.initial((now ?? DateTime.now)());

  final LcuReadTransport client;
  final Future<GodSenseDatabase> Function() _databaseFactory;
  final DateTime Function() _now;
  final CaptureEpochId _captureEpochId;

  NativeLeagueFoundationState _state;
  GodSenseDatabase? _database;
  DriftJournalRepository? _journal;
  DriftAccountContextRepository? _accountRepository;
  AccountContextCoordinator? _accounts;
  LcuCapabilityProbe? _capabilityProbe;
  LiveClientJournalAdapter? _liveClientJournal;
  LocalScoutSyncService? _scoutSync;
  DriftLocalScoutRepository? _scoutRepository;
  LocalDataManager? _localData;
  TacticalAdviceJournalAdapter? _tacticalAdviceJournal;
  VisionJournalAdapter? _visionJournal;
  late final GameSessionCoordinator _sessions = GameSessionCoordinator(
    now: _now,
  );
  Future<void>? _scoutSyncRunning;
  bool _scoutSyncPending = false;
  Future<void>? _initializing;
  DateTime? _lastAccountSync;
  DateTime? _lastCapabilityProbe;
  DateTime? _lastScoutSyncAt;
  String? _lastScoutPuuid;
  String? _lastCapabilityContext;
  int _recordCounter = 0;
  int _transportGeneration = 0;
  CaptureEpochId? _activeCaptureEpochId;
  bool _wasConnected = false;
  bool _initialScoutSyncScheduled = false;
  String? _lastObservedGameflowPhase;
  bool _postGameScoutSyncPending = false;
  bool _disposed = false;
  final Map<String, String> _snapshotHashes = {};

  NativeLeagueFoundationState get state => _state;

  Future<LocalDataRetentionResult> applyLocalDataRetention() async {
    await _ensureInitialized();
    return _localData!.applyRetention(now: _now());
  }

  Future<File> exportLocalData(File destination) async {
    await _ensureInitialized();
    return _localData!.exportTo(destination);
  }

  Future<void> deleteAllLocalData() async {
    await _ensureInitialized();
    await _localData!.deleteAllUserData();
    _snapshotHashes.clear();
    _state = NativeLeagueFoundationState.initial(_now());
  }

  Future<List<LocalMatchRecord>> loadLocalMatches(
    Puuid puuid, {
    int limit = 20,
  }) async {
    await _ensureInitialized();
    if (_disposed) return const [];
    return _scoutRepository!.loadMatches(puuid, limit: limit);
  }

  Future<LocalRankedSnapshot?> loadLocalRanked(Puuid puuid) async {
    await _ensureInitialized();
    if (_disposed) return null;
    return _scoutRepository!.loadLatestRanked(puuid);
  }

  Future<LocalMatchRecord> loadScoutMatchDetails(
    LocalMatchRecord cached,
  ) async {
    await _ensureInitialized();
    if (_disposed) throw StateError('La conexión con League se ha cerrado.');
    final connected = _accounts?.state.context?.account;
    if (connected != null && connected.platformId != cached.match.platformId) {
      throw StateError(
        'Abre League en la región de esta partida para consultar sus detalles.',
      );
    }
    return _scoutSync!.loadMatchDetails(cached);
  }

  Future<LeagueAccountProfile> resolveAndSyncScout({
    required String gameName,
    required String tagLine,
    bool includeHistory = true,
  }) async {
    final account = await resolveScoutAccount(
      gameName: gameName,
      tagLine: tagLine,
    );
    await synchronizeScoutAccount(account, includeHistory: includeHistory);
    return account;
  }

  Future<LeagueAccountProfile> resolveScoutAccount({
    required String gameName,
    required String tagLine,
  }) async {
    await _ensureInitialized();
    final normalizedName = gameName.trim();
    final normalizedTag = tagLine.trim();
    if (normalizedName.isEmpty || normalizedTag.isEmpty) {
      throw const FormatException('Riot ID requires game name and tag line.');
    }
    final lookupQuery = Uri(
      queryParameters: {'gameName': normalizedName, 'tagLine': normalizedTag},
    ).query;
    final lookup = await client.getDetailed(
      '/lol-summoner/v1/alias/lookup?$lookupQuery',
    );
    final lookupBody = _foundationMap(lookup.body);
    final puuidValue = lookupBody['puuid']?.toString() ?? '';
    if (!lookup.isSuccess || puuidValue.isEmpty) {
      throw StateError('No se encontró $normalizedName#$normalizedTag en LCU.');
    }
    final summonerQuery = Uri(
      queryParameters: {'name': '$normalizedName#$normalizedTag'},
    ).query;
    final summoner = await client.getDetailed(
      '/lol-summoner/v1/summoners?$summonerQuery',
    );
    final summonerBody = _foundationMap(summoner.body);
    final connected = _accounts?.state.context?.account;
    final now = _now().toUtc();
    final account = LeagueAccountProfile(
      puuid: Puuid(puuidValue),
      platformId: connected?.platformId ?? PlatformId('LA1'),
      riotId: RiotId(gameName: normalizedName, tagLine: normalizedTag),
      summonerId: _foundationInt(summonerBody['summonerId']),
      summonerLevel: _foundationInt(summonerBody['summonerLevel']),
      profileIconId: _foundationInt(summonerBody['profileIconId']),
      clientVersion: connected?.clientVersion,
      patchKey: connected?.patchKey,
      firstSeenAt: now,
      lastSeenAt: now,
    );
    await _accountRepository!.saveKnownAccount(account);
    return account;
  }

  Future<LocalScoutSyncResult> synchronizeScoutAccount(
    LeagueAccountProfile account, {
    bool includeHistory = true,
    Future<void> Function(LocalScoutSyncProgress progress)? onProgress,
  }) async {
    await _ensureInitialized();
    final connected = _accounts?.state.context?.account;
    return _scoutSync!.synchronize(
      puuid: account.puuid,
      platformId: account.platformId,
      capabilities: _state.capabilities,
      currentAccountPuuid: connected?.puuid,
      includeHistory: includeHistory,
      onProgress: onProgress,
    );
  }

  Future<bool> recordTacticalAdvice({
    required String question,
    required TacticalAdvice advice,
  }) async {
    await _ensureInitialized();
    if (_disposed) return false;
    return _tacticalAdviceJournal!.ingest(
      question: question,
      advice: advice,
      session: _sessions.state.current,
    );
  }

  Future<bool> recordVisionObservation(VisionObservation observation) async {
    await _ensureInitialized();
    if (_disposed) return false;
    return _visionJournal!.ingest(
      observation,
      session: _sessions.state.current,
    );
  }

  Future<void> observeLiveClient({
    required Map<String, dynamic>? allGameData,
    int? gameId,
  }) async {
    try {
      await _ensureInitialized();
      if (_disposed) return;
      final account = _accounts!.state.context?.account;
      final gameData = allGameData?['gameData'];
      final gameTime = gameData is Map
          ? (gameData['gameTime'] as num?)?.toDouble()
          : null;
      final session = _sessions.observeLiveClient(
        available: allGameData != null,
        accountPuuid: account?.puuid,
        platformId: account?.platformId,
        gameId: gameId,
        gameTimeSeconds: gameTime,
      );
      final current = session.current;
      await _liveClientJournal!.ingest(
        allGameData: allGameData,
        match: current?.match,
        gameGeneration: current?.generation,
      );
      _state = NativeLeagueFoundationState(
        account: _state.account,
        capabilities: _state.capabilities,
        gameSession: session,
        lastScoutSync: _state.lastScoutSync,
        lastError: _state.lastError,
      );
    } catch (error) {
      _state = NativeLeagueFoundationState(
        account: _state.account,
        capabilities: _state.capabilities,
        gameSession: _sessions.state,
        lastError: error.toString(),
        lastScoutSync: _state.lastScoutSync,
      );
    }
  }

  Future<NativeLeagueFoundationState> observeLcu({
    required bool connected,
    required String gameflowPhase,
    Object? champSelectSession,
    int? gameId,
    bool forceAccountSync = false,
    bool forceCapabilityProbe = false,
  }) async {
    try {
      await _ensureInitialized();
      if (_disposed) return _state;
      final now = _now().toUtc();
      if (!connected) {
        if (_wasConnected) {
          _initialScoutSyncScheduled = false;
          _lastAccountSync = null;
        }
        _wasConnected = false;
        final account = _accounts!.markDisconnected('LCU is disconnected.');
        if (_lastCapabilityContext != 'disconnected') {
          await _refreshCapabilities(
            const LcuProbeContext(),
            now,
            contextKey: 'disconnected',
          );
        }
        return _state = NativeLeagueFoundationState(
          account: account,
          capabilities: _state.capabilities,
          gameSession: _sessions.state,
          lastScoutSync: _state.lastScoutSync,
        );
      }

      if (!_wasConnected) {
        _transportGeneration++;
        _activeCaptureEpochId = CaptureEpochId(
          '${_captureEpochId.value}-$_transportGeneration',
        );
        _wasConnected = true;
      }
      final previousPuuid = _accounts!.state.context?.account.puuid.value;
      if (forceAccountSync ||
          _lastAccountSync == null ||
          now.difference(_lastAccountSync!) >= _accountReconciliationInterval) {
        await _accounts!.synchronize();
        _lastAccountSync = now;
      }
      final account = _accounts!.state.context?.account;
      final accountChanged = previousPuuid != account?.puuid.value;
      final session = _sessions.observeLcu(
        connected: true,
        gameflowPhase: gameflowPhase,
        accountPuuid: account?.puuid,
        platformId: account?.platformId,
        gameId: gameId,
      );

      await _appendSnapshot(
        channel: 'gameflow',
        semanticKey: 'current-phase',
        payload: gameflowPhase,
        receivedAt: now,
        retention: RetentionClass.matchLifetime,
      );
      if (champSelectSession != null) {
        await _appendSnapshot(
          channel: 'champ-select',
          semanticKey: 'current-session',
          payload: champSelectSession,
          receivedAt: now,
          retention: RetentionClass.matchLifetime,
          gameId: gameId,
        );
      }

      final context = _accounts!.state.context;
      final capabilityContext = LcuProbeContext(
        puuid: context?.account.puuid.value,
        gameId: gameId,
        gameflowPhase: gameflowPhase,
        clientVersion: context?.account.clientVersion,
      );
      final capabilityPhase = gameflowPhase == 'ChampSelect'
          ? 'champ-select'
          : 'outside-champ-select';
      final contextKey = [
        context?.account.puuid.value,
        gameId,
        capabilityPhase,
        context?.account.clientVersion,
      ].join('|');
      if (forceCapabilityProbe ||
          _lastCapabilityProbe == null ||
          contextKey != _lastCapabilityContext ||
          now.difference(_lastCapabilityProbe!) >=
              _capabilityReconciliationInterval) {
        await _refreshCapabilities(
          capabilityContext,
          now,
          contextKey: contextKey,
        );
      }
      if (_lastObservedGameflowPhase == 'InProgress' &&
          gameflowPhase != 'InProgress') {
        _postGameScoutSyncPending = true;
      }
      _lastObservedGameflowPhase = gameflowPhase;
      final postGameDataReady =
          _postGameScoutSyncPending &&
          gameflowPhase != 'PreEndOfGame' &&
          gameflowPhase != 'WaitingForStats';
      if (!_initialScoutSyncScheduled || accountChanged || postGameDataReady) {
        final scheduled = _scheduleScoutSync(now, force: true);
        if (scheduled) {
          _initialScoutSyncScheduled = true;
          if (postGameDataReady) _postGameScoutSyncPending = false;
        }
      }
      return _state = NativeLeagueFoundationState(
        account: _accounts!.state,
        capabilities: _state.capabilities,
        gameSession: session,
        lastScoutSync: _state.lastScoutSync,
      );
    } catch (error) {
      return _state = NativeLeagueFoundationState(
        account: _state.account,
        capabilities: _state.capabilities,
        gameSession: _sessions.state,
        lastScoutSync: _state.lastScoutSync,
        lastError: error.toString(),
      );
    }
  }

  Future<void> _ensureInitialized() {
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    final database = await _databaseFactory();
    if (_disposed) {
      await database.close();
      return;
    }
    _database = database;
    _localData = LocalDataManager(database);
    await _localData!.applyRetention(now: _now());
    _journal = DriftJournalRepository(database);
    _tacticalAdviceJournal = TacticalAdviceJournalAdapter(
      repository: _journal!,
      now: _now,
      idPrefix: '${_captureEpochId.value}-coach',
    );
    _visionJournal = VisionJournalAdapter(
      repository: _journal!,
      idPrefix: '${_captureEpochId.value}-vision',
    );
    _liveClientJournal = LiveClientJournalAdapter(
      repository: _journal!,
      now: _now,
      idPrefix: '${_captureEpochId.value}-live',
    );
    final accountRepository = DriftAccountContextRepository(database);
    _accountRepository = accountRepository;
    _scoutRepository = DriftLocalScoutRepository(database);
    _scoutSync = LocalScoutSyncService(
      transport: client,
      repository: _scoutRepository!,
      now: _now,
      detailLimit: 5,
      detailConcurrency: 2,
    );
    _accounts = AccountContextCoordinator(
      source: LcuCurrentAccountSource(client: client, now: _now),
      repository: accountRepository,
      now: _now,
    );
    _capabilityProbe = LcuCapabilityProbe(transport: client, now: _now);
    await _accounts!.restore();
    _state = NativeLeagueFoundationState(
      account: _accounts!.state,
      capabilities: _state.capabilities,
      gameSession: _sessions.state,
      lastScoutSync: _state.lastScoutSync,
    );
  }

  Future<void> _refreshCapabilities(
    LcuProbeContext context,
    DateTime now, {
    required String contextKey,
  }) async {
    final capabilities = await _capabilityProbe!.probe(context);
    _lastCapabilityProbe = now;
    _lastCapabilityContext = contextKey;
    _state = NativeLeagueFoundationState(
      account: _accounts!.state,
      capabilities: capabilities,
      gameSession: _sessions.state,
      lastScoutSync: _state.lastScoutSync,
    );
  }

  bool _scheduleScoutSync(DateTime now, {bool force = false}) {
    final account = _accounts?.state.context?.account;
    if (account == null ||
        (!_state.capabilities.canLoadRanked &&
            !_state
                .capabilities[LcuCapabilityId.matchHistoryList]
                .isAvailable)) {
      return false;
    }
    if (_scoutSyncRunning != null) {
      _scoutSyncPending = true;
      return false;
    }
    final accountChanged = _lastScoutPuuid != account.puuid.value;
    if (!force &&
        !accountChanged &&
        _lastScoutSyncAt != null &&
        now.difference(_lastScoutSyncAt!) < const Duration(minutes: 2)) {
      return false;
    }
    _lastScoutSyncAt = now;
    _lastScoutPuuid = account.puuid.value;
    final running = _runScoutSync(account.puuid, account.platformId);
    _scoutSyncRunning = running;
    unawaited(
      running.whenComplete(() {
        _scoutSyncRunning = null;
        if (!_scoutSyncPending || _disposed) return;
        _scoutSyncPending = false;
        _scheduleScoutSync(_now().toUtc(), force: true);
      }),
    );
    return true;
  }

  Future<void> _runScoutSync(Puuid puuid, PlatformId platformId) async {
    try {
      final result = await _scoutSync!.synchronize(
        puuid: puuid,
        platformId: platformId,
        capabilities: _state.capabilities,
        currentAccountPuuid: _accounts?.state.context?.account.puuid,
      );
      if (_disposed || _accounts?.state.context?.account.puuid != puuid) return;
      _state = NativeLeagueFoundationState(
        account: _state.account,
        capabilities: _state.capabilities,
        gameSession: _sessions.state,
        lastScoutSync: result,
        lastError: _state.lastError,
      );
    } catch (error) {
      if (_disposed) return;
      _state = NativeLeagueFoundationState(
        account: _state.account,
        capabilities: _state.capabilities,
        gameSession: _sessions.state,
        lastScoutSync: _state.lastScoutSync,
        lastError: error.toString(),
      );
    }
  }

  Future<void> _appendSnapshot({
    required String channel,
    required String semanticKey,
    required Object? payload,
    required DateTime receivedAt,
    required RetentionClass retention,
    int? gameId,
  }) async {
    const codec = JournalPayloadCodec();
    final encoded = codec.encodeJson(payload);
    final account = _accounts!.state.context?.account;
    final snapshotKey =
        '${_activeCaptureEpochId?.value ?? _captureEpochId.value}|'
        '$channel|$semanticKey';
    if (_snapshotHashes[snapshotKey] == encoded.semanticHash) return;
    await _journal!.append(
      SourceRecordDraft(
        id: EntryId('${_captureEpochId.value}-${_recordCounter++}'),
        kind: JournalEntryKind.sourceSnapshot,
        source: SourceEnvelope(
          namespace: SourceNamespace(producer: 'lcu', channel: channel),
          transportGeneration: TransportGeneration(_transportGeneration),
          gameGeneration: _sessions.state.current?.generation,
          match: gameId == null
              ? _sessions.state.current?.match
              : account == null
              ? null
              : MatchKey(platformId: account.platformId, gameId: gameId),
          receivedAt: receivedAt,
        ),
        rawPayload: encoded.bytes,
        rawFormat: RawPayloadFormat.jsonUtf8,
        rawHash: encoded.rawHash,
        semanticHash: encoded.semanticHash,
        semanticKey: semanticKey,
        captureEpochId: _activeCaptureEpochId ?? _captureEpochId,
        retentionClass: retention,
      ),
    );
    _snapshotHashes[snapshotKey] = encoded.semanticHash;
  }

  Future<void> dispose() async {
    _disposed = true;
    final initializing = _initializing;
    if (initializing != null) await initializing;
    await _scoutSyncRunning;
    await _database?.close();
  }
}

Map<String, dynamic> _foundationMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

int? _foundationInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
