part of '../../app/godsense_app.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(companionControllerProvider);
    final nativeLeague = ref.watch(nativeLeagueProvider);
    final game = ref.watch(effectiveGameProvider);
    final lobby = ref.watch(effectiveLobbyProvider);
    final coach = backend.localCoachHealth['opencode'];
    final coachMap = coach is Map ? coach : const {};
    final model = coachMap['model'];
    final modelMap = model is Map ? model : const {};
    final cv = backend.health?.components['cv'];
    final alerts = backend.alerts
        .where((alert) => alert.isVisibleAlert)
        .take(5);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatusCard(
              title: 'League client',
              value: game != null
                  ? 'In game · ${game.phase} · '
                        '${nativeLeague.lcuEventConnected ? 'eventos' : 'polling'}'
                  : lobby?.lcuConnected == true
                  ? '${lobby!.phase} · '
                        '${nativeLeague.lcuEventConnected ? 'eventos' : 'polling'}'
                  : 'Not connected',
              icon: Icons.sports_esports,
            ),
            _StatusCard(
              title: 'Live Client API',
              value: nativeLeague.liveApiConnected
                  ? '${nativeLeague.liveApiLatencyMilliseconds.toStringAsFixed(1)} ms · native'
                  : nativeLeague.inGame
                  ? 'Reconectando · ${nativeLeague.consecutiveLiveFailures} fallos'
                  : 'Esperando partida',
              icon: Icons.monitor_heart_outlined,
            ),
            _StatusCard(
              title: 'Local coach',
              value:
                  modelMap['name']?.toString() ??
                  coachMap['state']?.toString() ??
                  'Checking',
              icon: Icons.psychology,
            ),
            _StatusCard(
              title: 'Vision tracker',
              value: cv == null
                  ? 'Unavailable'
                  : cv.alive
                  ? 'Running'
                  : cv.error ?? 'Stopped',
              icon: Icons.visibility,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Current session', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  game == null
                      ? 'No active game'
                      : '${game.phase} · ${_formatGameTime(game.gameTime)}',
                ),
                subtitle: Text(
                  game == null
                      ? 'GodSense will start tracking when League game data is available.'
                      : '${game.allies.length} allies · ${game.enemies.length} enemies',
                ),
              ),
              const Divider(height: 1),
              if (alerts.isEmpty)
                const ListTile(
                  leading: Icon(Icons.notifications_none),
                  title: Text('No recent alerts'),
                  subtitle: Text('Live alerts arrive through /ws/alerts.'),
                )
              else
                for (final alert in alerts)
                  ListTile(
                    leading: Icon(
                      alert.kind == CompanionAlertKind.gank
                          ? Icons.warning_amber
                          : Icons.visibility,
                    ),
                    title: Text(alert.title),
                    subtitle: Text(alert.message),
                  ),
            ],
          ),
        ),
        if (backend.lastError != null) ...[
          const SizedBox(height: 12),
          Text(
            backend.lastError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value),
        ),
      ),
    );
  }
}
