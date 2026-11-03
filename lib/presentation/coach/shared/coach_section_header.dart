import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../../shared/godsense_ui_components.dart';

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Semantics(
            selected: phase == automaticPhase,
            child: GsButton(
              label: 'Auto · ${_label(automaticPhase)}',
              icon: Icons.sync_rounded,
              variant: phase == automaticPhase
                  ? GsButtonVariant.primary
                  : GsButtonVariant.secondary,
              onPressed: () => onPhaseSelected(null),
            ),
          ),
          for (final value in CoachPhase.values)
            Semantics(
              selected: phase == value && phase != automaticPhase,
              child: GsButton(
                label: _label(value),
                variant: phase == value && phase != automaticPhase
                    ? GsButtonVariant.primary
                    : GsButtonVariant.ghost,
                onPressed: () => onPhaseSelected(value),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        phase == automaticPhase
            ? 'La vista sigue automáticamente la fase de League.'
            : 'Vista manual: eliges qué etapa consultar; la fase de League no cambia.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: GsColors.textSecondary),
      ),
    ],
  );
}

String _label(CoachPhase value) => switch (value) {
  CoachPhase.champSelect => 'Selección',
  CoachPhase.inGame => 'En partida',
  CoachPhase.postGame => 'Postpartida',
  CoachPhase.inactive => 'Inactivo',
};
