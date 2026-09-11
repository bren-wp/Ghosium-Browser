#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>

#include <algorithm>
#include <cwctype>
#include <filesystem>
#include <fstream>
#include <string>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

namespace {

constexpr wchar_t kProductName[] = L"Ghosium Browser";
constexpr wchar_t kCompanyDirectory[] = L"Brendigo";
constexpr wchar_t kProfileDirectory[] = L"Ghosium";
constexpr wchar_t kEngineExecutable[] = L"Ghosium-Engine.exe";
constexpr wchar_t kSelfTestSwitch[] = L"--ghosium-self-test";
constexpr wchar_t kWaitSwitch[] = L"--ghosium-wait";
constexpr wchar_t kPortableProfilePrefix[] = L"--ghosium-portable-profile=";
constexpr wchar_t kLanguagePrefix[] = L"--ghosium-language=";

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t ch) {
    return static_cast<wchar_t>(std::towlower(ch));
  });
  return value;
}

bool StartsWithInsensitive(const std::wstring& value, const std::wstring& prefix) {
  return value.size() >= prefix.size() &&
         ToLower(value.substr(0, prefix.size())) == ToLower(prefix);
}

std::wstring QuoteArgument(const std::wstring& argument) {
  if (argument.empty()) {
    return L"\"\"";
  }
  if (argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) {
    return argument;
  }

  std::wstring result = L"\"";
  size_t backslashes = 0;
  for (const wchar_t ch : argument) {
    if (ch == L'\\') {
      ++backslashes;
      continue;
    }
    if (ch == L'\"') {
      result.append(backslashes * 2 + 1, L'\\');
      result.push_back(L'\"');
      backslashes = 0;
      continue;
    }
    result.append(backslashes, L'\\');
    backslashes = 0;
    result.push_back(ch);
  }
  result.append(backslashes * 2, L'\\');
  result.push_back(L'\"');
  return result;
}

fs::path ExecutableDirectory() {
  std::wstring buffer(32768, L'\0');
  const DWORD length =
      GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    return {};
  }
  buffer.resize(length);
  return fs::path(buffer).parent_path();
}

fs::path LocalProfileDirectory() {
  wchar_t buffer[MAX_PATH]{};
  const HRESULT result = SHGetFolderPathW(
      nullptr, CSIDL_LOCAL_APPDATA | CSIDL_FLAG_CREATE, nullptr,
      SHGFP_TYPE_CURRENT, buffer);
  if (FAILED(result) || buffer[0] == L'\0') {
    return {};
  }
  return fs::path(buffer) / kCompanyDirectory / kProfileDirectory / L"User Data";
}

fs::path NormalizeProfilePath(const fs::path& value) {
  if (value.empty()) {
    return {};
  }
  std::error_code error;
  fs::path normalized = fs::absolute(value, error);
  if (error || normalized.empty()) {
    return {};
  }
  return normalized.lexically_normal();
}

std::wstring ReadFirstLine(const fs::path& path) {
  std::wifstream stream(path);
  std::wstring line;
  if (!stream.good() || !std::getline(stream, line)) {
    return {};
  }
  while (!line.empty() && std::iswspace(line.back())) {
    line.pop_back();
  }
  while (!line.empty() && std::iswspace(line.front())) {
    line.erase(line.begin());
  }
  return line;
}

bool IsValidLocale(const std::wstring& locale) {
  if (locale.size() < 2 || locale.size() > 18) {
    return false;
  }
  for (const wchar_t ch : locale) {
    if (!((ch >= L'a' && ch <= L'z') || (ch >= L'A' && ch <= L'Z') ||
          (ch >= L'0' && ch <= L'9') || ch == L'-')) {
      return false;
    }
  }
  return true;
}

std::wstring WindowsErrorText(DWORD code) {
  LPWSTR raw = nullptr;
  const DWORD length = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&raw), 0, nullptr);
  if (length == 0 || raw == nullptr) {
    return L"Windows error " + std::to_wstring(code);
  }
  std::wstring text(raw, length);
  LocalFree(raw);
  while (!text.empty() && std::iswspace(text.back())) {
    text.pop_back();
  }
  return text + L" (" + std::to_wstring(code) + L")";
}

