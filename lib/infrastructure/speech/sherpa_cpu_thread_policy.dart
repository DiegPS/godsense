import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Mirrors ONNX Runtime's CPU default: one inference thread per physical core.
class SherpaCpuThreadPolicy {
  const SherpaCpuThreadPolicy._();

  static int recommended() {
    final fallback = Platform.numberOfProcessors;
    if (!Platform.isWindows) return fallback;

    Pointer<Uint32>? byteCount;
    Pointer<Uint8>? buffer;
    try {
      final getProcessorInfo = DynamicLibrary.open('kernel32.dll')
          .lookupFunction<
            Int32 Function(Uint32, Pointer<Uint8>, Pointer<Uint32>),
            int Function(int, Pointer<Uint8>, Pointer<Uint32>)
          >('GetLogicalProcessorInformationEx');
      byteCount = calloc<Uint32>();
      getProcessorInfo(0, nullptr, byteCount);
      if (byteCount.value == 0) return fallback;

      buffer = calloc<Uint8>(byteCount.value);
      if (getProcessorInfo(0, buffer, byteCount) == 0) return fallback;

      var cores = 0;
      var offset = 0;
      while (offset < byteCount.value) {
        final entry = buffer + offset;
        final relationship = entry.cast<Uint32>().value;
        final size = (entry + 4).cast<Uint32>().value;
        if (size < 8 || offset + size > byteCount.value) return fallback;
        if (relationship == 0) cores++;
        offset += size;
      }
      return cores > 0 ? cores : fallback;
    } catch (_) {
      return fallback;
    } finally {
      if (buffer != null) calloc.free(buffer);
      if (byteCount != null) calloc.free(byteCount);
    }
  }
}
