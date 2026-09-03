part of '../../app/godsense_app.dart';

/// GodSense Unified Design System Tokens
abstract class GsColors {
  static const canvas = Color(0xFF080B10);
  static const surface = Color(0xFF0F141D);
  static const surfaceElevated = Color(0xFF151C28);
  static const surfaceHover = Color(0xFF1C2433);

  static const border = Color(0xFF1E293B);
  static const borderInteractive = Color(0x3338BDF8);
  static const borderActive = Color(0x8038BDF8);

  static const cyan = Color(0xFF38BDF8);
  static const cyanGlow = Color(0x1F38BDF8);
  static const cyanLight = Color(0xFFE0F2FE);

  static const emerald = Color(0xFF10B981);
  static const emeraldGlow = Color(0x1F10B981);

  static const crimson = Color(0xFFEF4444);
  static const crimsonGlow = Color(0x1FEF4444);

  static const amber = Color(0xFFF59E0B);
  static const amberGlow = Color(0x1FF59E0B);

  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFFAAB8CA);
  static const textMuted = Color(0xFF8B9BB0);
}

/// Standard Sizing Tokens for Controls across GodSense
abstract class GsSizes {
  /// Standard control height for desktop form controls (buttons, inputs, selects, icon buttons)
  static const double controlHeight = 36.0;

  /// Compact control height for dense toolbars, table actions, inline chips
  static const double controlHeightCompact = 30.0;

  /// Large control height for prominent CTA buttons or hero search inputs
  static const double controlHeightLarge = 42.0;

  /// Standard border radius across all controls
  static const double radius = 6.0;
}

/// Standardized Obsidian Card Container
class GsCard extends StatelessWidget {
  const GsCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(16),
    this.elevation = 0,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || icon != null || action != null;

