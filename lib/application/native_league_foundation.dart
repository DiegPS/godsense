import 'dart:async';
import 'dart:io';

import '../domain/identity/league_identity.dart';
import '../domain/journal/journal_models.dart';
import '../domain/league/game_session.dart';
import '../domain/league/lcu_capabilities.dart';
import '../domain/league/local_scout.dart';
import '../infrastructure/league/lcu_capability_probe.dart';
import '../infrastructure/league/lcu_current_account_source.dart';
import '../infrastructure/league/lcu_probe_transport.dart';
import '../infrastructure/persistence/drift_account_context_repository.dart';
import '../infrastructure/persistence/drift_journal_repository.dart';
import '../infrastructure/persistence/drift_local_scout_repository.dart';
import '../infrastructure/persistence/godsense_database.dart'
    hide AccountContextState;
import '../infrastructure/persistence/journal_payload_codec.dart';
import 'account_context_coordinator.dart';
import 'game_session_coordinator.dart';
import 'live_client_journal_adapter.dart';
import 'local_scout_sync_service.dart';

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
  AccountContextCoordinator? _accounts;
  LcuCapabilityProbe? _capabilityProbe;
  LiveClientJournalAdapter? _liveClientJournal;
  LocalScoutSyncService? _scoutSync;
  late final GameSessionCoordinator _sessions = GameSessionCoordinator(
    now: _now,
  );
  Future<void>? _scoutSyncRunning;
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
  bool _disposed = false;

  NativeLeagueFoundationState get state => _state;

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
  }) async {
    try {
      await _ensureInitialized();
      if (_disposed) return _state;
      final now = _now().toUtc();
      if (!connected) {
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
      if (_lastAccountSync == null ||
          now.difference(_lastAccountSync!) >= const Duration(seconds: 5)) {
        await _accounts!.synchronize();
        _lastAccountSync = now;
      }
      final account = _accounts!.state.context?.account;
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
      final contextKey = [
        context?.account.puuid.value,
        gameId,
        gameflowPhase,
        context?.account.clientVersion,
      ].join('|');
      if (_lastCapabilityProbe == null ||
          contextKey != _lastCapabilityContext ||
          now.difference(_lastCapabilityProbe!) >=
              const Duration(seconds: 30)) {
        await _refreshCapabilities(
          capabilityContext,
          now,
          contextKey: contextKey,
        );
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
    _journal = DriftJournalRepository(database);
    _liveClientJournal = LiveClientJournalAdapter(
      repository: _journal!,
      now: _now,
      idPrefix: '${_captureEpochId.value}-live',
    );
    final accountRepository = DriftAccountContextRepository(database);
    _scoutSync = LocalScoutSyncService(
      transport: client,
      repository: DriftLocalScoutRepository(database),
      now: _now,
      detailLimit: 5,
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
    _scheduleScoutSync(now);
  }

  void _scheduleScoutSync(DateTime now) {
    final account = _accounts?.state.context?.account;
    if (account == null ||
        _scoutSyncRunning != null ||
        (!_state.capabilities.canLoadRanked &&
            !_state
                .capabilities[LcuCapabilityId.matchHistoryList]
                .isAvailable)) {
      return;
    }
    final accountChanged = _lastScoutPuuid != account.puuid.value;
    if (!accountChanged &&
        _lastScoutSyncAt != null &&
        now.difference(_lastScoutSyncAt!) < const Duration(minutes: 2)) {
      return;
    }
    _lastScoutSyncAt = now;
    _lastScoutPuuid = account.puuid.value;
    final running = _runScoutSync(account.puuid, account.platformId);
    _scoutSyncRunning = running;
    unawaited(running.whenComplete(() => _scoutSyncRunning = null));
  }

  Future<void> _runScoutSync(Puuid puuid, PlatformId platformId) async {
    try {
      final result = await _scoutSync!.synchronize(
        puuid: puuid,
        platformId: platformId,
        capabilities: _state.capabilities,
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
  }

  Future<void> dispose() async {
    _disposed = true;
    final initializing = _initializing;
    if (initializing != null) await initializing;
    await _scoutSyncRunning;
    await _database?.close();
  }
}
