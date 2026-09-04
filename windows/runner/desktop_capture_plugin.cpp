#include "desktop_capture_plugin.h"

#include <d3d11.h>
#include <dxgi1_2.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <wrl/client.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

using Microsoft::WRL::ComPtr;
using EncodableMap = flutter::EncodableMap;
using EncodableValue = flutter::EncodableValue;

std::string WideToUtf8(const wchar_t* value) {
  if (value == nullptr || *value == L'\0') {
    return {};
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0,
                                       nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value, -1, result.data(), size, nullptr,
                      nullptr);
  result.pop_back();
  return result;
}

std::string PersistentDisplayId(const wchar_t* device_name) {
  DISPLAY_DEVICEW device = {};
  device.cb = sizeof(device);
  for (DWORD index = 0; EnumDisplayDevicesW(device_name, index, &device, 0);
       ++index) {
    if ((device.StateFlags & DISPLAY_DEVICE_ACTIVE) != 0 &&
        (device.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0) {
      const auto id = WideToUtf8(device.DeviceID);
      if (!id.empty()) {
        return id;
      }
    }
    device = {};
    device.cb = sizeof(device);
  }
  return WideToUtf8(device_name);
}

double DpiScaleForRect(const RECT& bounds) {
  const POINT point = {bounds.left, bounds.top};
  const HMONITOR monitor =
      MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
  using GetDpiForMonitorFn = HRESULT(WINAPI*)(HMONITOR, int, UINT*, UINT*);
  static const auto get_dpi = []() -> GetDpiForMonitorFn {
    const HMODULE module = LoadLibraryW(L"shcore.dll");
    return module == nullptr
               ? nullptr
               : reinterpret_cast<GetDpiForMonitorFn>(
                     GetProcAddress(module, "GetDpiForMonitor"));
  }();
  UINT dpi_x = 96;
  UINT dpi_y = 96;
  if (get_dpi != nullptr) {
    get_dpi(monitor, 0, &dpi_x, &dpi_y);
  }
  return static_cast<double>(dpi_x) / 96.0;
}

struct DisplayOutput {
  ComPtr<IDXGIAdapter1> adapter;
  ComPtr<IDXGIOutput> output;
  DXGI_OUTPUT_DESC description = {};
  std::string id;
  std::string name;
  bool primary = false;
  double dpi_scale = 1.0;
};

std::vector<DisplayOutput> EnumerateOutputs() {
  ComPtr<IDXGIFactory1> factory;
  const HRESULT factory_result =
      CreateDXGIFactory1(IID_PPV_ARGS(factory.GetAddressOf()));
  if (FAILED(factory_result)) {
    throw std::runtime_error("No se pudo enumerar las pantallas con DXGI.");
  }

  std::vector<DisplayOutput> displays;
  for (UINT adapter_index = 0;; ++adapter_index) {
    ComPtr<IDXGIAdapter1> adapter;
    if (factory->EnumAdapters1(adapter_index, adapter.GetAddressOf()) ==
        DXGI_ERROR_NOT_FOUND) {
      break;
    }
    for (UINT output_index = 0;; ++output_index) {
      ComPtr<IDXGIOutput> output;
      if (adapter->EnumOutputs(output_index, output.GetAddressOf()) ==
          DXGI_ERROR_NOT_FOUND) {
        break;
      }
      DXGI_OUTPUT_DESC description = {};
      if (FAILED(output->GetDesc(&description)) ||
          description.AttachedToDesktop == FALSE) {
        continue;
      }
      const RECT bounds = description.DesktopCoordinates;
      const POINT origin = {0, 0};
      const HMONITOR primary_monitor =
          MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY);
      DisplayOutput display;
      display.adapter = adapter;
      display.output = output;
      display.description = description;
      display.name = WideToUtf8(description.DeviceName);
      display.id = PersistentDisplayId(description.DeviceName);
      display.primary = description.Monitor == primary_monitor;
      display.dpi_scale = DpiScaleForRect(bounds);
      displays.push_back(std::move(display));
    }
  }
  if (displays.empty()) {
    throw std::runtime_error("Windows no informó ninguna pantalla activa.");
  }
  return displays;
}

