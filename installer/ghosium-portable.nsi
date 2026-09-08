Unicode true
!include "FileFunc.nsh"
!pragma warning error all

!ifndef GHOSIUM_VERSION
  !define GHOSIUM_VERSION "0.0.0"
!endif
!ifndef GHOSIUM_STAGE
  !error "GHOSIUM_STAGE must point to the assembled Ghosium directory"
!endif
!ifndef GHOSIUM_ARTIFACTS
  !error "GHOSIUM_ARTIFACTS must point to the release artifact directory"
!endif
!ifndef GHOSIUM_ICON
  !define GHOSIUM_ICON "${__FILEDIR__}\..\ghosium.ico"
!endif
!ifndef GHOSIUM_PORTABLE_PROFILE_SWITCH
  !define GHOSIUM_PORTABLE_PROFILE_SWITCH "--user-data-dir"
!endif

!define PRODUCT_NAME "Ghosium Browser"
!define PRODUCT_EXE "Ghosium-Browser.exe"
!define PORTABLE_RUNTIME_DIR ".ghosium-portable-runtime"
!define PORTABLE_DATA_DIR "Ghosium-Portable-Data"

Name "${PRODUCT_NAME} ${GHOSIUM_VERSION} Portable"
OutFile "${GHOSIUM_ARTIFACTS}\Ghosium-Browser-Portable.exe"
RequestExecutionLevel user
SilentInstall silent
AutoCloseWindow true
SetCompress auto
SetCompressor zlib
Icon "${GHOSIUM_ICON}"

VIProductVersion "${GHOSIUM_VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "Ghosium Browser"
VIAddVersionKey /LANG=1033 "CompanyName" "Brendigo"
VIAddVersionKey /LANG=1033 "FileDescription" "Ghosium Browser Portable"
VIAddVersionKey /LANG=1033 "FileVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (c) 2026 Brendigo"

Var PortableRuntime
Var PortableProfile
Var PortableArgs

Function .onInit
  ${GetParameters} $PortableArgs

  StrCpy $PortableRuntime "$EXEDIR\${PORTABLE_RUNTIME_DIR}\${GHOSIUM_VERSION}"
  StrCpy $PortableProfile "$EXEDIR\${PORTABLE_DATA_DIR}"

  ClearErrors
  CreateDirectory "$EXEDIR\${PORTABLE_RUNTIME_DIR}"
  CreateDirectory "$PortableRuntime"
  CreateDirectory "$PortableProfile"
  IfErrors portable_path_error

  SetOutPath "$PortableRuntime"
  File /r "${GHOSIUM_STAGE}\*.*"

  IfFileExists "$PortableRuntime\${PRODUCT_EXE}" 0 portable_runtime_error
  IfFileExists "$PortableRuntime\LICENSE" 0 portable_runtime_error
  IfFileExists "$PortableRuntime\THIRD_PARTY_NOTICES.md" 0 portable_runtime_error

  ; Portable mode is deliberately registry-free. Caller arguments are forwarded,
  ; but the fixed profile switch is intentionally appended last so a duplicate
  ; caller-provided --user-data-dir cannot escape the adjacent Portable profile.
  ; No default-browser registration, shortcuts, updater or uninstall entries are
  ; created by this package.
  ExecWait '"$PortableRuntime\${PRODUCT_EXE}" --no-first-run --no-default-browser-check $PortableArgs "${GHOSIUM_PORTABLE_PROFILE_SWITCH}=$PortableProfile"' $0
  SetErrorLevel $0
  Quit

portable_path_error:
  MessageBox MB_ICONSTOP|MB_OK "Ghosium Portable cannot write beside this executable. Move it to a writable folder and try again."
  SetErrorLevel 20
  Quit

portable_runtime_error:
  MessageBox MB_ICONSTOP|MB_OK "Ghosium Portable could not prepare its verified runtime. Download a fresh official package."
  SetErrorLevel 21
  Quit
FunctionEnd

Section
SectionEnd
