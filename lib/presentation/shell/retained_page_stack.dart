import 'package:flutter/widgets.dart';

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
                child: RepaintBoundary(child: widget.children[index]),
              ),
            ),
          ),
      ],
    );
  }
}
