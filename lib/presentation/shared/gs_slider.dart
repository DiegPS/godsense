import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'gs_tokens.dart';

// Material Slider in Flutter 3.47 creates an always-visible OverlayPortal.
// When its tab becomes offstage, it can send an orphan accessibility node and
// crash the Windows engine (flutter/flutter#190357, fixed upstream in #193372).
// Use the overlay-free Cupertino track while keeping keyboard and screen-reader
// controls. Remove this workaround once the minimum SDK contains that fix.
class GsSlider extends StatefulWidget {
  const GsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double>? onChanged;

  @override
  State<GsSlider> createState() => _GsSliderState();
}

class _AdjustSlider extends Intent {
  const _AdjustSlider(this.direction);
  final int direction;
}

class _GsSliderState extends State<GsSlider> {
  bool _focused = false;

  double _adjusted(int direction) =>
      (widget.value + direction * (widget.max - widget.min) / widget.divisions)
          .clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final reverse = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: widget.label,
      slider: true,
      enabled: enabled,
      value: widget.value.toStringAsFixed(2),
      increasedValue: _adjusted(1).toStringAsFixed(2),
      decreasedValue: _adjusted(-1).toStringAsFixed(2),
      onIncrease: enabled ? () => widget.onChanged!(_adjusted(1)) : null,
      onDecrease: enabled ? () => widget.onChanged!(_adjusted(-1)) : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.arrowRight): _AdjustSlider(
            reverse ? -1 : 1,
          ),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _AdjustSlider(
            reverse ? 1 : -1,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowUp):
              const _AdjustSlider(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _AdjustSlider(-1),
        },
        actions: {
          _AdjustSlider: CallbackAction<_AdjustSlider>(
            onInvoke: (intent) {
              widget.onChanged?.call(_adjusted(intent.direction));
              return null;
            },
          ),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: _focused ? GsColors.cyan : const Color(0x00000000),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CupertinoSlider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            activeColor: GsColors.cyan,
            thumbColor: GsColors.textPrimary,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