    return Material(
      color: backgroundColor ?? GsColors.surface,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: GsColors.cyan),
                    const SizedBox(width: 10),
                  ],
                  if (title != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: GsColors.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: GsColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  ?action,
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Button Variants
enum GsButtonVariant { primary, secondary, ghost, danger }

/// Unified Action Button
class GsButton extends StatefulWidget {
  const GsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = GsButtonVariant.primary,
    this.loading = false,
    this.compact = false,
    this.height,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GsButtonVariant variant;
  final bool loading;
  final bool compact;
  final double? height;

  @override
  State<GsButton> createState() => _GsButtonState();
}

class _GsButtonState extends State<GsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    Color bg;
    Color border;
    Color fg;

    switch (widget.variant) {
      case GsButtonVariant.primary:
        bg = enabled
            ? (_hovered ? const Color(0xFF0284C7) : const Color(0xFF0369A1))
            : const Color(0xFF1E293B);
        border = enabled
            ? (_hovered ? GsColors.cyan : const Color(0x6638BDF8))
            : Colors.transparent;
        fg = enabled ? Colors.white : GsColors.textMuted;
        break;
      case GsButtonVariant.secondary:
        bg = enabled
            ? (_hovered ? GsColors.surfaceHover : GsColors.surfaceElevated)
            : GsColors.surface;
        border = enabled
            ? (_hovered ? GsColors.cyan : GsColors.border)
            : GsColors.border;
        fg = enabled ? GsColors.textPrimary : GsColors.textMuted;
        break;
      case GsButtonVariant.ghost:
        bg = enabled
            ? (_hovered ? GsColors.surfaceHover : Colors.transparent)
            : Colors.transparent;
        border = Colors.transparent;
        fg = enabled
            ? (_hovered ? GsColors.cyan : GsColors.textSecondary)
            : GsColors.textMuted;
        break;
      case GsButtonVariant.danger:
        bg = enabled
            ? (_hovered ? const Color(0xFFDC2626) : const Color(0xFF991B1B))
            : const Color(0xFF1E293B);
        border = enabled
            ? (_hovered ? GsColors.crimson : const Color(0x66EF4444))
            : Colors.transparent;
        fg = enabled ? Colors.white : GsColors.textMuted;
        break;
    }

    final double targetHeight =
        widget.height ?? (widget.compact ? GsSizes.controlHeightCompact : GsSizes.controlHeight);
    final double iconSize = widget.compact ? 13.0 : 15.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: targetHeight,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(GsSizes.radius),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.loading) ...[
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: iconSize, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.compact ? 12.5 : 13.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standardized Icon Button matching GsButton sizing and styling tokens
class GsIconButton extends StatefulWidget {
  const GsIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size,
    this.iconSize = 16.0,
    this.variant = GsButtonVariant.secondary,
    this.compact = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double? size;
  final double iconSize;
  final GsButtonVariant variant;
  final bool compact;
  final Color? color;

  @override
  State<GsIconButton> createState() => _GsIconButtonState();
}

class _GsIconButtonState extends State<GsIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    Color bg;
    Color border;
    Color fg;

    switch (widget.variant) {
      case GsButtonVariant.primary:
        bg = enabled
            ? (_hovered ? const Color(0xFF0284C7) : const Color(0xFF0369A1))
            : const Color(0xFF1E293B);
        border = enabled
            ? (_hovered ? GsColors.cyan : const Color(0x6638BDF8))
            : Colors.transparent;
        fg = enabled ? Colors.white : GsColors.textMuted;
        break;
      case GsButtonVariant.secondary:
        bg = enabled
            ? (_hovered ? GsColors.surfaceHover : const Color(0xFF0F172A))
            : GsColors.surface;
        border = enabled
            ? (_hovered ? GsColors.cyan : const Color(0x1FFFFFFF))
            : const Color(0x1FFFFFFF);
        fg = enabled ? (widget.color ?? GsColors.cyan) : GsColors.textMuted;
        break;
      case GsButtonVariant.ghost:
        bg = enabled
            ? (_hovered ? GsColors.surfaceHover : Colors.transparent)
            : Colors.transparent;
        border = Colors.transparent;
        fg = enabled
            ? (_hovered ? GsColors.cyan : GsColors.textSecondary)
            : GsColors.textMuted;
        break;
      case GsButtonVariant.danger:
        bg = enabled
            ? (_hovered ? const Color(0xFFDC2626) : const Color(0xFF991B1B))
            : const Color(0xFF1E293B);
        border = enabled
            ? (_hovered ? GsColors.crimson : const Color(0x66EF4444))
            : Colors.transparent;
        fg = enabled ? Colors.white : GsColors.textMuted;
        break;
    }

    final targetSize = widget.size ??
        (widget.compact ? GsSizes.controlHeightCompact : GsSizes.controlHeight);

    Widget content = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: targetSize,
          height: targetSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(GsSizes.radius),
            border: Border.all(color: border, width: 1),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: fg,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}

/// Standardized Single-Line Text Input matching GsButton, GsSelect, GsIconButton
class GsInput extends StatelessWidget {
  const GsInput({
    super.key,
    this.controller,
    this.hintText,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.height,
    this.compact = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofocus = false,
    this.style,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final double? width;
  final double? height;
  final bool compact;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final targetHeight = height ??
        (compact ? GsSizes.controlHeightCompact : GsSizes.controlHeight);
    final fontSize = compact ? 12.0 : 13.0;

    return SizedBox(
      width: width,
      height: targetHeight,
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: style ??
            TextStyle(
              fontSize: fontSize,
              color: GsColors.textPrimary,
            ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: fontSize,
            color: GsColors.textMuted,
          ),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: GsColors.cyan,
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 15, color: GsColors.textSecondary)
              : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GsSizes.radius),
            borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GsSizes.radius),
            borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GsSizes.radius),
            borderSide: const BorderSide(color: GsColors.cyan),
          ),
        ),
      ),
    );
  }
}

