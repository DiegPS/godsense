import 'package:flutter/material.dart';

import '../../infrastructure/speech/microphone_test_service.dart';

class MicrophoneTestPanel extends StatelessWidget {
  const MicrophoneTestPanel({
    super.key,
    required this.state,
    required this.onStart,
    required this.onCancel,
    this.enabled = true,
  });
  final MicrophoneTestState state;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: state.active || !enabled ? null : onStart,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('Probar micrófono'),
            ),
            if (state.active)
              TextButton.icon(
                onPressed: state.phase == MicrophoneTestPhase.cancelling
                    ? null
                    : onCancel,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Cancelar prueba'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(switch (state.phase) {
          MicrophoneTestPhase.idle =>
            enabled
                ? 'Graba hasta 3 segundos del micrófono predeterminado y escúchalos. El audio se borra al terminar y no se envía al coach.'
                : 'Termina de hablar con el coach antes de probar el micrófono.',
          MicrophoneTestPhase.preparing => 'Preparando el micrófono…',
          MicrophoneTestPhase.recording =>
            'Habla ahora: grabando hasta 3 segundos…',
          MicrophoneTestPhase.playing => 'Escucha tu grabación…',
          MicrophoneTestPhase.cancelling =>
            'Cancelando y liberando el micrófono…',
          MicrophoneTestPhase.completed =>
            state.silent
                ? 'No detectamos señal audible. Revisa el micrófono predeterminado y su volumen en Windows.'
                : 'Prueba completada. Si te escuchaste bien, el micrófono y la reproducción funcionan.',
          MicrophoneTestPhase.error =>
            state.cleanupFailed
                ? 'La prueba terminó, pero no se pudo limpiar la carpeta temporal de Windows.'
                : state.permissionDenied
                ? 'Windows no permite usar el micrófono. Revisa Privacidad y seguridad → Micrófono y permite el acceso a aplicaciones de escritorio.'
                : 'No pudimos completar la prueba. Revisa que el micrófono y los altavoces estén conectados y vuelve a intentarlo.',
        }),
        if (state.phase == MicrophoneTestPhase.recording) ...[
          const SizedBox(height: 8),
          const Text('Nivel de entrada'),
          LinearProgressIndicator(
            value: state.level,
            semanticsLabel: 'Nivel del micrófono',
            semanticsValue: '${(state.level * 100).round()} %',
          ),
        ],
      ],
    ),
  );
}
