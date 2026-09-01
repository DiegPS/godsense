import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/account_context_coordinator.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';

void main() {
  test('restores the last account while remaining offline', () async {
    final stored = _context('account-a', generation: 3, revision: 8);
    final coordinator = AccountContextCoordinator(
      source: _QueueAccountSource(),
      repository: _MemoryAccountRepository(stored),
    );

    final state = await coordinator.restore();

    expect(state.status, AccountContextStatus.disconnected);
    expect(state.context?.account.puuid.value, 'account-a');
    expect(state.syncRevision, 8);
  });

  test(
    'keeps generation for refresh and increments it on PUUID switch',
    () async {
      final source = _QueueAccountSource()
        ..enqueue(CurrentAccountResult.connected(_account('account-a')))
        ..enqueue(CurrentAccountResult.connected(_account('account-a')))
        ..enqueue(CurrentAccountResult.connected(_account('account-b')));
      final coordinator = AccountContextCoordinator(
        source: source,
        repository: _MemoryAccountRepository(),
        now: () => DateTime.utc(2026, 9, 1),
      );

      expect((await coordinator.synchronize()).context?.accountGeneration, 1);
      expect((await coordinator.synchronize()).context?.accountGeneration, 1);
      final switched = await coordinator.synchronize();
      expect(switched.context?.account.puuid.value, 'account-b');
      expect(switched.context?.accountGeneration, 2);
    },
  );

  test('retains account context when LCU disconnects', () async {
    final source = _QueueAccountSource()
      ..enqueue(CurrentAccountResult.connected(_account('account-a')))
      ..enqueue(const CurrentAccountResult.disconnected('restart'));
    final coordinator = AccountContextCoordinator(
      source: source,
      repository: _MemoryAccountRepository(),
    );
    await coordinator.synchronize();

    final disconnected = await coordinator.synchronize();

    expect(disconnected.status, AccountContextStatus.disconnected);
    expect(disconnected.context?.account.puuid.value, 'account-a');
    expect(disconnected.lastError, 'restart');
  });

  test(
    'does not publish a late response from the previous account request',
    () async {
      final source = _CompleterAccountSource();
      final repository = _MemoryAccountRepository();
      final coordinator = AccountContextCoordinator(
        source: source,
        repository: repository,
      );

      final first = coordinator.synchronize();
      final second = coordinator.synchronize();
      source.completers[1].complete(
        CurrentAccountResult.connected(_account('account-b')),
      );
      await second;
      source.completers[0].complete(
        CurrentAccountResult.connected(_account('account-a')),
      );
      await first;

      expect(coordinator.state.context?.account.puuid.value, 'account-b');
      expect(repository.active?.account.puuid.value, 'account-b');
    },
  );
}

LeagueAccountProfile _account(String puuid) {
  return LeagueAccountProfile(
    puuid: Puuid(puuid),
    platformId: PlatformId('LA1'),
    firstSeenAt: DateTime.utc(2026, 9, 1),
    lastSeenAt: DateTime.utc(2026, 9, 1),
  );
}

AccountContext _context(
  String puuid, {
  required int generation,
  required int revision,
}) {
  return AccountContext(
    account: _account(puuid),
    accountGeneration: generation,
    syncRevision: revision,
    activatedAt: DateTime.utc(2026, 9, 1),
  );
}

class _QueueAccountSource implements CurrentAccountSource {
  final List<CurrentAccountResult> _results = [];

  void enqueue(CurrentAccountResult result) => _results.add(result);

  @override
  Future<CurrentAccountResult> loadCurrentAccount() async =>
      _results.removeAt(0);
}

class _CompleterAccountSource implements CurrentAccountSource {
  final List<Completer<CurrentAccountResult>> completers = [];

  @override
  Future<CurrentAccountResult> loadCurrentAccount() {
    final completer = Completer<CurrentAccountResult>();
    completers.add(completer);
    return completer.future;
  }
}

class _MemoryAccountRepository implements AccountContextRepository {
  _MemoryAccountRepository([this.active]);

  AccountContext? active;

  @override
  Future<bool> activate(AccountContext context) async {
    if ((active?.syncRevision ?? -1) > context.syncRevision) return false;
    active = context;
    return true;
  }

  @override
  Future<AccountContext?> loadActive() async => active;

  @override
  Future<List<LeagueAccountProfile>> loadAllAccounts() async =>
      active == null ? [] : [active!.account];
}
