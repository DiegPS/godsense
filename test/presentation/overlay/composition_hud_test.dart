import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/domain/companion_models.dart';

void main() {
  for (final width in [160.0, 240.0, 340.0]) {
    testWidgets('ten champion portraits fit composition HUD at width $width', (
      tester,
    ) async {
      final team = List.generate(
        5,
        (_) => {'champion_name': 'Ahri', 'role': 'JUNGLE'},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: EsportsCompositionHUD(
                  game: GameSnapshot.fromJson({
                    'game_time': 150.0,
                    'allies': team,
                    'enemies': team,
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('J'), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    });
  }
}
