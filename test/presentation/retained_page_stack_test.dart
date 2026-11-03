import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:godsense/presentation/shell/retained_page_stack.dart';

final _liveCounter = StateProvider<int>((ref) => 0);

void main() {
  testWidgets(
    'hidden retained page pauses live rebuilds and catches up on return',
    (tester) async {
      final container = ProviderContainer();
      final index = ValueNotifier(0);
      addTearDown(container.dispose);
      addTearDown(index.dispose);
      var builds = 0;
      final pages = [
        Consumer(
          builder: (context, ref, _) {
            final value = ActivePageWatch(context, ref)(_liveCounter);
            builds++;
            return Text('Live $value');
          },
        ),
        const Text('Other page'),
      ];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (_, selected, _) =>
                  RetainedPageStack(index: selected, children: pages),
            ),
          ),
        ),
      );
      container.read(_liveCounter.notifier).state = 1;
      await tester.pump();
      expect(find.text('Live 1'), findsOneWidget);
      index.value = 1;
      await tester.pump();
      final hiddenBuilds = builds;
      for (var value = 2; value <= 10; value++) {
        container.read(_liveCounter.notifier).state = value;
        await tester.pump();
      }
      expect(builds, hiddenBuilds);
      index.value = 0;
      await tester.pump();
      expect(find.text('Live 10'), findsOneWidget);
    },
  );

  testWidgets(
    'hidden pages defer resize layout and show the latest data on return',
    (tester) async {
      final index = ValueNotifier(0);
      final width = ValueNotifier(500.0);
      final hiddenText = ValueNotifier('original');
      addTearDown(index.dispose);
      addTearDown(width.dispose);
      addTearDown(hiddenText.dispose);
      final layouts = <double>[];
      final pages = [
        ValueListenableBuilder<String>(
          valueListenable: hiddenText,
          builder: (_, text, _) => LayoutBuilder(
            builder: (_, constraints) {
              layouts.add(constraints.maxWidth);
              return Text(text);
            },
          ),
        ),
        const Text('Visible page'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: width,
              builder: (_, value, _) => SizedBox(
                width: value,
                height: 400,
                child: ValueListenableBuilder<int>(
                  valueListenable: index,
                  builder: (_, selected, _) =>
                      RetainedPageStack(index: selected, children: pages),
                ),
              ),
            ),
          ),
        ),
      );
      expect(layouts, [500]);
      index.value = 1;
      await tester.pump();
      final beforeResize = layouts.length;
      width.value = 420;
      await tester.pump();
      expect(
        layouts.length,
        beforeResize,
        reason: 'Resizing must not lay out retained hidden pages.',
      );
      hiddenText.value = 'latest data';
      await tester.pump();
      // Hidden widgets may still receive their own data updates. Those must not
      // make subsequent window resizes lay out the hidden subtree again.
      final afterDataUpdate = layouts.length;
      width.value = 360;
      await tester.pump();
      expect(
        layouts.length,
        afterDataUpdate,
        reason: 'An inactive page must not perform layout on window changes.',
      );
      expect(find.text('latest data'), findsNothing);
      index.value = 0;
      await tester.pump();
      expect(layouts.last, 360);
      expect(find.text('latest data'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
