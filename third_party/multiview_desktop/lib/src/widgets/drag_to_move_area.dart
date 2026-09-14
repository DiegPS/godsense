import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../multi_view_desktop.dart';

/// Makes its child area draggable to move the current window.
///
/// Typically used on a custom title bar or another drag handle:
///
/// ```dart
/// DragToMoveArea(
///   child: SizedBox(
///     height: 32,
///     child: Text('My App'),
///   ),
/// )
/// ```
class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});

  /// Child widget that receives drag gestures to move the window.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.buttons & kPrimaryMouseButton == 0) return;
        MultiViewDesktop.of(context).startDragging();
      },
      child: child,
    );
  }
}
