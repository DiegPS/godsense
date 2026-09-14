import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_vision_controller.dart';

void main() {
  test('frame-only vision updates do not invalidate Coach', () {
    final vision = _TestVisionController();
    final container = ProviderContainer(
      overrides: [nativeVisionProvider.overrideWith((_) => vision)],
    );
    addTearDown(container.dispose);

    var notifications = 0;
    container.listen(
      coachVisionEventsProvider,
      (_, _) => notifications++,
      fireImmediately: true,
    );

    vision.emitFrameOnlyUpdate();
    expect(notifications, 1);
  });
}

class _TestVisionController extends NativeVisionController {
  void emitFrameOnlyUpdate() {
    state = state.copyWith(processing: !state.processing);
  }
}
