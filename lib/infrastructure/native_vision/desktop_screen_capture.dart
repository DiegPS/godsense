import 'package:flutter/services.dart';

class CaptureDisplay {
  const CaptureDisplay({
    required this.id,
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.dpiScale,
    required this.primary,
    required this.rotation,
  });

  factory CaptureDisplay.fromMap(Map<Object?, Object?> value) => CaptureDisplay(
    id: value['id']?.toString() ?? '',
    name: value['name']?.toString() ?? '',
    left: (value['left'] as num?)?.round() ?? 0,
    top: (value['top'] as num?)?.round() ?? 0,
    width: (value['width'] as num?)?.round() ?? 0,
    height: (value['height'] as num?)?.round() ?? 0,
    dpiScale: (value['dpiScale'] as num?)?.toDouble() ?? 1,
    primary: value['primary'] == true,
    rotation: (value['rotation'] as num?)?.round() ?? 0,
  );

  final String id;
  final String name;
  final int left;
  final int top;
  final int width;
  final int height;
  final double dpiScale;
  final bool primary;
  final int rotation;

  bool contains({
    required int regionLeft,
    required int regionTop,
    required int regionWidth,
    required int regionHeight,
  }) =>
      regionLeft >= left &&
      regionTop >= top &&
      regionLeft + regionWidth <= left + width &&
      regionTop + regionHeight <= top + height;

  Map<String, dynamic> enrichBounds({
    required int regionLeft,
    required int regionTop,
    required int regionWidth,
    required int regionHeight,
  }) => {
    'left': regionLeft,
    'top': regionTop,
    'width': regionWidth,
    'height': regionHeight,
    'display_id': id,
    'display_name': name,
    'display_left': left,
    'display_top': top,
    'display_width': width,
    'display_height': height,
    'display_dpi_scale': dpiScale,
    'display_rotation': rotation,
    'local_left': regionLeft - left,
    'local_top': regionTop - top,
  };
}

class CapturedRegion {
  const CapturedRegion({
    required this.width,
    required this.height,
    required this.bgra,
    required this.capturedAt,
    required this.captureMicroseconds,
    this.display,
  });

  final int width;
  final int height;
  final Uint8List bgra;
  final DateTime capturedAt;
  final int captureMicroseconds;
  final CaptureDisplay? display;
}

abstract interface class ScreenCaptureSource {
  Future<List<CaptureDisplay>> getDisplays();

  Future<CapturedRegion> capture({
    required int left,
    required int top,
    required int width,
    required int height,
    String? displayId,
    int? localLeft,
    int? localTop,
  });

  Future<Map<String, dynamic>> describeBounds(Map<String, dynamic> bounds);

  void dispose();
}

/// Captures the visible desktop through Windows Desktop Duplication (DXGI).
///
/// The native side binds a calibrated region to the corresponding DXGI output,
/// keeps the latest desktop texture when the desktop has not changed, and
/// recreates the duplication session after display or mode changes.
class DesktopScreenCapture implements ScreenCaptureSource {
  DesktopScreenCapture({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('godsense/desktop_capture');

  final MethodChannel _channel;

  @override
  Future<List<CaptureDisplay>> getDisplays() async {
    final values = await _channel.invokeMethod<List<Object?>>('getDisplays');
    if (values == null || values.isEmpty) {
      throw StateError('Windows no informó ninguna pantalla disponible.');
    }
    return values
        .whereType<Map<Object?, Object?>>()
        .map(CaptureDisplay.fromMap)
        .where((display) => display.width > 0 && display.height > 0)
        .toList(growable: false);
  }

  @override
  Future<CapturedRegion> capture({
    required int left,
    required int top,
    required int width,
    required int height,
    String? displayId,
    int? localLeft,
    int? localTop,
  }) async {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Capture dimensions must be positive.');
    }
    final response = await _channel.invokeMethod<Map<Object?, Object?>>(
      'capture',
      <String, Object>{
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        if (displayId != null && displayId.isNotEmpty) 'displayId': displayId,
        'localLeft': ?localLeft,
        'localTop': ?localTop,
      },
    );
    if (response == null) {
      throw StateError('DXGI no devolvió ningún frame.');
    }
    final pixels = response['bgra'];
    final captureWidth = (response['captureWidth'] as num?)?.round() ?? width;
    final captureHeight =
        (response['captureHeight'] as num?)?.round() ?? height;
    if (pixels is! Uint8List ||
        pixels.length != captureWidth * captureHeight * 4) {
      throw StateError('DXGI devolvió un frame BGRA incompleto.');
    }
    return CapturedRegion(
      width: captureWidth,
      height: captureHeight,
      bgra: pixels,
      capturedAt: DateTime.now(),
      captureMicroseconds:
          (response['captureMicroseconds'] as num?)?.round() ?? 0,
      display: CaptureDisplay.fromMap(response),
    );
  }

  @override
  Future<Map<String, dynamic>> describeBounds(
    Map<String, dynamic> bounds,
  ) async {
    int read(String key) => (bounds[key] as num).round();
    final left = read('left');
    final top = read('top');
    final width = read('width');
    final height = read('height');
    final requestedId = bounds['display_id']?.toString();
    final displays = await getDisplays();
    CaptureDisplay? selected;
    if (requestedId != null && requestedId.isNotEmpty) {
      for (final display in displays) {
        if (display.id == requestedId) {
          selected = display;
          break;
        }
      }
      if (selected == null) {
        throw StateError('The calibrated display is not currently available.');
      }
    } else {
      for (final display in displays) {
        if (display.contains(
          regionLeft: left,
          regionTop: top,
          regionWidth: width,
          regionHeight: height,
        )) {
          selected = display;
          break;
        }
      }
    }
    if (selected == null) {
      throw ArgumentError.value(
        bounds,
        'bounds',
        'The region must fit completely inside one display.',
      );
    }
    final localLeft = (bounds['local_left'] as num?)?.round();
    final localTop = (bounds['local_top'] as num?)?.round();
    final resolvedLeft = requestedId == selected.id && localLeft != null
        ? selected.left + localLeft
        : left;
    final resolvedTop = requestedId == selected.id && localTop != null
        ? selected.top + localTop
        : top;
    return selected.enrichBounds(
      regionLeft: resolvedLeft,
      regionTop: resolvedTop,
      regionWidth: width,
      regionHeight: height,
    );
  }

  @override
  void dispose() {}
}
