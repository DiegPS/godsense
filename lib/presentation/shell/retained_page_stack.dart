import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';

class RetainedPageStack extends StatefulWidget {
  const RetainedPageStack({
    super.key,
    required this.index,
    required this.children,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;

  @override
  State<RetainedPageStack> createState() => _RetainedPageStackState();
}

class _RetainedPageStackState extends State<RetainedPageStack> {
  final _visited = <int>{};

  @override
  void didUpdateWidget(RetainedPageStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _visited.removeWhere((index) => index >= widget.children.length);
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final index in _visited)
          Offstage(
            key: ValueKey(index),
            offstage: index != widget.index,
            child: TickerMode(
              enabled: index == widget.index,
              child: ExcludeFocus(
                excluding: index != widget.index,
                child: _DeferredPageLayout(
                  active: index == widget.index,
                  child: RepaintBoundary(child: widget.children[index]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Offstage retains state and hides painting/semantics, but still lays out its
// child. Stop hidden-page layout at this boundary until the page is revisited.
class _DeferredPageLayout extends SingleChildRenderObjectWidget {
  const _DeferredPageLayout({required this.active, required super.child});
  final bool active;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDeferredPageLayout(active);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDeferredPageLayout renderObject,
  ) {
    renderObject.active = active;
  }
}

class _RenderDeferredPageLayout extends RenderProxyBox {
  _RenderDeferredPageLayout(this._active);
  bool _active;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (_active) {
      super.performLayout();
    } else {
      size = constraints.smallest;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _active ? super.computeDryLayout(constraints) : constraints.smallest;
}

// Retained pages keep their form state, but do not need live subscriptions while
// hidden. TickerMode makes this build run again on return and read fresh data.
class ActivePageWatch {
  ActivePageWatch(BuildContext context, this._ref)
    : _active = TickerMode.valuesOf(context).enabled;
  final WidgetRef _ref;
  final bool _active;
  T call<T>(ProviderListenable<T> provider) =>
      _active ? _ref.watch(provider) : _ref.read(provider);
}
