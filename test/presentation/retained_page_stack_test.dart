import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/presentation/shell/retained_page_stack.dart';

void main() {
  testWidgets(
    'loads on demand and retains drafts, scroll and inactive tickers',
    (tester) async {
      final index = ValueNotifier(0);
      final text = TextEditingController();
      final focus = FocusNode();
      final scroll = ScrollController();
      addTearDown(index.dispose);
      addTearDown(text.dispose);
      addTearDown(focus.dispose);
      addTearDown(scroll.dispose);
      var secondPageBuilds = 0;
      final pages = <Widget>[
        Material(
          child: Column(
            children: [
              TextField(controller: text, focusNode: focus),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: const [SizedBox(height: 1800)],
                ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (_) {
            secondPageBuilds++;
            return const Text('Second page');
          },
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, selected, _) =>
                RetainedPageStack(index: selected, children: pages),
          ),
        ),
      );
      expect(secondPageBuilds, 0);
      await tester.enterText(find.byType(TextField), 'Unfinished question');
      scroll.jumpTo(250);
      await tester.pump();
      final originalPage = tester.element(find.byType(TextField));
      index.value = 1;
      await tester.pump();
      expect(find.text('Second page'), findsOneWidget);
      expect(focus.hasFocus, isFalse);
      final hiddenField = find.byType(TextField, skipOffstage: false);
      expect(TickerMode.valuesOf(tester.element(hiddenField)).enabled, isFalse);
      expect(find.byType(TextField), findsNothing);
      index.value = 0;
      await tester.pump();
      expect(tester.element(find.byType(TextField)), same(originalPage));
      expect(text.text, 'Unfinished question');
      expect(scroll.offset, 250);
      expect(TickerMode.valuesOf(originalPage).enabled, isTrue);
      expect(secondPageBuilds, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
