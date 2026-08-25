!include "MUI2.nsh"

Name "RustDesk"
OutFile "rustdesk-1.4.9-install.exe"
InstallDir "$PROGRAMFILES64\RustDesk"
RequestExecutionLevel admin

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

Section "Install"
  SetOutPath "$INSTDIR"
  ; Copy the entire Release folder contents
  File /r "Release\*.*"
  ; Create uninstaller
  WriteUninstaller "$INSTDIR\uninst.exe"
  ; Start menu shortcut
  CreateDirectory "$SMPROGRAMS\RustDesk"
  CreateShortcut "$SMPROGRAMS\RustDesk\RustDesk.lnk" "$INSTDIR\rustdesk.exe"
  CreateShortcut "$SMPROGRAMS\RustDesk\Uninstall.lnk" "$INSTDIR\uninst.exe"
  ; Registry uninstall info
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" "DisplayName" "RustDesk"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" "UninstallString" "$\"$INSTDIR\uninst.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" "DisplayVersion" "1.4.9"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk" "Publisher" "Custom Build"
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\RustDesk"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk"
SectionEnd
