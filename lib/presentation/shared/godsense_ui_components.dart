import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';

import 'gs_tokens.dart';
export 'gs_tokens.dart';
export 'gs_feature_page.dart';

class GsSectionHeading extends StatelessWidget {
  const GsSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.center,
    this.icon,
    this.action,
    this.page = false,
  });
  final String title;
  final String? subtitle;
  final Widget? center;
  final IconData? icon;
  final Widget? action;
  final bool page;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      crossAxisAlignment: center == null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GsColors.accentTint,
              borderRadius: BorderRadius.circular(GsSizes.radius),
            ),
            child: ExcludeSemantics(
              child: Icon(icon, size: 20, color: GsColors.accent),
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
    if (center == null) return UiPageHeader(title: heading, actions: [?action]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 700 * scale) {
          return UiPageHeader(title: heading, actions: [center!, ?action]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            Expanded(child: Center(child: center!)),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        );
      },
    );
  }
}

class GsCard extends StatelessWidget {
  const GsCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.headerCenter,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(20),
    this.elevation = 1,
    this.borderColor,
    this.backgroundColor,
  });
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? headerCenter;
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
    shadowColor: const Color(0xFF24213A).withValues(alpha: .05),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GsSizes.cardRadius),
      side: BorderSide(color: borderColor ?? GsColors.border),
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
              center: headerCenter,
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
    GsButtonVariant.primary => GsColors.onAccent,
    GsButtonVariant.danger => GsColors.crimson,
    _ => GsColors.textPrimary,
  };
  final background = switch (variant) {
    GsButtonVariant.primary => GsColors.accent,
    GsButtonVariant.secondary => GsColors.surfaceElevated,
    GsButtonVariant.danger => GsColors.crimsonGlow,
    GsButtonVariant.ghost => Colors.transparent,
  };
  final geometry = UiControlMetrics.action(context);
  final horizontalPadding = compact
      ? 12.0
      : UiThemeData.of(context).actionHorizontalPadding;
  return geometry.copyWith(
    minimumSize: WidgetStatePropertyAll(
      Size(40, GsSizes.control(context, height)),
    ),
    padding: WidgetStatePropertyAll(
      geometry.padding!
          .resolve({})!
          .resolve(Directionality.of(context))
          .copyWith(left: horizontalPadding, right: horizontalPadding),
    ),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(
      UiControlMetrics.textStyle(context).copyWith(fontWeight: FontWeight.w600),
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
          ? GsColors.accent.withValues(alpha: .24)
          : foreground.withValues(alpha: .09),
    ),
    side: WidgetStateProperty.resolveWith(
      (s) => BorderSide(
        color: s.contains(WidgetState.focused)
            ? GsColors.focus
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
        clipBehavior: Clip.none,
        children: [
          Row(
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
          if (loading && icon == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: -5,
              child: SizedBox(
                height: 2,
                child: MediaQuery.disableAnimationsOf(context)
                    ? const ColoredBox(color: GsColors.accent)
                    : const LinearProgressIndicator(semanticsLabel: 'En curso'),
              ),
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
    this.focusNode,
    this.labelText,
    this.helperText,
    this.errorText,
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
  final FocusNode? focusNode;
  final String? labelText;
  final String? helperText;
  final String? errorText;
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
    child: _GsFieldProfile(
      height: height,
      builder: (context) => UiControls.input(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textAlignVertical: TextAlignVertical.center,
        style: style,
        decoration: InputDecoration(
          labelText: labelText,
          helperText: helperText,
          errorText: errorText,
          hintText: hintText,
          prefixText: prefixText,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: GsSizes.icon),
          suffixIcon: suffixIcon,
        ),
      ),
    ),
  );
}

// Explicit large controls use the same library profile, not a fixed outer box.
// Helpers, errors and scaled text remain free to grow below the painted border.
class _GsFieldProfile extends StatelessWidget {
  const _GsFieldProfile({required this.height, required this.builder});
  final double? height;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (height == null) return builder(context);
    final theme = Theme.of(context);
    final profile = UiThemeData.of(context);
    final base = MediaQuery.sizeOf(context).width < profile.compactBreakpoint
        ? profile.compactControlHeight
        : profile.controlHeight;
    final target = height! > base ? height! : base;
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((value) => value is! UiThemeData),
          profile.copyWith(controlHeight: target, compactControlHeight: target),
        ],
      ),
      child: Builder(builder: builder),
    );
  }
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
    this.helperText,
    this.errorText,
    this.validator,
    this.width,
    this.height,
    this.compact = false,
  });
  final T value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<T>? validator;
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
          child: _GsFieldProfile(
            height: height,
            builder: (context) => DropdownButtonFormField<T>(
              key: ValueKey(value),
              initialValue: items.containsKey(value) ? value : null,
              isExpanded: true,
              isDense: true,
              itemHeight: null,
              validator: validator,
              decoration: UiControlMetrics.decoration(
                context,
                InputDecoration(helperText: helperText, errorText: errorText),
                select: true,
              ),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              dropdownColor: GsColors.surfaceElevated,
              borderRadius: BorderRadius.circular(GsSizes.radius),
              menuMaxHeight: 360,
              style: UiControlMetrics.textStyle(context),
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
      GsBadgeVariant.info => GsColors.accent,
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
