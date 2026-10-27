The unmodified `sherpa-onnx-c-api.h` is the public C API header from
https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.6/sherpa-onnx/c-api/c-api.h .

SHA-256: `426db2c6acfb51e02143aece67c45779fae699d961c7c26ccf6f1388fdeaa2df`.

Copyright Xiaomi Corporation and sherpa-onnx contributors. The upstream
Apache-2.0 license is included as `LICENSE.sherpa-onnx` and copied into the
application's `data/licenses/` directory during the Windows build.

This helper uses the DLLs already supplied by the pinned `sherpa_onnx_windows`
dependency. It does not download, install or update speech software at runtime.
Review the C ABI before changing the bundled Sherpa version.
