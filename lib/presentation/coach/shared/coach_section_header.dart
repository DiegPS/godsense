import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import 'coach_surface.dart';

class CoachSectionHeader extends StatelessWidget {
  const CoachSectionHeader({
    super.key,
    required this.phase,
    required this.automaticPhase,
    required this.onPhaseSelected,
  });

  final CoachPhase phase;
  final CoachPhase automaticPhase;
  final ValueChanged<CoachPhase?> onPhaseSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isAuto = phase == automaticPhase;
        final controls = Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PhaseButton(
              label: 'Auto · ${_label(automaticPhase)}',
              icon: Icons.sync_rounded,
              selected: isAuto,
              isAutoBadge: true,
              onPressed: () => onPhaseSelected(null),
            ),
            for (final value in CoachPhase.values)
              _PhaseButton(
                label: _label(value),
                icon: _icon(value),
                selected: phase == value && !isAuto,
                onPressed: () => onPhaseSelected(value),
              ),
          ],
        );
        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.psychology_outlined,
              size: 20,
              color: CoachColors.cyan,
            ),
            const SizedBox(width: 8),
            const Text(
              'Coach',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CoachColors.primaryText,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAuto ? const Color(0x2610B981) : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isAuto ? const Color(0x4D10B981) : const Color(0x26FFFFFF),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAuto ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      boxShadow: isAuto
                          ? const [BoxShadow(color: Color(0x8010B981), blurRadius: 4)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isAuto ? 'Sincronizado' : 'Manual',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAuto ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 10), controls],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            controls,
          ],
        );
      },
    );
  }
}

class _PhaseButton extends StatelessWidget {
  const _PhaseButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.isAutoBadge = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isAutoBadge;

  @override
  Widget build(BuildContext context) {
    final activeColor = isAutoBadge ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
    return Semantics(
      button: true,
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          foregroundColor: selected ? Colors.white : const Color(0xFF94A3B8),
          backgroundColor: selected ? const Color(0xFF1E293B) : const Color(0xFF0C1017),
          side: BorderSide(
            color: selected ? activeColor : const Color(0x1FFFFFFF),
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? activeColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _icon(CoachPhase value) => switch (value) {
  CoachPhase.champSelect => Icons.how_to_reg_rounded,
  CoachPhase.inGame => Icons.sensors_rounded,
  CoachPhase.postGame => Icons.assessment_outlined,
  CoachPhase.inactive => Icons.pause_circle_outline_rounded,
};

String _label(CoachPhase value) => switch (value) {
  CoachPhase.champSelect => 'Selección',
  CoachPhase.inGame => 'En partida',
  CoachPhase.postGame => 'Postpartida',
  CoachPhase.inactive => 'Inactivo',
};