void ShowError(const std::wstring& message) {
  MessageBoxW(nullptr, message.c_str(), kProductName,
              MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
}

bool CoreFilesExist(const fs::path& root) {
  std::error_code error;
  return fs::is_regular_file(root / L"runtime" / kEngineExecutable, error) &&
         fs::is_regular_file(root / L"extension" / L"manifest.json", error) &&
         fs::is_regular_file(root / L"extension" / L"rules.json", error) &&
         fs::is_regular_file(root / L"extension" / L"newtab.html", error) &&
         fs::is_regular_file(root / L"extension" / L"newtab.css", error);
}

bool IsInternalSwitch(const std::wstring& argument) {
  const std::wstring lowered = ToLower(argument);
  return lowered == kSelfTestSwitch || lowered == kWaitSwitch ||
         StartsWithInsensitive(lowered, kPortableProfilePrefix) ||
         StartsWithInsensitive(lowered, kLanguagePrefix);
}

bool IsProtectedArgument(const std::wstring& argument, bool* consumes_next) {
  *consumes_next = false;
  const std::wstring lowered = ToLower(argument);
  const std::vector<std::wstring> valued = {
      L"--user-data-dir", L"--load-extension", L"--disable-extensions-except",
      L"--remote-debugging-port", L"--lang"};

  for (const auto& option : valued) {
    if (lowered == option) {
      *consumes_next = true;
      return true;
    }
    if (StartsWithInsensitive(lowered, option + L"=")) {
      return true;
    }
  }

  return lowered == L"--enable-crash-reporter" ||
         lowered == L"--enable-sync" ||
         lowered == L"--disable-extensions" ||
         lowered == L"--no-sandbox" ||
         lowered == L"--disable-web-security" ||
         lowered == L"--ignore-certificate-errors" ||
         lowered == L"--allow-running-insecure-content" ||
         lowered == L"--remote-debugging-pipe" || IsInternalSwitch(lowered);
}

bool IsValidHandle(HANDLE handle) {
  return handle != nullptr && handle != INVALID_HANDLE_VALUE;
}

HANDLE DuplicateForChild(HANDLE source) {
  if (!IsValidHandle(source)) {
    return nullptr;
  }
  HANDLE duplicate = nullptr;
  if (!DuplicateHandle(GetCurrentProcess(), source, GetCurrentProcess(),
                       &duplicate, 0, TRUE, DUPLICATE_SAME_ACCESS)) {
    return nullptr;
  }
  return duplicate;
}

void ApplyLauncherMitigations() {
  SetDllDirectoryW(L"");
  PROCESS_MITIGATION_IMAGE_LOAD_POLICY policy{};
  policy.NoRemoteImages = 1;
  policy.NoLowMandatoryLabelImages = 1;
  SetProcessMitigationPolicy(ProcessImageLoadPolicy, &policy, sizeof(policy));
}

}  // namespace

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int) {
  ApplyLauncherMitigations();

  const fs::path root = ExecutableDirectory();
  if (root.empty() || !CoreFilesExist(root)) {
    ShowError(L"Ghosium Browser files are incomplete. Reinstall or download a fresh official package.");
    return 2;
  }

  int argc = 0;
  LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) {
    ShowError(L"Ghosium Browser could not read the launch command.");
    return 3;
  }

  bool wait_for_engine = false;
  bool headless_mode = false;
  fs::path portable_profile;
  std::wstring requested_locale;

  for (int index = 1; index < argc; ++index) {
    const std::wstring argument = argv[index];
    const std::wstring lowered = ToLower(argument);
    if (lowered == kSelfTestSwitch) {
      LocalFree(argv);
      return 0;
    }
    if (lowered == kWaitSwitch) {
      wait_for_engine = true;
    } else if (lowered == L"--dump-dom" ||
               StartsWithInsensitive(lowered, L"--headless")) {
      headless_mode = true;
      wait_for_engine = true;
    } else if (StartsWithInsensitive(argument, kPortableProfilePrefix)) {
      portable_profile = fs::path(
          argument.substr(std::wstring(kPortableProfilePrefix).size()));
    } else if (StartsWithInsensitive(argument, kLanguagePrefix)) {
      requested_locale =
          argument.substr(std::wstring(kLanguagePrefix).size());
    }
  }

  const fs::path runtime_directory = root / L"runtime";
  const fs::path engine_executable = runtime_directory / kEngineExecutable;
  const fs::path privacy_extension = root / L"extension";

  fs::path profile_directory = portable_profile.empty()
                                   ? LocalProfileDirectory()
                                   : NormalizeProfilePath(portable_profile);
  if (profile_directory.empty()) {
    LocalFree(argv);
    ShowError(L"Ghosium Browser could not resolve a safe local profile directory.");
    return 4;
  }

  std::error_code directory_error;
  fs::create_directories(profile_directory, directory_error);
  if (directory_error) {
    LocalFree(argv);
    ShowError(L"Ghosium Browser could not prepare the selected local profile. Check folder permissions and try again.");
    return 4;
  }

  std::wstring locale = requested_locale;
  if (locale.empty()) {
    locale = ReadFirstLine(root / L"ghosium-language.txt");
  }
  if (!IsValidLocale(locale)) {
    locale = L"en-US";
  }

  std::vector<std::wstring> arguments;
  arguments.emplace_back(engine_executable.wstring());
  arguments.emplace_back(L"--user-data-dir=" + profile_directory.wstring());
  arguments.emplace_back(L"--load-extension=" + privacy_extension.wstring());
  arguments.emplace_back(L"--lang=" + locale);
  arguments.emplace_back(L"--disable-sync");
  arguments.emplace_back(L"--disable-breakpad");
  arguments.emplace_back(L"--disable-background-mode");
  arguments.emplace_back(L"--disable-domain-reliability");
  arguments.emplace_back(L"--no-pings");
  arguments.emplace_back(L"--no-first-run");
  arguments.emplace_back(L"--no-default-browser-check");

  for (int index = 1; index < argc; ++index) {
    bool consumes_next = false;
    if (IsProtectedArgument(argv[index], &consumes_next)) {
      if (consumes_next && index + 1 < argc) {
        ++index;
      }
      continue;
    }
    arguments.emplace_back(argv[index]);
  }
  LocalFree(argv);

  std::wstring command_line;
  for (size_t index = 0; index < arguments.size(); ++index) {
    if (index != 0) {
      command_line.push_back(L' ');
    }
    command_line.append(QuoteArgument(arguments[index]));
  }

  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  BOOL inherit_handles = FALSE;
  HANDLE child_stdin = nullptr;
  HANDLE child_stdout = nullptr;
  HANDLE child_stderr = nullptr;

  if (headless_mode) {
    child_stdin = DuplicateForChild(GetStdHandle(STD_INPUT_HANDLE));
    child_stdout = DuplicateForChild(GetStdHandle(STD_OUTPUT_HANDLE));
    child_stderr = DuplicateForChild(GetStdHandle(STD_ERROR_HANDLE));
    if (child_stdout && child_stderr) {
      startup_info.dwFlags |= STARTF_USESTDHANDLES;
      startup_info.hStdInput = child_stdin;
      startup_info.hStdOutput = child_stdout;
      startup_info.hStdError = child_stderr;
      inherit_handles = TRUE;
    }
  }

  PROCESS_INFORMATION process_info{};
  const BOOL created = CreateProcessW(
      engine_executable.c_str(), command_line.data(), nullptr, nullptr,
      inherit_handles, CREATE_UNICODE_ENVIRONMENT | CREATE_DEFAULT_ERROR_MODE,
      nullptr, runtime_directory.c_str(), &startup_info, &process_info);

  if (child_stdin) CloseHandle(child_stdin);
  if (child_stdout) CloseHandle(child_stdout);
  if (child_stderr) CloseHandle(child_stderr);

  if (!created) {
    const DWORD error = GetLastError();
    ShowError(L"Ghosium Browser could not start. " + WindowsErrorText(error));
    return 5;
  }

  CloseHandle(process_info.hThread);
  if (wait_for_engine) {
    WaitForSingleObject(process_info.hProcess, INFINITE);
    DWORD exit_code = 0;
    if (!GetExitCodeProcess(process_info.hProcess, &exit_code)) {
      exit_code = 6;
    }
    CloseHandle(process_info.hProcess);
    return static_cast<int>(exit_code);
  }

  CloseHandle(process_info.hProcess);
  return 0;
}