EncodableMap DisplayToMap(const DisplayOutput& display) {
  const RECT bounds = display.description.DesktopCoordinates;
  return {{EncodableValue("id"), EncodableValue(display.id)},
          {EncodableValue("name"), EncodableValue(display.name)},
          {EncodableValue("left"), EncodableValue(bounds.left)},
          {EncodableValue("top"), EncodableValue(bounds.top)},
          {EncodableValue("width"),
           EncodableValue(bounds.right - bounds.left)},
          {EncodableValue("height"),
           EncodableValue(bounds.bottom - bounds.top)},
          {EncodableValue("dpiScale"), EncodableValue(display.dpi_scale)},
          {EncodableValue("primary"), EncodableValue(display.primary)},
          {EncodableValue("rotation"),
           EncodableValue(static_cast<int>(display.description.Rotation))}};
}

const EncodableValue* FindValue(const EncodableMap& map,
                                const char* key) {
  const auto iterator = map.find(EncodableValue(key));
  return iterator == map.end() ? nullptr : &iterator->second;
}

int ReadInt(const EncodableMap& map, const char* key) {
  const EncodableValue* value = FindValue(map, key);
  if (value == nullptr) {
    throw std::invalid_argument(std::string("Falta ") + key + ".");
  }
  if (const auto* number = std::get_if<int32_t>(value)) {
    return *number;
  }
  if (const auto* number = std::get_if<int64_t>(value)) {
    return static_cast<int>(*number);
  }
  throw std::invalid_argument(std::string(key) + " debe ser entero.");
}

std::string ReadString(const EncodableMap& map, const char* key) {
  const EncodableValue* value = FindValue(map, key);
  if (value == nullptr) {
    return {};
  }
  const auto* text = std::get_if<std::string>(value);
  return text == nullptr ? std::string() : *text;
}

class DuplicationSession {
 public:
  explicit DuplicationSession(const DisplayOutput& display)
      : display_id_(display.id), display_name_(display.name) {
    Initialize(display);
  }

  const std::string& display_id() const { return display_id_; }
  const std::string& display_name() const { return display_name_; }

  std::vector<uint8_t> Capture(int local_left, int local_top, int width,
                               int height) {
    for (int attempt = 0; attempt < 2; ++attempt) {
      try {
        return CaptureOnce(local_left, local_top, width, height);
      } catch (const std::runtime_error&) {
        if (attempt != 0) {
          throw;
        }
        Reinitialize();
      }
    }
    throw std::runtime_error("No se pudo recuperar la captura DXGI.");
  }

