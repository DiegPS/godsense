import 'package:flutter/material.dart';

abstract final class CoachColors {
  static const canvas = Color(0xFF080B10);
  static const surface = Color(0xFF0F141D);
  static const elevated = Color(0xFF151C28);
  static const border = Color(0xFF1E293B);
  static const cyan = Color(0xFF38BDF8);
  static const emerald = Color(0xFF10B981);
  static const crimson = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const primaryText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFF94A3B8);
  static const mutedText = Color(0xFF64748B);
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CoachColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoachColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || action != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    ExcludeSemantics(
                      child: Icon(icon, size: 18, color: CoachColors.cyan),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: const TextStyle(
                              color: CoachColors.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: CoachColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
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
