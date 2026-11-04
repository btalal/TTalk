#include <windows.h>

#include <string>
#include <vector>

namespace {
int ReportError(const wchar_t* message, DWORD error) {
  const std::wstring detail = std::wstring(message) + L"\n\nCode Windows : " +
                              std::to_wstring(error);
  ::MessageBoxW(nullptr, detail.c_str(), L"TTalk", MB_OK | MB_ICONERROR);
  return 1;
}
}  // namespace

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, wchar_t*, int) {
  // Resolve beside this launcher, independently of the shortcut's working folder.
  std::vector<wchar_t> path(32768);
  const DWORD length = ::GetModuleFileNameW(nullptr, path.data(),
                                           static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return ReportError(L"Impossible de localiser TTalk.", ::GetLastError());
  }
  const std::wstring location(path.data(), length);
  const auto separator = location.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return ReportError(L"Impossible de localiser le dossier TTalk.",
                       ERROR_PATH_NOT_FOUND);
  }
  const std::wstring directory = location.substr(0, separator) + L"\\app";
  const std::wstring executable = directory + L"\\ttalk.exe";
  std::wstring command = L"\"" + executable + L"\"";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION child{};
  if (!::CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr,
                        FALSE, 0, nullptr, directory.c_str(), &startup, &child)) {
    return ReportError(
        L"Impossible de lancer TTalk. Extrayez tout le ZIP et conservez le "
        L"dossier app a cote de TTalk.exe.", ::GetLastError());
  }
  ::CloseHandle(child.hThread);
  const DWORD waited = ::WaitForSingleObject(child.hProcess, INFINITE);
  DWORD exit_code = 1;
  if (waited == WAIT_OBJECT_0) {
    ::GetExitCodeProcess(child.hProcess, &exit_code);
  }
  ::CloseHandle(child.hProcess);
  return static_cast<int>(exit_code);
}
