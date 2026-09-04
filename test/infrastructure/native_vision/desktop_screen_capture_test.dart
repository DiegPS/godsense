import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('godsense/desktop_capture');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getDisplays') {
            return <Object?>[
              _display(
                id: 'secondary',
                name: r'\\.\DISPLAY2',
                left: -1920,
                top: 0,
              ),
              _display(id: 'primary', name: r'\\.\DISPLAY1', left: 0, top: 0),
            ];
          }
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          return <Object?, Object?>{
            ..._display(
              id: arguments['displayId']?.toString() ?? 'secondary',
              name: r'\\.\DISPLAY2',
              left: -1920,
              top: 0,
            ),
            'captureWidth': arguments['width'],
            'captureHeight': arguments['height'],
            'localLeft': arguments['localLeft'] ?? 1500,
            'localTop': arguments['localTop'] ?? 700,
            'captureMicroseconds': 900,
            'bgra': Uint8List(
              (arguments['width'] as int) * (arguments['height'] as int) * 4,
            ),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('describes a negative-coordinate region on its real display', () async {
    final capture = DesktopScreenCapture(channel: channel);
    final bounds = await capture.describeBounds({
      'left': -420,
      'top': 700,
      'width': 300,
      'height': 300,
    });

    expect(bounds['display_id'], 'secondary');
    expect(bounds['display_left'], -1920);
    expect(bounds['local_left'], 1500);
    expect(bounds['local_top'], 700);
  });

  test(
    'passes stable display identity and local coordinates to DXGI',
    () async {
      final capture = DesktopScreenCapture(channel: channel);
      final frame = await capture.capture(
        left: -420,
        top: 700,
        width: 64,
        height: 64,
        displayId: 'secondary',
        localLeft: 1500,
        localTop: 700,
      );

      final arguments = Map<Object?, Object?>.from(
        calls.single.arguments as Map,
      );
      expect(arguments['displayId'], 'secondary');
      expect(arguments['localLeft'], 1500);
      expect(frame.bgra, hasLength(64 * 64 * 4));
      expect(frame.display?.id, 'secondary');
      expect(frame.captureMicroseconds, 900);
    },
  );

  test('does not silently rebind a missing display to the primary one', () {
    final capture = DesktopScreenCapture(channel: channel);

    expect(
      () => capture.describeBounds({
        'left': 100,
        'top': 100,
        'width': 300,
        'height': 300,
        'display_id': 'disconnected-monitor',
        'local_left': 100,
        'local_top': 100,
      }),
      throwsStateError,
    );
  });
}

Map<Object?, Object?> _display({
  required String id,
  required String name,
  required int left,
  required int top,
}) => <Object?, Object?>{
  'id': id,
  'name': name,
  'left': left,
  'top': top,
  'width': 1920,
  'height': 1080,
  'dpiScale': 1.25,
  'primary': id == 'primary',
  'rotation': 1,
};
