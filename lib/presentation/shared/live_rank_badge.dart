import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class LiveRankBadge extends StatelessWidget {
  const LiveRankBadge({super.key, required this.profile});

  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final status = profile?['status'];
    if (status == 'loading') return const Text('Consultando rango…');
    if (status != 'available') return const Text('Rango no disponible');
    final tier = profile?['tier']?.toString() ?? 'UNRANKED';
    final label = tier == 'UNRANKED' || tier == 'NONE'
        ? 'Sin rango en Solo/Duo'
        : '$tier ${profile?['division'] ?? ''} · ${profile?['lp'] ?? 0} LP';
    return Tooltip(
      message: 'Solo/Duo · LCU · ${profile?['observed_at'] ?? ''}',
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

@Preview(name: 'Live rank states', size: Size(340, 180))
Widget liveRankBadgePreview() => const MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveRankBadge(profile: {'status': 'loading'}),
          LiveRankBadge(profile: null),
          LiveRankBadge(profile: {'status': 'available', 'tier': 'UNRANKED'}),
          LiveRankBadge(
            profile: {
              'status': 'available',
              'tier': 'GOLD',
              'division': 'II',
              'lp': 42,
            },
          ),
        ],
      ),
    ),
  ),
);
