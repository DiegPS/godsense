import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/presentation/coach/shared/ai_model_selector.dart';

import '../../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;
import '../../support/ai_models.dart';

void main() {
  testWidgets(
    'provider and searchable model selector update the shared selection',
    (tester) async {
      final controller = ReadyModelSelection();
      final supervisor = FakeSupervisor();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (ref) => Stream.value(supervisor.state),
            ),
            aiModelSelectionProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(24),
                child: AiModelSelector(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Proveedor de modelos'), findsWidgets);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Premium');
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Premium\npaid-model · Costo según proveedor').last,
      );
      await tester.pumpAndSettle();
      expect(controller.state.selected, paidModel);
      expect(find.textContaining('puede consumir saldo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
