import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_vision_controller.dart';

void main() {
  final scenarios = [
    (state: const NativeVisionState(), status: 'En espera', ready: false),
    (
      state: const NativeVisionState(running: true),
      status: 'Esperando enemigos',
      ready: false,
    ),
    (
      state: const NativeVisionState(
        running: true,
        expectedTargets: 5,
        targetsLoading: true,
      ),
      status: 'Preparando reconocimiento',
      ready: false,
    ),
    (
      state: const NativeVisionState(running: true, expectedTargets: 5),
      status: 'Esperando retratos · reintentando',
      ready: false,
    ),
    (
      state: const NativeVisionState(
        running: true,
        expectedTargets: 5,
        loadedTargets: 3,
      ),
      status: 'Reconocimiento parcial · 3/5',
      ready: false,
    ),
    (
      state: const NativeVisionState(
        running: true,
        expectedTargets: 5,
        loadedTargets: 5,
        pendingVariants: true,
      ),
      status: 'Faltan transformaciones · reintentando',
      ready: false,
    ),
    (
      state: const NativeVisionState(
        running: true,
        expectedTargets: 5,
        loadedTargets: 5,
      ),
      status: 'Vigilando',
      ready: true,
    ),
    (
      state: const NativeVisionState(
        running: true,
        expectedTargets: 5,
        loadedTargets: 5,
        error: 'Fixture capture unavailable',
      ),
      status: 'Revisar visión',
      ready: false,
    ),
    (
      state: const NativeVisionState(
        running: false,
        expectedTargets: 5,
        loadedTargets: 5,
        error: 'Fixture recalibration required',
      ),
      status: 'Revisar visión',
      ready: false,
    ),
  ];
  for (final (index, scenario) in scenarios.indexed) {
    test(
      'recognition readiness requires all prerequisites: case $index / ${scenario.status}',
      () {
        expect(scenario.state.recognitionReady, scenario.ready);
        expect(scenario.state.recognitionStatus, scenario.status);
      },
    );
  }
}
