import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiview_desktop/src/app_shell/app_shell_registry.dart';
import 'package:multiview_desktop/src/shared_entry_app.dart';

void main() {
  testWidgets(
    'nested app shell stays synchronized through its cached element',
    (tester) async {
      final registry = AppShellRegistry();
      addTearDown(registry.dispose);

      await tester.pumpWidget(
        MainAppShellCapture(
          registry: registry,
          child: const _NestedApp(color: Colors.red),
        ),
      );
      await tester.pump();
      expect(registry.snapshot?.color, Colors.red);

      await tester.pumpWidget(
        MainAppShellCapture(
          registry: registry,
          child: const _NestedApp(color: Colors.blue),
        ),
      );
      await tester.pump();
      expect(registry.snapshot?.color, Colors.blue);
    },
  );
}

class _NestedApp extends StatelessWidget {
  const _NestedApp({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: MaterialApp(color: color, home: const SizedBox()),
  );
}
