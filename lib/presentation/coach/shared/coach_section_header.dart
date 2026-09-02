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
        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PhaseButton(
              label: 'Auto · ${_label(automaticPhase)}',
              selected: phase == automaticPhase,
              onPressed: () => onPhaseSelected(null),
            ),
            for (final value in CoachPhase.values)
              _PhaseButton(
                label: _label(value),
                selected: phase == value && phase != automaticPhase,
                onPressed: () => onPhaseSelected(value),
              ),
          ],
        );
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coach',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: CoachColors.primaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'Asistencia táctica guiada por lo que ocurre en tu partida.',
              style: TextStyle(color: CoachColors.secondaryText, fontSize: 13),
            ),
          ],
        );
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), controls],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            Flexible(child: controls),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: selected
              ? CoachColors.primaryText
              : CoachColors.secondaryText,
          backgroundColor: selected
              ? CoachColors.cyan.withValues(alpha: .16)
              : Colors.transparent,
          side: BorderSide(
            color: selected ? CoachColors.cyan : CoachColors.border,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

String _label(CoachPhase value) => switch (value) {
  CoachPhase.champSelect => 'Selección',
  CoachPhase.inGame => 'En partida',
  CoachPhase.postGame => 'Postpartida',
  CoachPhase.inactive => 'Inactivo',
};
