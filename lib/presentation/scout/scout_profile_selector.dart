import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../application/native_league_controller.dart';
import '../../domain/league/account_context.dart';
import '../../domain/league/scout_selection_store.dart';
import '../shared/godsense_ui_components.dart';

class ScoutProfileSelector extends ConsumerWidget {
  const ScoutProfileSelector({super.key});

  static const _follow = (puuid: '', platform: '');
  static ScoutProfileKey _key(LeagueAccountProfile account) =>
      (puuid: account.puuid.value, platform: account.platformId.value);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scout = ref.watch(localScoutProvider);
    final controller = ref.read(localScoutProvider.notifier);
    final saved = ref.watch(savedScoutAccountsProvider);
    final connected = ref.watch(
      nativeLeagueProvider.select(
        (state) =>
            state.lcuConnected ? state.accountContext?.context?.account : null,
      ),
    );
    final accounts = <ScoutProfileKey, LeagueAccountProfile>{
      for (final account in saved.asData?.value ?? <LeagueAccountProfile>[])
        _key(account): account,
      if (scout.subjectAccount != null)
        _key(scout.subjectAccount!): scout.subjectAccount!,
    };
    final selected =
        controller.followsConnectedAccount || scout.subjectAccount == null
        ? _follow
        : _key(scout.subjectAccount!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GsSelect<ScoutProfileKey>(
          key: const Key('scout-profile-selector'),
          label: 'Perfil que consultas en Scout',
          value: selected,
          items: {
            _follow: 'Seguir la cuenta de League',
            for (final entry in accounts.entries)
              entry.key:
                  '${entry.value.riotId?.displayName ?? 'Perfil local'} · ${entry.value.platformId.value}',
          },
          onChanged: (key) {
            if (key == _follow) {
              controller.useConnectedAccount();
            } else {
              controller.selectSavedAccount(accounts[key]!);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          controller.followsConnectedAccount
              ? connected == null
                    ? 'Abre League para seguir su cuenta. También puedes consultar un perfil guardado sin conexión.'
                    : 'Scout seguirá los cambios de cuenta en League.'
              : 'Este perfil permanece seleccionado aunque cambies de cuenta en League. Sus datos guardados están disponibles sin conexión.',
        ),
        if (!controller.followsConnectedAccount &&
            connected != null &&
            _key(connected) != selected) ...[
          const SizedBox(height: 8),
          Text(
            'En League: ${connected.riotId?.displayName ?? 'Otra cuenta'} · ${connected.platformId.value}. Consultar este perfil no cambia esa sesión.',
          ),
        ],
        if (saved.hasError) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(savedScoutAccountsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text(
              'No se pudieron leer los perfiles guardados. Reintentar',
            ),
          ),
        ],
        if (scout.selectionError != null) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(scout.selectionError!)),
        ],
      ],
    );
  }
}
