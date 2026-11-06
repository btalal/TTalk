#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // A single instance owns the local encrypted vault in this Windows session.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, FALSE, L"Local\\com.talal.ttalk");
  if (instance_mutex == nullptr) {
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"TTalk");
    if (existing != nullptr) {
      ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Same default window as macOS (800 x 600, centred): the compact layout with
  // Discussions, Contacts and Réglages at the bottom. Maximising the window
  // switches to the two-column layout on both platforms.
  constexpr int kWidth = 800;
  constexpr int kHeight = 600;
  RECT work_area;
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  HMONITOR primary = ::MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  const double scale = FlutterDesktopGetDpiForMonitor(primary) / 96.0;
  const int work_width = static_cast<int>((work_area.right - work_area.left) / scale);
  const int work_height = static_cast<int>((work_area.bottom - work_area.top) / scale);
  Win32Window::Point origin(
      static_cast<unsigned int>(work_area.left / scale + (work_width > kWidth ? (work_width - kWidth) / 2 : 0)),
      static_cast<unsigned int>(work_area.top / scale + (work_height > kHeight ? (work_height - kHeight) / 2 : 0)));
  Win32Window::Size size(kWidth, kHeight);
  if (!window.Create(L"TTalk", origin, size)) {
    ::CoUninitialize();
    ::CloseHandle(instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
