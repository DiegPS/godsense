import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/presentation/shared/live_rank_badge.dart';

void main() {
  testWidgets('distinguishes rank loading, missing and unranked states', (
    tester,
  ) async {
    await tester.pumpWidget(liveRankBadgePreview());
    expect(find.text('Consultando rango…'), findsOneWidget);
    expect(find.text('Rango no disponible'), findsOneWidget);
    expect(find.text('Sin rango en Solo/Duo'), findsOneWidget);
    expect(find.text('GOLD II · 42 LP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rank remains readable with large text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: LiveRankBadge(
              profile: {
                'status': 'available',
                'tier': 'CHALLENGER',
                'lp': 1500,
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('CHALLENGER  · 1500 LP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
