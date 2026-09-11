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
  !define GHOSIUM_PORTABLE_PROFILE_SWITCH "--ghosium-portable-profile"
!endif

!define PRODUCT_NAME "Ghosium Browser"
!define PRODUCT_EXE "Ghosium-Browser.exe"
!define PORTABLE_RUNTIME_DIR ".ghosium-portable-runtime"
!define PORTABLE_DATA_DIR "Ghosium-Portable-Data"
!define PORTABLE_READY_MARKER ".ghosium-runtime-ready"

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
Var PortableStage
Var PortableReady

Function VerifyPortableRuntime
  StrCpy $PortableReady "0"
  IfFileExists "$PortableRuntime\${PRODUCT_EXE}" 0 portable_verify_done
  IfFileExists "$PortableRuntime\LICENSE" 0 portable_verify_done
  IfFileExists "$PortableRuntime\THIRD_PARTY_NOTICES.md" 0 portable_verify_done
  IfFileExists "$PortableRuntime\${PORTABLE_READY_MARKER}" 0 portable_verify_done

  ClearErrors
  FileOpen $R8 "$PortableRuntime\${PORTABLE_READY_MARKER}" r
  IfErrors portable_verify_done
  FileRead $R8 $R9
  FileClose $R8
  StrCmp $R9 "Ghosium Portable Runtime|${GHOSIUM_VERSION}$\r$\n" 0 portable_verify_done
  StrCpy $PortableReady "1"
portable_verify_done:
FunctionEnd

Function PreparePortableRuntime
  Call VerifyPortableRuntime
  StrCmp $PortableReady "1" portable_prepare_done

  System::Call 'kernel32::GetCurrentProcessId() i .r0'
  StrCpy $PortableStage "$EXEDIR\${PORTABLE_RUNTIME_DIR}\${GHOSIUM_VERSION}.stage-$0"

  RMDir /r "$PortableStage"
  ClearErrors
  CreateDirectory "$PortableStage"
  IfErrors portable_prepare_error
  SetOutPath "$PortableStage"
  ClearErrors
  File /r "${GHOSIUM_STAGE}\*.*"
  IfErrors portable_prepare_error

  IfFileExists "$PortableStage\${PRODUCT_EXE}" 0 portable_prepare_error
  IfFileExists "$PortableStage\LICENSE" 0 portable_prepare_error
  IfFileExists "$PortableStage\THIRD_PARTY_NOTICES.md" 0 portable_prepare_error

  ClearErrors
  FileOpen $R8 "$PortableStage\${PORTABLE_READY_MARKER}" w
  IfErrors portable_prepare_error
  FileWrite $R8 "Ghosium Portable Runtime|${GHOSIUM_VERSION}$\r$\n"
  FileClose $R8

  ; Another Ghosium Portable process may have completed the same version while
  ; this process was extracting its private staging directory. Prefer the
  ; already-verified runtime instead of deleting or replacing a live tree.
  Call VerifyPortableRuntime
  StrCmp $PortableReady "1" portable_concurrent_ready

  ; The destination is a fixed product-owned version directory, never a caller
  ; supplied path. An incomplete cache is safe to replace; user data lives in
  ; the separate Ghosium-Portable-Data directory and is never removed here.
  RMDir /r "$PortableRuntime"
  ClearErrors
  Rename "$PortableStage" "$PortableRuntime"
  IfErrors portable_rename_race
  Goto portable_prepare_done

portable_rename_race:
  ; If a concurrent instance won the rename race, accept it only after the full
  ; runtime marker/core-file contract succeeds. Otherwise fail closed.
  Call VerifyPortableRuntime
  StrCmp $PortableReady "1" portable_concurrent_ready portable_prepare_error

portable_concurrent_ready:
  RMDir /r "$PortableStage"
  Goto portable_prepare_done

portable_prepare_error:
  RMDir /r "$PortableStage"
  MessageBox MB_ICONSTOP|MB_OK "Ghosium Portable could not prepare its verified runtime. Move the package to a writable local folder or download a fresh official package."
  SetErrorLevel 21
  Quit

portable_prepare_done:
FunctionEnd

Function .onInit
  ${GetParameters} $PortableArgs

  StrCpy $PortableRuntime "$EXEDIR\${PORTABLE_RUNTIME_DIR}\${GHOSIUM_VERSION}"
  StrCpy $PortableProfile "$EXEDIR\${PORTABLE_DATA_DIR}"

  ClearErrors
  CreateDirectory "$EXEDIR\${PORTABLE_RUNTIME_DIR}"
  CreateDirectory "$PortableProfile"
  IfErrors portable_path_error

  Call PreparePortableRuntime
  Call VerifyPortableRuntime
  StrCmp $PortableReady "1" portable_launch portable_runtime_error

portable_launch:
  ; Caller arguments are forwarded through Ghosium's hardened launcher. The
  ; private portable-profile switch is appended last so a user-supplied profile
  ; argument can never escape the adjacent Ghosium-Portable-Data directory.
  ; The launcher itself rejects unsafe sandbox/certificate/debugging overrides.
  ClearErrors
  ExecWait '"$PortableRuntime\${PRODUCT_EXE}" $PortableArgs "${GHOSIUM_PORTABLE_PROFILE_SWITCH}=$PortableProfile"' $0
  IfErrors portable_launch_error
  SetErrorLevel $0
  Quit

portable_path_error:
  MessageBox MB_ICONSTOP|MB_OK "Ghosium Portable cannot write beside this executable. Move it to a writable local folder and try again."
  SetErrorLevel 20
  Quit

portable_runtime_error:
  MessageBox MB_ICONSTOP|MB_OK "Ghosium Portable could not verify its local runtime. Download a fresh official package."
  SetErrorLevel 21
  Quit

portable_launch_error:
  MessageBox MB_ICONSTOP|MB_OK "Ghosium Portable could not start the browser. Check folder permissions and try again."
  SetErrorLevel 22
  Quit
FunctionEnd

Section
SectionEnd
