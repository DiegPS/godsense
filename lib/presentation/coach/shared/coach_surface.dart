import 'package:flutter/material.dart';

import '../../shared/godsense_ui_components.dart';

abstract final class CoachColors {
  static const canvas = GsColors.canvas;
  static const surface = GsColors.surface;
  static const elevated = GsColors.surfaceElevated;
  static const border = GsColors.border;
  static const cyan = GsColors.cyan;
  static const emerald = GsColors.emerald;
  static const crimson = GsColors.crimson;
  static const amber = GsColors.amber;
  static const primaryText = GsColors.textPrimary;
  static const secondaryText = GsColors.textSecondary;
  static const mutedText = GsColors.textMuted;
}

class CoachSurface extends StatelessWidget {
  const CoachSurface({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.action,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GsCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: action,
      child: child,
    );
  }
}

class CoachEmptyState extends StatelessWidget {
  const CoachEmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, color: CoachColors.mutedText, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CoachColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
