import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/presentation/coach/live/voice_coach_card.dart';

void main() {
  testWidgets(
    'requests instant advice and disables the action while processing',
    (tester) async {
      var requests = 0;
      Future<void> show({required bool processing}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceCoachCard(
              processing: processing,
              history: const [],
              onAdviceRequested: () => requests++,
            ),
          ),
        ),
      );
      await show(processing: false);
      await tester.tap(find.text('Consejo ahora'));
      expect(requests, 1);
      await show(processing: true);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Consejo ahora'));
      expect(requests, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