/// Sleek Custom Toggle Switch with Fixed Dimensions
class GsToggleSwitch extends StatelessWidget {
  const GsToggleSwitch({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: value ? GsColors.cyan : GsColors.textMuted,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? GsColors.textPrimary
                          : GsColors.textMuted,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: GsColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: value ? GsColors.cyan : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed Dimension Pill Toggle (e.g. for GTCRN noise reduction, audio switches)
class GsPillToggle extends StatelessWidget {
  const GsPillToggle({
    super.key,
    required this.label,
    required this.selected,
    required this.onToggle,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onToggle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? GsColors.cyanGlow : GsColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? GsColors.borderActive : GsColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? GsColors.cyan : GsColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? GsColors.cyan : GsColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GsColors.cyan : GsColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Styled Dark Dropdown Selector
class GsSelect<T> extends StatelessWidget {
  const GsSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width,
    this.height,
    this.compact = false,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;
  final String? label;
  final double? width;
  final double? height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final targetHeight = height ??
        (compact ? GsSizes.controlHeightCompact : GsSizes.controlHeight);

    final content = Container(
      height: targetHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(GsSizes.radius),
        border: Border.all(
          color: enabled ? const Color(0x2EFFFFFF) : const Color(0x14FFFFFF),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: compact ? 16 : 18,
            color: enabled ? const Color(0xFF38BDF8) : GsColors.textMuted,
          ),
          dropdownColor: const Color(0xFF0F172A),
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled ? GsColors.textPrimary : GsColors.textMuted,
          ),
          items: items.entries.map((entry) {
            return DropdownMenuItem<T>(
              value: entry.key,
              child: Text(
                entry.value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (val) => val != null ? onChanged!(val) : null
              : null,
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Tooltip(message: items[value] ?? '', child: content),
        ],
      ),
    );
  }
}

/// Status Badge Pill
enum GsBadgeVariant { success, danger, warning, info, neutral }

class GsBadge extends StatelessWidget {
  const GsBadge({
    super.key,
    required this.label,
    this.variant = GsBadgeVariant.neutral,
    this.icon,
    this.dot = true,
  });

  final String label;
  final GsBadgeVariant variant;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;

    switch (variant) {
      case GsBadgeVariant.success:
        bg = GsColors.emeraldGlow;
        border = const Color(0x4D10B981);
        fg = GsColors.emerald;
        break;
      case GsBadgeVariant.danger:
        bg = GsColors.crimsonGlow;
        border = const Color(0x4DEF4444);
        fg = GsColors.crimson;
        break;
      case GsBadgeVariant.warning:
        bg = GsColors.amberGlow;
        border = const Color(0x4DF59E0B);
        fg = GsColors.amber;
        break;
      case GsBadgeVariant.info:
        bg = GsColors.cyanGlow;
        border = const Color(0x4D38BDF8);
        fg = GsColors.cyan;
        break;
      case GsBadgeVariant.neutral:
        bg = const Color(0x0DFFFFFF);
        border = GsColors.border;
        fg = GsColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Metric Stat Widget
class GsMetricStat extends StatelessWidget {
  const GsMetricStat({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: GsColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: GsColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valueColor ?? GsColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12, color: GsColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// System Health & Diagnostics Matrix
class GsHealthMatrix extends StatelessWidget {
  const GsHealthMatrix({super.key, required this.components});

  final Map<String, ({bool alive, String? latency, String? error})> components;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: components.entries.map((entry) {
        final name = entry.key;
        final info = entry.value;
        final isAlive = info.alive;

        return Container(
          width: 175,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: GsColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAlive
                  ? const Color(0x2610B981)
                  : const Color(0x33EF4444),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAlive ? GsColors.emerald : GsColors.crimson,
                  boxShadow: isAlive
                      ? const [
                          BoxShadow(color: Color(0x8010B981), blurRadius: 4),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: GsColors.textPrimary,
                      ),
                    ),
                    Text(
                      isAlive
                          ? (info.latency ?? 'Listo')
                          : (info.error ?? 'Requiere atención'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isAlive ? GsColors.emerald : GsColors.crimson,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
