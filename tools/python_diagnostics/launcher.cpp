#include <windows.h>

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

using PyMain = int(__cdecl*)(int, wchar_t**);
using PySetPath = void(__cdecl*)(const wchar_t*);
using PySetPythonHome = void(__cdecl*)(const wchar_t*);

int wmain(int argc, wchar_t** argv) {
  if (argc < 4) {
    std::wcerr << L"usage: scoutr_python_launcher <runtime> <pyc-root> <script> [args...]\n";
    return 2;
  }

  const std::filesystem::path runtime = std::filesystem::absolute(argv[1]);
  const std::filesystem::path pyc_root = std::filesystem::absolute(argv[2]);
  const std::filesystem::path script = std::filesystem::absolute(argv[3]);
  const std::wstring python_path =
      (runtime / L"base_library.zip").wstring() + L";" +
      runtime.wstring() + L";" + pyc_root.wstring() + L";" +
      pyc_root.parent_path().wstring() + L";" + script.parent_path().wstring();

  SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS |
                           LOAD_LIBRARY_SEARCH_USER_DIRS);
  AddDllDirectory(runtime.c_str());
  const auto numpy_libraries = runtime / L"numpy.libs";
  if (std::filesystem::exists(numpy_libraries)) {
    AddDllDirectory(numpy_libraries.c_str());
    for (const auto& entry : std::filesystem::directory_iterator(numpy_libraries)) {
      if (entry.path().extension() == L".dll" &&
          entry.path().filename().wstring().rfind(L"msvcp", 0) == 0) {
        LoadLibraryW(entry.path().c_str());
      }
    }
    for (const auto& entry : std::filesystem::directory_iterator(numpy_libraries)) {
      if (entry.path().extension() == L".dll") {
        LoadLibraryW(entry.path().c_str());
      }
    }
  }
  SetDllDirectoryW(runtime.c_str());
  SetEnvironmentVariableW(L"PYTHONHOME", runtime.c_str());
  SetEnvironmentVariableW(L"PYTHONPATH", python_path.c_str());
  SetEnvironmentVariableW(L"PYTHONUTF8", L"1");
  SetEnvironmentVariableW(L"SCOUTR_PYTHON_RUNTIME", runtime.c_str());

  const auto library = LoadLibraryW((runtime / L"python311.dll").c_str());
  if (!library) {
    std::wcerr << L"failed to load python311.dll: " << GetLastError() << L"\n";
    return 3;
  }
  const auto py_main = reinterpret_cast<PyMain>(GetProcAddress(library, "Py_Main"));
  const auto py_set_path =
      reinterpret_cast<PySetPath>(GetProcAddress(library, "Py_SetPath"));
  const auto py_set_home = reinterpret_cast<PySetPythonHome>(
      GetProcAddress(library, "Py_SetPythonHome"));
  if (!py_main || !py_set_path || !py_set_home) {
    std::wcerr << L"python311.dll is missing embedding exports\n";
    FreeLibrary(library);
    return 4;
  }

  py_set_home(runtime.c_str());
  py_set_path(python_path.c_str());

  std::vector<wchar_t*> python_argv;
  python_argv.push_back(argv[0]);
  python_argv.push_back(const_cast<wchar_t*>(script.c_str()));
  for (int index = 4; index < argc; ++index) {
    python_argv.push_back(argv[index]);
  }
  const int result = py_main(static_cast<int>(python_argv.size()),
                             python_argv.data());
  FreeLibrary(library);
  return result;
}