 private:
  void Initialize(const DisplayOutput& display) {
    display_id_ = display.id;
    display_name_ = display.name;
    adapter_ = display.adapter;
    output_ = display.output;
    output_description_ = display.description;

    const UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
    D3D_FEATURE_LEVEL selected_level;
    const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_1,
                                        D3D_FEATURE_LEVEL_11_0,
                                        D3D_FEATURE_LEVEL_10_1,
                                        D3D_FEATURE_LEVEL_10_0};
    HRESULT result = D3D11CreateDevice(
        adapter_.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr, flags, levels,
        static_cast<UINT>(std::size(levels)), D3D11_SDK_VERSION,
        device_.GetAddressOf(), &selected_level, context_.GetAddressOf());
    if (result == E_INVALIDARG) {
      result = D3D11CreateDevice(
          adapter_.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr, flags, levels + 1,
          static_cast<UINT>(std::size(levels) - 1), D3D11_SDK_VERSION,
          device_.GetAddressOf(), &selected_level, context_.GetAddressOf());
    }
    if (FAILED(result)) {
      throw std::runtime_error("No se pudo crear el dispositivo Direct3D.");
    }
    ComPtr<IDXGIOutput1> output_one;
    if (FAILED(output_.As(&output_one)) ||
        FAILED(output_one->DuplicateOutput(device_.Get(),
                                           duplication_.GetAddressOf()))) {
      throw std::runtime_error("No se pudo iniciar Desktop Duplication.");
    }
  }

  void Reinitialize() {
    staging_.Reset();
    desktop_.Reset();
    duplication_.Reset();
    context_.Reset();
    device_.Reset();
    output_.Reset();
    adapter_.Reset();
    const auto displays = EnumerateOutputs();
    const auto iterator = std::find_if(
        displays.begin(), displays.end(), [this](const DisplayOutput& display) {
          return display.id == display_id_ || display.name == display_name_;
        });
    if (iterator == displays.end()) {
      throw std::runtime_error("La pantalla calibrada ya no está disponible.");
    }
    Initialize(*iterator);
  }

  void AcquireLatestFrame() {
    DXGI_OUTDUPL_FRAME_INFO frame_info = {};
    ComPtr<IDXGIResource> resource;
    const UINT timeout = desktop_ == nullptr ? 100 : 0;
    const HRESULT result = duplication_->AcquireNextFrame(
        timeout, &frame_info, resource.GetAddressOf());
    if (result == DXGI_ERROR_WAIT_TIMEOUT && desktop_ != nullptr) {
      return;
    }
    if (FAILED(result)) {
      throw std::runtime_error("Desktop Duplication perdió la pantalla.");
    }
    ComPtr<ID3D11Texture2D> frame;
    const HRESULT query_result = resource.As(&frame);
    if (SUCCEEDED(query_result)) {
      D3D11_TEXTURE2D_DESC description = {};
      frame->GetDesc(&description);
      if (desktop_ == nullptr) {
        D3D11_TEXTURE2D_DESC copy_description = description;
        copy_description.Usage = D3D11_USAGE_DEFAULT;
        copy_description.BindFlags = 0;
        copy_description.CPUAccessFlags = 0;
        copy_description.MiscFlags = 0;
        copy_description.MipLevels = 1;
        copy_description.ArraySize = 1;
        if (FAILED(device_->CreateTexture2D(&copy_description, nullptr,
                                            desktop_.GetAddressOf()))) {
          duplication_->ReleaseFrame();
          throw std::runtime_error("No se pudo reservar el frame DXGI.");
        }
      }
      context_->CopyResource(desktop_.Get(), frame.Get());
    }
    duplication_->ReleaseFrame();
    if (FAILED(query_result)) {
      throw std::runtime_error("DXGI devolvió un frame incompatible.");
    }
  }

  void EnsureStaging(int width, int height, DXGI_FORMAT format) {
    if (staging_ != nullptr && staging_width_ == width &&
        staging_height_ == height && staging_format_ == format) {
      return;
    }
    staging_.Reset();
    D3D11_TEXTURE2D_DESC description = {};
    description.Width = static_cast<UINT>(width);
    description.Height = static_cast<UINT>(height);
    description.MipLevels = 1;
    description.ArraySize = 1;
    description.Format = format;
    description.SampleDesc.Count = 1;
    description.Usage = D3D11_USAGE_STAGING;
    description.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    if (FAILED(device_->CreateTexture2D(&description, nullptr,
                                        staging_.GetAddressOf()))) {
      throw std::runtime_error("No se pudo reservar la lectura DXGI.");
    }
    staging_width_ = width;
    staging_height_ = height;
    staging_format_ = format;
  }

  std::vector<uint8_t> CaptureOnce(int local_left, int local_top, int width,
                                   int height) {
    if (width <= 0 || height <= 0 || local_left < 0 || local_top < 0) {
      throw std::invalid_argument("La región de captura no es válida.");
    }
    const RECT bounds = output_description_.DesktopCoordinates;
    const int display_width = bounds.right - bounds.left;
    const int display_height = bounds.bottom - bounds.top;
    if (local_left + width > display_width ||
        local_top + height > display_height) {
      throw std::invalid_argument(
          "La región calibrada ya no cabe en la pantalla seleccionada.");
    }
    AcquireLatestFrame();
    if (desktop_ == nullptr) {
      throw std::runtime_error("DXGI todavía no entregó un frame.");
    }
    D3D11_TEXTURE2D_DESC source_description = {};
    desktop_->GetDesc(&source_description);
    const bool rotated = output_description_.Rotation != DXGI_MODE_ROTATION_IDENTITY &&
                         output_description_.Rotation != DXGI_MODE_ROTATION_UNSPECIFIED;
    const int read_width = rotated ? static_cast<int>(source_description.Width) : width;
    const int read_height = rotated ? static_cast<int>(source_description.Height) : height;
    EnsureStaging(read_width, read_height, source_description.Format);
    if (rotated) {
      context_->CopyResource(staging_.Get(), desktop_.Get());
    } else {
      const D3D11_BOX source_box = {
          static_cast<UINT>(local_left), static_cast<UINT>(local_top), 0,
          static_cast<UINT>(local_left + width),
          static_cast<UINT>(local_top + height), 1};
      context_->CopySubresourceRegion(staging_.Get(), 0, 0, 0, 0,
                                      desktop_.Get(), 0, &source_box);
    }

    D3D11_MAPPED_SUBRESOURCE mapped = {};
    if (FAILED(context_->Map(staging_.Get(), 0, D3D11_MAP_READ, 0, &mapped))) {
      throw std::runtime_error("No se pudo leer el frame DXGI.");
    }
    std::vector<uint8_t> pixels(static_cast<size_t>(width) * height * 4);
    const auto* source = static_cast<const uint8_t*>(mapped.pData);
    if (!rotated) {
      for (int row = 0; row < height; ++row) {
        std::memcpy(pixels.data() + static_cast<size_t>(row) * width * 4,
                    source + static_cast<size_t>(row) * mapped.RowPitch,
                    static_cast<size_t>(width) * 4);
      }
    } else {
      const int source_width = static_cast<int>(source_description.Width);
      const int source_height = static_cast<int>(source_description.Height);
      for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
          const int logical_x = local_left + x;
          const int logical_y = local_top + y;
          int source_x = logical_x;
          int source_y = logical_y;
          switch (output_description_.Rotation) {
            case DXGI_MODE_ROTATION_ROTATE90:
              source_x = logical_y;
              source_y = source_height - 1 - logical_x;
              break;
            case DXGI_MODE_ROTATION_ROTATE180:
              source_x = source_width - 1 - logical_x;
              source_y = source_height - 1 - logical_y;
              break;
            case DXGI_MODE_ROTATION_ROTATE270:
              source_x = source_width - 1 - logical_y;
              source_y = logical_x;
              break;
            default:
              break;
          }
          if (source_x < 0 || source_y < 0 || source_x >= source_width ||
              source_y >= source_height) {
            continue;
          }
          const size_t source_offset =
              static_cast<size_t>(source_y) * mapped.RowPitch +
              static_cast<size_t>(source_x) * 4;
          const size_t target_offset =
              (static_cast<size_t>(y) * width + x) * 4;
          std::memcpy(pixels.data() + target_offset, source + source_offset, 4);
        }
      }
    }
    context_->Unmap(staging_.Get(), 0);
    return pixels;
  }

  std::string display_id_;
  std::string display_name_;
  ComPtr<IDXGIAdapter1> adapter_;
  ComPtr<IDXGIOutput> output_;
  DXGI_OUTPUT_DESC output_description_ = {};
  ComPtr<ID3D11Device> device_;
  ComPtr<ID3D11DeviceContext> context_;
  ComPtr<IDXGIOutputDuplication> duplication_;
  ComPtr<ID3D11Texture2D> desktop_;
  ComPtr<ID3D11Texture2D> staging_;
  int staging_width_ = 0;
  int staging_height_ = 0;
  DXGI_FORMAT staging_format_ = DXGI_FORMAT_UNKNOWN;
};

class DesktopCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<DesktopCapturePlugin>(registrar);
    registrar->AddPlugin(std::move(plugin));
  }

  explicit DesktopCapturePlugin(flutter::PluginRegistrarWindows* registrar) {
    channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
        registrar->messenger(), "godsense/desktop_capture",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          HandleMethodCall(call, std::move(result));
        });
  }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    try {
      if (call.method_name() == "getDisplays") {
        flutter::EncodableList values;
        for (const auto& display : EnumerateOutputs()) {
          values.emplace_back(DisplayToMap(display));
        }
        result->Success(EncodableValue(values));
        return;
      }
      if (call.method_name() != "capture") {
        result->NotImplemented();
        return;
      }
      const auto* arguments = std::get_if<EncodableMap>(call.arguments());
      if (arguments == nullptr) {
        throw std::invalid_argument("Faltan los datos de captura.");
      }
      const int global_left = ReadInt(*arguments, "left");
      const int global_top = ReadInt(*arguments, "top");
      const int width = ReadInt(*arguments, "width");
      const int height = ReadInt(*arguments, "height");
      const std::string requested_id = ReadString(*arguments, "displayId");
      const auto displays = EnumerateOutputs();
      auto selected = displays.end();
      if (!requested_id.empty()) {
        selected = std::find_if(
            displays.begin(), displays.end(),
            [&requested_id](const DisplayOutput& display) {
              return display.id == requested_id;
            });
        if (selected == displays.end()) {
          throw std::runtime_error(
              "La pantalla calibrada no está disponible en este momento.");
        }
      } else {
        selected = std::find_if(
            displays.begin(), displays.end(),
            [global_left, global_top, width, height](const DisplayOutput& display) {
              const RECT bounds = display.description.DesktopCoordinates;
              return global_left >= bounds.left && global_top >= bounds.top &&
                     global_left + width <= bounds.right &&
                     global_top + height <= bounds.bottom;
            });
      }
      if (selected == displays.end()) {
        throw std::invalid_argument(
            "La región no pertenece por completo a ninguna pantalla activa.");
      }
      const RECT display_bounds = selected->description.DesktopCoordinates;
      int local_left = global_left - display_bounds.left;
      int local_top = global_top - display_bounds.top;
      if (!requested_id.empty() && requested_id == selected->id) {
        const EncodableValue* local_left_value =
            FindValue(*arguments, "localLeft");
        const EncodableValue* local_top_value = FindValue(*arguments, "localTop");
        if (local_left_value != nullptr && local_top_value != nullptr) {
          local_left = ReadInt(*arguments, "localLeft");
          local_top = ReadInt(*arguments, "localTop");
        }
      }
      if (session_ == nullptr || session_->display_id() != selected->id) {
        session_ = std::make_unique<DuplicationSession>(*selected);
      }
      const auto started = std::chrono::steady_clock::now();
      auto pixels = session_->Capture(local_left, local_top, width, height);
      const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(
                               std::chrono::steady_clock::now() - started)
                               .count();
      EncodableMap response = DisplayToMap(*selected);
      response[EncodableValue("captureWidth")] = EncodableValue(width);
      response[EncodableValue("captureHeight")] = EncodableValue(height);
      response[EncodableValue("localLeft")] = EncodableValue(local_left);
      response[EncodableValue("localTop")] = EncodableValue(local_top);
      response[EncodableValue("captureMicroseconds")] =
          EncodableValue(static_cast<int64_t>(elapsed));
      response[EncodableValue("bgra")] = EncodableValue(std::move(pixels));
      result->Success(EncodableValue(response));
    } catch (const std::exception& error) {
      session_.reset();
      result->Error("CAPTURE_FAILED", error.what());
    }
  }

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<DuplicationSession> session_;
};

}  // namespace

void DesktopCapturePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  DesktopCapturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
