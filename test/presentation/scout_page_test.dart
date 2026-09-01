import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/local_scout_controller.dart';

void main() {
  testWidgets('explains the offline state when no account is available', (
    tester,
  ) async {
    await tester.pumpWidget(_scoutApp(const LocalScoutState()));

    expect(find.text('Scout local'), findsOneWidget);
    expect(find.text('Conecta una cuenta de League'), findsOneWidget);
    expect(find.byTooltip('Actualizar historial local'), findsOneWidget);
  });

  testWidgets('renders cached rank and match data', (tester) async {
    await tester.pumpWidget(
      _scoutApp(
        const LocalScoutState(
          profile: {
            'game_name': 'Diego',
            'tag_line': 'LAN',
            'rank': {'tier': 'GOLD', 'division': 'II', 'lp': 64, 'winrate': 60},
          },
          matches: [
            {
              'match_id': 123,
              'result': 'Victoria',
              'champion': {'name': 'Ashe'},
              'kills': 8,
              'deaths': 2,
              'assists': 11,
              'role': 'BOTTOM',
              'csm': 0,
            },
          ],
        ),
      ),
    );

    expect(find.text('Diego#LAN'), findsOneWidget);
    expect(find.textContaining('GOLD II'), findsOneWidget);
    expect(find.textContaining('Ashe · Victoria'), findsOneWidget);
    expect(find.byTooltip('Abrir detalle de partida'), findsOneWidget);
  });
}

Widget _scoutApp(LocalScoutState state) {
  return ProviderScope(
    overrides: [
      localScoutProvider.overrideWith(
        (_) => LocalScoutController(
          loadMatches: (_, {limit = 20}) async => const [],
          loadRanked: (_) async => null,
          initialState: state,
        ),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: ScoutPage())),
  );
}
