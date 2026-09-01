import '../domain/league/account_context.dart';

enum AccountContextStatus {
  restoring,
  disconnected,
  connectedWithoutAccount,
  ready,
}

class AccountContextState {
  const AccountContextState({
    required this.status,
    required this.syncRevision,
    this.context,
    this.lastError,
  });

  const AccountContextState.initial()
    : status = AccountContextStatus.restoring,
      syncRevision = 0,
      context = null,
      lastError = null;

  final AccountContextStatus status;
  final int syncRevision;
  final AccountContext? context;
  final String? lastError;

  bool get lcuConnected =>
      status == AccountContextStatus.connectedWithoutAccount ||
      status == AccountContextStatus.ready;
}

class AccountContextCoordinator {
  AccountContextCoordinator({
    required this.source,
    required this.repository,
    DateTime Function()? now,
    this.onStateChanged,
  }) : _now = now ?? DateTime.now;

  final CurrentAccountSource source;
  final AccountContextRepository repository;
  final DateTime Function() _now;
  final void Function(AccountContextState)? onStateChanged;

  AccountContextState _state = const AccountContextState.initial();
  int _operationRevision = 0;

  AccountContextState get state => _state;

  Future<AccountContextState> restore() async {
    final restored = await repository.loadActive();
    if (restored == null) {
      return _emit(
        const AccountContextState(
          status: AccountContextStatus.disconnected,
          syncRevision: 0,
        ),
      );
    }
    _operationRevision = restored.syncRevision;
    return _emit(
      AccountContextState(
        status: AccountContextStatus.disconnected,
        syncRevision: restored.syncRevision,
        context: restored,
      ),
    );
  }

  Future<AccountContextState> synchronize() async {
    final revision = ++_operationRevision;
    final result = await source.loadCurrentAccount();
    if (revision != _operationRevision) return _state;

    if (result.connection == AccountSourceConnection.disconnected) {
      return _emit(
        AccountContextState(
          status: AccountContextStatus.disconnected,
          syncRevision: revision,
          context: _state.context,
          lastError: result.error,
        ),
      );
    }

    final account = result.account;
    if (account == null) {
      return _emit(
        AccountContextState(
          status: AccountContextStatus.connectedWithoutAccount,
          syncRevision: revision,
          context: _state.context,
          lastError: result.error,
        ),
      );
    }

    final previous = _state.context;
    final switched =
        previous == null || previous.account.puuid != account.puuid;
    final context = AccountContext(
      account: account,
      accountGeneration: switched
          ? (previous?.accountGeneration ?? 0) + 1
          : previous.accountGeneration,
      syncRevision: revision,
      activatedAt: switched ? _now().toUtc() : previous.activatedAt,
    );
    final applied = await repository.activate(context);
    if (!applied || revision != _operationRevision) return _state;
    return _emit(
      AccountContextState(
        status: AccountContextStatus.ready,
        syncRevision: revision,
        context: context,
      ),
    );
  }

  AccountContextState markDisconnected([String? error]) {
    _operationRevision++;
    return _emit(
      AccountContextState(
        status: AccountContextStatus.disconnected,
        syncRevision: _operationRevision,
        context: _state.context,
        lastError: error,
      ),
    );
  }

  AccountContextState _emit(AccountContextState next) {
    _state = next;
    onStateChanged?.call(next);
    return next;
  }
}
