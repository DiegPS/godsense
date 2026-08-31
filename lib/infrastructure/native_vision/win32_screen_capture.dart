import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class CapturedRegion {
  const CapturedRegion({
    required this.width,
    required this.height,
    required this.bgra,
    required this.capturedAt,
    required this.captureMicroseconds,
  });

  final int width;
  final int height;
  final Uint8List bgra;
  final DateTime capturedAt;
  final int captureMicroseconds;
}

class Win32ScreenCapture {
  HDC? _screenDc;
  HDC? _memoryDc;
  HBITMAP? _bitmap;
  HGDIOBJ? _previousObject;
  Pointer<BITMAPINFO>? _info;
  Pointer<Uint8>? _pixels;
  int _width = 0;
  int _height = 0;

  CapturedRegion capture({
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    final stopwatch = Stopwatch()..start();
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Capture dimensions must be positive.');
    }
    _ensureResources(width, height);

    final copied = BitBlt(
      _memoryDc!,
      0,
      0,
      width,
      height,
      _screenDc!,
      left,
      top,
      ROP_CODE(SRCCOPY | CAPTUREBLT),
    );
    if (!copied.value) {
      throw StateError('BitBlt failed (${copied.error}).');
    }
    final lines = GetDIBits(
      _memoryDc!,
      _bitmap!,
      0,
      height,
      _pixels!,
      _info!,
      DIB_RGB_COLORS,
    );
    if (lines != height) {
      throw StateError('GetDIBits copied $lines of $height lines.');
    }
    return CapturedRegion(
      width: width,
      height: height,
      bgra: Uint8List.fromList(_pixels!.asTypedList(width * height * 4)),
      capturedAt: DateTime.now(),
      captureMicroseconds: stopwatch.elapsedMicroseconds,
    );
  }

  void _ensureResources(int width, int height) {
    if (_width == width && _height == height && _pixels != null) return;
    _releaseResources();
    _screenDc = GetDC(null);
    if (_screenDc!.isNull) throw StateError('GetDC failed.');
    _memoryDc = CreateCompatibleDC(_screenDc!);
    if (_memoryDc!.isNull) {
      _releaseResources();
      throw StateError('CreateCompatibleDC failed.');
    }
    _bitmap = CreateCompatibleBitmap(_screenDc!, width, height);
    if (_bitmap!.isNull) {
      _releaseResources();
      throw StateError('CreateCompatibleBitmap failed.');
    }
    _previousObject = SelectObject(_memoryDc!, HGDIOBJ(_bitmap!));
    _info = calloc<BITMAPINFO>();
    _pixels = calloc<Uint8>(width * height * 4);
    _info!.ref.bmiHeader
      ..biSize = sizeOf<BITMAPINFOHEADER>()
      ..biWidth = width
      ..biHeight = -height
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = BI_RGB
      ..biSizeImage = width * height * 4;
    _width = width;
    _height = height;
  }

  void dispose() => _releaseResources();

  void _releaseResources() {
    if (_memoryDc != null && _previousObject != null) {
      SelectObject(_memoryDc!, _previousObject!);
    }
    if (_bitmap != null && !_bitmap!.isNull) {
      DeleteObject(HGDIOBJ(_bitmap!));
    }
    if (_memoryDc != null && !_memoryDc!.isNull) DeleteDC(_memoryDc!);
    if (_screenDc != null && !_screenDc!.isNull) ReleaseDC(null, _screenDc!);
    if (_pixels != null) calloc.free(_pixels!);
    if (_info != null) calloc.free(_info!);
    _screenDc = null;
    _memoryDc = null;
    _bitmap = null;
    _previousObject = null;
    _pixels = null;
    _info = null;
    _width = 0;
    _height = 0;
  }
}
