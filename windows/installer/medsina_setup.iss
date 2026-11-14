#ifndef MyAppName
  #define MyAppName "Medsina"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.0.30"
#endif
#define MyAppPublisher "Medsina Sante Algerie"
#define MyAppURL "https://medsina.medevsync.com"
#ifndef MyAppExeName
  #define MyAppExeName "medsina.exe"
#endif
#ifndef MyAppGuid
  #define MyAppGuid "C64A2F02-5369-45B1-9DF8-97E4A8D9F21B"
#endif
#ifndef MyOutputDir
  #define MyOutputDir "..\..\win-dist"
#endif
#ifndef MyOutputBaseFilename
  #define MyOutputBaseFilename "Medsina_Windows_Setup"
#endif
#ifndef MyReleaseDir
  #define MyReleaseDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef MyIconFile
  #define MyIconFile "..\runner\resources\app_icon.ico"
#endif

[Setup]
; Unique GUID identifying the app across updates
AppId={{{#MyAppGuid}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\app_icon.ico
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Professional ultra compression
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile={#MyIconFile}
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseFilename}
; Force Windows Shell to refresh icon cache upon install & uninstall
ChangesAssociations=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyIconFile}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
