#include "flutter_window.h"

#include <flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h>
#include <multiview_desktop/multi_view_desktop_plugin.h>

namespace {

void RegisterApplicationPlugins(FlutterDesktopEngineRef engine) {
  FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
      FlutterDesktopEngineGetPluginRegistrar(
          engine, "FlutterSecureStorageWindowsPlugin"));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  const RECT frame = GetClientArea();
  const int width = frame.right - frame.left;
  const int height = frame.bottom - frame.top;

  MultiViewDesktopPrepareEngine(project_, GetHandle());
  MultiViewDesktopCreateMainView(GetHandle(), width, height);

  FlutterDesktopEngineRef engine = MultiViewDesktopGetEngineRef();
  if (engine == nullptr) {
    return false;
  }
  RegisterApplicationPlugins(engine);

  const HWND flutter_hwnd =
      MultiViewDesktopGetFlutterHwnd(MultiViewDesktopGetMainViewId());
  if (flutter_hwnd == nullptr) {
    return false;
  }
  SetChildContent(flutter_hwnd);

  return true;
}

void FlutterWindow::OnDestroy() {
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  LRESULT result = 0;

  if (message == WM_FONTCHANGE) {
    FlutterDesktopEngineReloadSystemFonts(MultiViewDesktopGetEngineRef());
  }
  if (MultiViewDesktopHandleWindowProc(hwnd, message, wparam, lparam,
                                       &result)) {
    return result;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
