#ifndef RUNNER_DESKTOP_CAPTURE_PLUGIN_H_
#define RUNNER_DESKTOP_CAPTURE_PLUGIN_H_

#include <flutter_windows.h>

// Registers GodSense's DXGI desktop capture channel with the shared Flutter
// engine used by every multiview_desktop window.
void DesktopCapturePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#endif  // RUNNER_DESKTOP_CAPTURE_PLUGIN_H_
