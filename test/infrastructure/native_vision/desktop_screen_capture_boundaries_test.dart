import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('godsense/capture-boundaries-test');
  final calls = <MethodCall>[];
  Object? response;
  setUp(() {
    calls.clear();
    response = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return response;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final displays in [
    null,
    <Object?>[],
    <Object?>[
      null,
      'invalid',
      {'id': 'empty'},
    ],
  ]) {
    test(
      'an unusable display inventory fails with actionable error: $displays',
      () async {
        response = displays;
        await expectLater(
          DesktopScreenCapture(channel: channel).getDisplays(),
          throwsStateError,
        );
      },
    );
  }

  for (final dimensions in [(0, 20), (-1, 20), (20, 0), (20, -1)]) {
    test(
      'invalid requested size $dimensions never reaches native capture',
      () async {
        await expectLater(
          DesktopScreenCapture(channel: channel).capture(
            left: 0,
            top: 0,
            width: dimensions.$1,
            height: dimensions.$2,
          ),
          throwsArgumentError,
        );
        expect(calls, isEmpty);
      },
    );
  }

  for (final (index, invalid) in <Object?>[
    null,
    {'bgra': Uint8List(15)},
    {
      'bgra': <int>[0, 0, 0, 0],
    },
    {'captureWidth': -1, 'captureHeight': -1, 'bgra': Uint8List(4)},
    {'captureWidth': 0, 'captureHeight': 2, 'bgra': Uint8List(0)},
  ].indexed) {
    test(
      'invalid native frame is rejected: case $index',
      () async {
        response = invalid;
        await expectLater(
          DesktopScreenCapture(channel: channel)
              .capture(left: 0, top: 0, width: 2, height: 2),
          throwsStateError,
        );
      },
    );
  }

  for (final local in [(-1, 10), (1800, 10), (10, -1), (10, 900)]) {
    test('identified monitor must still contain local region $local', () async {
      response = [_display];
      await expectLater(
        DesktopScreenCapture(channel: channel).describeBounds({
          'left': 100,
          'top': 100,
          'width': 300,
          'height': 300,
          'display_id': 'stable-display',
          'local_left': local.$1,
          'local_top': local.$2,
        }),
        throwsArgumentError,
      );
    });
  }

  test(
    'moved display resolves valid local coordinates against its new origin',
    () async {
      response = [
        {..._display, 'left': -1920},
      ];
      final bounds = await DesktopScreenCapture(channel: channel)
          .describeBounds({
            'left': 100,
            'top': 100,
            'width': 300,
            'height': 300,
            'display_id': 'stable-display',
            'local_left': 1620,
            'local_top': 780,
          });
      expect(bounds['left'], -300);
      expect(bounds['top'], 780);
      expect(bounds['local_left'], 1620);
      expect(bounds['display_id'], 'stable-display');
    },
  );
}

const _display = <Object?, Object?>{
  'id': 'stable-display',
  'name': 'Synthetic monitor',
  'left': 0,
  'top': 0,
  'width': 1920,
  'height': 1080,
  'dpiScale': 1.25,
  'primary': true,
  'rotation': 1,
};
