import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv.dart' as cv;
import 'package:path_provider/path_provider.dart';

class VisionIconCache {
  Future<Uint8List?> load(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    File? file;
    try {
      final root = await getApplicationSupportDirectory();
      file = File(
        '${root.path}/vision_icons/${sha256.convert(utf8.encode(url))}.png',
      );
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (_valid(bytes)) return bytes;
      }
    } catch (_) {
      // A read-only cache must not disable recognition.
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final bytes = await consolidateHttpClientResponseBytes(response)
          .timeout(const Duration(seconds: 5));
      if (!_valid(bytes)) return null;
      if (file != null) {
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // Valid downloaded bytes remain usable if persistence fails.
        }
      }
      return bytes;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  bool _valid(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    try {
      final decoded = cv.imdecode(bytes, cv.IMREAD_COLOR);
      try {
        return !decoded.isEmpty && decoded.rows > 1 && decoded.cols > 1;
      } finally {
        decoded.dispose();
      }
    } catch (_) {
      return false;
    }
  }
}
