import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PythonVisionDiagnosticsState {
  const PythonVisionDiagnosticsState({
    this.connected = false,
    this.status = 'offline',
    this.snapshot = const {},
    this.framePng,
    this.maskPng,
    this.annotatedPng,
    this.error,
  });

  final bool connected;
  final String status;
  final Map<String, dynamic> snapshot;
  final Uint8List? framePng;
  final Uint8List? maskPng;
  final Uint8List? annotatedPng;
  final String? error;

  Map<String, dynamic> get metrics {
    final value = snapshot['metrics'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  List<Map<String, dynamic>> get detections {
    final value = snapshot['detections'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  PythonVisionDiagnosticsState copyWith({
    bool? connected,
    String? status,
    Map<String, dynamic>? snapshot,
    Uint8List? framePng,
    Uint8List? maskPng,
    Uint8List? annotatedPng,
    String? error,
    bool clearError = false,
  }) {
    return PythonVisionDiagnosticsState(
      connected: connected ?? this.connected,
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      framePng: framePng ?? this.framePng,
      maskPng: maskPng ?? this.maskPng,
      annotatedPng: annotatedPng ?? this.annotatedPng,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final pythonVisionDiagnosticsProvider =
    StateNotifierProvider<
      PythonVisionDiagnosticsController,
      PythonVisionDiagnosticsState
    >((ref) {
      final controller = PythonVisionDiagnosticsController();
      controller.start();
      return controller;
    });

class PythonVisionDiagnosticsController
    extends StateNotifier<PythonVisionDiagnosticsState> {
  PythonVisionDiagnosticsController()
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8430',
          connectTimeout: const Duration(milliseconds: 500),
          receiveTimeout: const Duration(seconds: 2),
        ),
      ),
      super(const PythonVisionDiagnosticsState());

  final Dio _dio;
  Timer? _timer;
  int _pollCount = 0;
  bool _polling = false;

  void start() {
    if (_timer != null) return;
    unawaited(_poll());
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final response = await _dio.get<Object?>('/api/diagnostics');
      final raw = response.data;
      if (raw is! Map) throw const FormatException('Invalid diagnostics JSON');
      final snapshot = raw.map((key, value) => MapEntry(key.toString(), value));
      var frame = state.framePng;
      var mask = state.maskPng;
      var annotated = state.annotatedPng;
      if (snapshot['status'] == 'running' && _pollCount++ % 2 == 0) {
        final images = await Future.wait([
          _image('/frame.png'),
          _image('/mask.png'),
          _image('/annotated.png'),
        ]);
        frame = images[0] ?? frame;
        mask = images[1] ?? mask;
        annotated = images[2] ?? annotated;
      }
      state = state.copyWith(
        connected: true,
        status: snapshot['status']?.toString() ?? 'unknown',
        snapshot: snapshot,
        framePng: frame,
        maskPng: mask,
        annotatedPng: annotated,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        connected: false,
        status: 'offline',
        error: error.toString(),
      );
    } finally {
      _polling = false;
    }
  }

  Future<Uint8List?> _image(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data == null ? null : Uint8List.fromList(response.data!);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
