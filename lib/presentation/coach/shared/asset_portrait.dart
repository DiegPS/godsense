import 'package:flutter/material.dart';

import 'coach_surface.dart';

class AssetPortrait extends StatelessWidget {
  const AssetPortrait({
    super.key,
    required this.semanticLabel,
    this.url,
    this.size = 40,
    this.fallback = Icons.image_not_supported_outlined,
    this.circular = false,
  });

  final String semanticLabel;
  final String? url;
  final double size;
  final IconData fallback;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size / 2 : 8.0;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(
          dimension: size,
          child: url == null || url!.isEmpty
              ? _fallback()
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                ),
        ),
      ),
    );
  }

  Widget _fallback() => ColoredBox(
    color: CoachColors.elevated,
    child: Icon(fallback, color: CoachColors.mutedText, size: size * .48),
  );
}
