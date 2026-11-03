import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';
import 'package:godsense/app/godsense_theme.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/presentation/coach/shared/ai_model_selector.dart';

import '../../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;
import '../../support/ai_models.dart';

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('themed model disclosure and painted fields agree at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final supervisor = FakeSupervisor();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (_) => Stream.value(supervisor.state),
            ),
            aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
          ],
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: UiDisclosure(
                  title: Text('Proveedor y modelo'),
                  children: [AiModelSelector()],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
      expect(
        tile.collapsedBackgroundColor,
        godsenseTheme().colorScheme.surface,
      );
      expect(tile.shape, isA<RoundedRectangleBorder>());
      await tester.tap(find.text('Proveedor y modelo'));
      await tester.pumpAndSettle();
      final providerBorder = InputDecorator.containerOf(
        tester.element(find.text('Proveedor').first),
      )!;
      final modelBorder = InputDecorator.containerOf(
        tester.element(find.text('Modelo').first),
      )!;
      expect(providerBorder.size.height, closeTo(modelBorder.size.height, 1));
      expect(tester.takeException(), isNull);
    });
  }
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
      expect(find.text('Proveedor'), findsWidgets);
      expect(find.textContaining('Motor activo:'), findsNothing);
      expect(find.textContaining('Se usará:'), findsNothing);
      expect(find.byTooltip('Actualizar modelos'), findsOneWidget);
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
      expect(find.textContaining('Se usará:'), findsNothing);
      expect(find.textContaining('puede consumir saldo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
