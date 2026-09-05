import 'package:flutter/material.dart';

import 'gs_tokens.dart';
export 'gs_tokens.dart';

class GsSectionHeading extends StatelessWidget {
  const GsSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.page = false,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final bool page;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final heading = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GsColors.cyanGlow,
                borderRadius: BorderRadius.circular(GsSizes.radius),
              ),
              child: ExcludeSemantics(
                child: Icon(icon, size: 20, color: GsColors.cyan),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style:
                        (page
                                ? Theme.of(context).textTheme.headlineMedium
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(
                              color: GsColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: GsColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      if (action == null) return heading;
      if (box.maxWidth < (page ? 900 : 560) ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 12), action!],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 24),
          action!,
        ],
      );
    },
  );
}

class GsCard extends StatelessWidget {
  const GsCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(20),
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
  Widget build(BuildContext context) => Material(
    color: backgroundColor ?? GsColors.surface,
    elevation: elevation,
    shadowColor: Colors.black26,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GsSizes.cardRadius),
      side: BorderSide(color: borderColor ?? const Color(0x12FFFFFF)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || action != null) ...[
          Padding(
            padding: const EdgeInsets.all(20),
            child: GsSectionHeading(
              title: title ?? '',
              subtitle: subtitle,
              icon: icon,
              action: action,
            ),
          ),
          const Divider(height: 1),
        ],
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

enum GsButtonVariant { primary, secondary, ghost, danger }

ButtonStyle gsButtonStyle(
  BuildContext context, {
  GsButtonVariant variant = GsButtonVariant.primary,
  double? height,
  bool compact = false,
}) {
  final foreground = switch (variant) {
    GsButtonVariant.primary => const Color(0xFF041822),
    GsButtonVariant.danger => GsColors.crimson,
    _ => GsColors.textPrimary,
  };
  final background = switch (variant) {
    GsButtonVariant.primary => GsColors.cyan,
    GsButtonVariant.secondary => GsColors.surfaceElevated,
    GsButtonVariant.danger => GsColors.crimsonGlow,
    GsButtonVariant.ghost => Colors.transparent,
  };
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(40, GsSizes.control(context, height)),
    ),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 8),
    ),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(
      Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GsSizes.radius),
      ),
    ),
    elevation: const WidgetStatePropertyAll(0),
    animationDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? GsColors.textMuted : foreground,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? GsColors.surfaceElevated
          : background,
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.focused)
          ? GsColors.cyan.withValues(alpha: .24)
          : foreground.withValues(alpha: .09),
    ),
    side: WidgetStateProperty.resolveWith(
      (s) => BorderSide(
        color: s.contains(WidgetState.focused)
            ? GsColors.cyanLight
            : variant == GsButtonVariant.secondary
            ? GsColors.borderInteractive
            : Colors.transparent,
        width: 1.5,
      ),
    ),
  );
}

class GsButton extends StatelessWidget {
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
  Widget build(BuildContext context) => Semantics(
    liveRegion: loading,
    value: loading ? 'En curso' : null,
    child: TextButton(
      onPressed: loading ? null : onPressed,
      style: gsButtonStyle(
        context,
        variant: variant,
        height: height,
        compact: compact,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: loading && icon == null ? 0 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  SizedBox.square(
                    dimension: GsSizes.icon,
                    child: loading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Icon(icon, size: GsSizes.icon),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
          ),
          if (loading && icon == null)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    ),
  );
}

class GsIconButton extends StatelessWidget {
  const GsIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size,
    this.iconSize = GsSizes.icon,
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
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    style:
        gsButtonStyle(
          context,
          variant: variant,
          height: size,
          compact: compact,
        ).copyWith(
          minimumSize: WidgetStatePropertyAll(
            Size.square(GsSizes.control(context, size)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          foregroundColor: color == null
              ? null
              : WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.disabled)
                      ? GsColors.textMuted
                      : color,
                ),
        ),
    icon: Icon(icon, size: iconSize),
  );
}

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
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: GsSizes.control(context, height),
    child: TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlignVertical: TextAlignVertical.center,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        hintText: hintText,
        prefixText: prefixText,
        prefixIconConstraints: BoxConstraints(
          minWidth: 40,
          minHeight: GsSizes.control(context, height),
        ),
        suffixIconConstraints: BoxConstraints(
          minWidth: 40,
          minHeight: GsSizes.control(context, height),
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: GsSizes.icon),
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      secondary: icon == null
          ? null
          : Icon(icon, size: 20, color: GsColors.textSecondary),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: GsColors.textSecondary),
              ),
            ),
    ),
  );
}

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
  Widget build(BuildContext context) => Semantics(
    toggled: selected,
    child: GsButton(
      label: label,
      icon: selected ? Icons.check_rounded : icon,
      variant: selected ? GsButtonVariant.primary : GsButtonVariant.secondary,
      onPressed: () => onToggle(!selected),
    ),
  );
}

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
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: GsColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          label: label,
          child: SizedBox(
            height: GsSizes.control(context, height),
            child: DropdownButtonFormField<T>(
              key: ValueKey(value),
              initialValue: items.containsKey(value) ? value : null,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                constraints: BoxConstraints(
                  minHeight: GsSizes.control(context, height),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              dropdownColor: GsColors.surfaceElevated,
              borderRadius: BorderRadius.circular(GsSizes.radius),
              menuMaxHeight: 360,
              style: Theme.of(context).textTheme.bodyMedium,
              items: [
                for (final entry in items.entries)
                  DropdownMenuItem<T>(
                    value: entry.key,
                    child: Tooltip(
                      message: entry.value,
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (next) {
                      if (next != null) onChanged!(next);
                    },
            ),
          ),
        ),
      ],
    ),
  );
}

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
    final color = switch (variant) {
      GsBadgeVariant.success => GsColors.emerald,
      GsBadgeVariant.danger => GsColors.crimson,
      GsBadgeVariant.warning => GsColors.amber,
      GsBadgeVariant.info => GsColors.cyan,
      GsBadgeVariant.neutral => GsColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(GsSizes.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot || icon != null) ...[
            Icon(icon ?? Icons.circle, size: dot ? 6 : 14, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: GsColors.textMuted),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: GsColors.textSecondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: valueColor ?? GsColors.textPrimary,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(
          subtitle!,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: GsColors.textSecondary),
        ),
      ],
    ],
  );
}
