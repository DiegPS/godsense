import 'package:flutter_test/flutter_test.dart';
import 'package:multiview_desktop/src/impl/cascade_close_service_impl.dart';

void main() {
  test(
    'nested closes complete child and parent without replacing either waiter',
    () async {
      final service = CascadeCloseService();
      service.attachWindow(1);
      final root = service.waitWindow(1);
      service.attachWindow(2);
      final child = service.waitWindow(2);
      service.attachWindow(2);
      service.completeWindow(2);
      service.completeWindow(2); // Duplicate native notifications are harmless.
      expect(await child.timeout(const Duration(seconds: 1)), isTrue);
      service.completeWindow(1);
      expect(await root.timeout(const Duration(seconds: 1)), isTrue);
    },
  );
  test('cancelling one window resolves all cascade waiters', () async {
    final service = CascadeCloseService();
    service.attachWindow(1);
    service.attachWindow(2);
    final root = service.waitWindow(1);
    final child = service.waitWindow(2);
    service.abort(2);
    expect(await child, isFalse);
    expect(await root, isFalse);
  });
}
