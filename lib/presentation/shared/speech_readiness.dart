import '../../application/native_speech_controller.dart';
import '../../infrastructure/speech/speech/live_captions_service.dart';

({String status, String detail, bool ready}) speechReadiness(
  NativeSpeechState state,
) {
  if (state.loading) {
    return (
      status: 'Comprobando voz',
      detail: 'Preparando la configuración de voz.',
      ready: false,
    );
  }
  if (!state.settings.pushToTalkEnabled) {
    return (
      status: 'Desactivadas',
      detail: 'Activa Hablar con el coach en Ajustes.',
      ready: false,
    );
  }
  if (state.microphoneTest.active) {
    return (
      status: 'Prueba en curso',
      detail: 'Push-to-Talk volverá a estar disponible al terminar la prueba.',
      ready: false,
    );
  }
  if (!state.modelsChecked && state.error != null) {
    return (
      status: 'Revisa la voz',
      detail: 'No pudimos comprobar el reconocimiento. Abre Ajustes y vuelve a intentarlo.',
      ready: false,
    );
  }
  if (!state.modelsChecked) {
    return (
      status: 'Comprobando modelo',
      detail: 'Comprobando el reconocimiento de voz instalado.',
      ready: false,
    );
  }
  if (!state.speechModelInstalled) {
    return (
      status: 'Falta modelo de voz',
      detail:
          'Descarga el reconocimiento de voz en Ajustes para poder preguntar.',
      ready: false,
    );
  }
  if (state.speech.phase == LiveCaptionsPhase.error) {
    return (
      status: 'Revisa el micrófono',
      detail: 'Prueba el micrófono en Ajustes y vuelve a intentarlo.',
      ready: false,
    );
  }
  return (
    status: 'Activadas',
    detail: 'Mantén ${state.settings.pushToTalkKey.toUpperCase()} para hablar.',
    ready: true,
  );
}
