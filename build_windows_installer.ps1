# Local Flutter Build Script with Inno Setup
# Requires: Flutter SDK, Inno Setup 6, Android SDK (for APK)

param(
    [string]$ReleaseType = "beta",
    [switch]$SkipAndroid = $false,
    [switch]$SkipWindows = $false,
    [switch]$Clean = $false
)

# ==================== CONFIGURATION ====================

# Auto-detect Flutter (check common locations)
$FLUTTER_PATHS = @(
    "C:\Users\$env:USERNAME\FlutterSDK\flutter\bin\flutter.bat",
    "C:\flutter\bin\flutter.bat",
    "C:\src\flutter\bin\flutter.bat",
    "$env:FLUTTER_ROOT\bin\flutter.bat"
)

$FLUTTER = $null
foreach ($path in $FLUTTER_PATHS)
{
    if (Test-Path $path)
    {
        $FLUTTER = $path
        break
    }
}

# Try flutter from PATH if not found
if (-not $FLUTTER)
{
    try
    {
        $null = Get-Command flutter -ErrorAction Stop
        $FLUTTER = "flutter"
    }
    catch
    {
        throw "Flutter non trovato! Installa Flutter o imposta il path corretto."
    }
}

# Auto-detect Inno Setup
$ISCC_PATHS = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)

$ISCC = $null
foreach ($path in $ISCC_PATHS)
{
    if (Test-Path $path)
    {
        $ISCC = $path
        break
    }
}

if (-not $ISCC -and -not $SkipWindows)
{
    Write-Warning "Inno Setup non trovato! Scarica da: https://jrsoftware.org/isdl.php"
    $SkipWindows = $true
}

# ==================== EXTRACT APP INFO ====================

if (-not (Test-Path "pubspec.yaml"))
{
    throw "File pubspec.yaml non trovato! Esegui lo script nella root del progetto Flutter."
}

$pubspec = Get-Content -Raw pubspec.yaml

# Extract APP_NAME
if ($pubspec -match 'name:\s*([^\s\r\n]+)')
{
    $APP_NAME = $matches[1].Trim()
}
else
{
    throw "Impossibile leggere il campo 'name' da pubspec.yaml"
}

# Extract APP_VERSION
if ($pubspec -match 'version:\s*([\d\.]+)')
{
    $APP_VERSION = $matches[1].Trim()
}
else
{
    throw "Impossibile leggere il campo 'version' da pubspec.yaml"
}

# ==================== BUILD INFO ====================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "        FLUTTER LOCAL BUILD SCRIPT" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "APP_NAME: $APP_NAME" -ForegroundColor Green
Write-Host "APP_VERSION: $APP_VERSION" -ForegroundColor Green
Write-Host "RELEASE_TYPE: $ReleaseType" -ForegroundColor Green
Write-Host "FLUTTER: $FLUTTER" -ForegroundColor Yellow
if (-not $SkipWindows)
{
    Write-Host "INNO SETUP: $ISCC" -ForegroundColor Yellow
}
Write-Host "============================================" -ForegroundColor Cyan

# Create dist directory
if (-not (Test-Path "dist"))
{
    New-Item -ItemType Directory -Path "dist" | Out-Null
}

# ==================== FLUTTER PREPARATION ====================

Write-Host "`nPreparing Flutter..." -ForegroundColor Magenta

if ($Clean)
{
    Write-Host "  - Cleaning project..." -ForegroundColor Gray
    & $FLUTTER clean
    if ($LASTEXITCODE -ne 0)
    {
        throw "Flutter clean failed!"
    }
}

Write-Host "  - Getting dependencies..." -ForegroundColor Gray
& $FLUTTER pub get
if ($LASTEXITCODE -ne 0)
{
    throw "Flutter pub get failed!"
}

# Check if l10n is configured
$hasL10n = $pubspec -match 'generate:\s*true' -or (Test-Path "lib/l10n")
if ($hasL10n)
{
    Write-Host "  - Generating localizations..." -ForegroundColor Gray
    & $FLUTTER gen-l10n
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "gen-l10n failed, continuing without localizations..."
    }
}

# ==================== ANDROID BUILD ====================

if (-not $SkipAndroid)
{
    Write-Host "`nBuilding Android APK..." -ForegroundColor Green

    & $FLUTTER build apk --release --build-name $APP_VERSION
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "Android build failed!"
    }
    else
    {
        $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
        $apkTarget = "dist\${APP_NAME}_v${APP_VERSION}.apk"

        if (Test-Path $apkSource)
        {
            Copy-Item $apkSource -Destination $apkTarget -Force
            Write-Host "Android APK: $apkTarget" -ForegroundColor Green
        }
        else
        {
            Write-Warning "APK non trovato in: $apkSource"
        }
    }
}

# ==================== WINDOWS BUILD ====================

if (-not $SkipWindows)
{
    Write-Host "`nBuilding Windows..." -ForegroundColor Blue

    # Enable Windows desktop
    & $FLUTTER config --enable-windows-desktop

    # Build Windows app
    Write-Host "  - Building Flutter Windows..." -ForegroundColor Gray
    & $FLUTTER build windows --release --build-name $APP_VERSION
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "Windows build failed!"
    }
    else
    {
        # ==================== INNO SETUP SCRIPT ====================

        Write-Host "  - Creating Inno Setup script..." -ForegroundColor Gray

        $ISS_FILE = "$PWD\${APP_NAME}_installer.iss"

        $ISS_CONTENT = @"
            #define AppName "$APP_NAME"
            #define AppVersion "$APP_VERSION"
            #define AppPublisher "Fede22dev"
            #define AppURL "https://github.com/Fede22dev/beauty_center"
            #define AppExeName "$APP_NAME.exe"
            #define AppId "f38c288-6d20-473b-87cd-5ef9f8bd2f46"

            [Setup]
            AppId={#AppId}
            AppName={#AppName}
            AppVersion={#AppVersion}
            AppVerName={#AppName} {#AppVersion}
            AppPublisher={#AppPublisher}
            AppPublisherURL={#AppURL}
            AppSupportURL={#AppURL}
            AppUpdatesURL={#AppURL}
            DefaultDirName={userpf}\{#AppName}
            DefaultGroupName={#AppName}
            AllowNoIcons=yes
            OutputDir=dist
            OutputBaseFilename={#AppName}_v{#AppVersion}_installer
            Compression=lzma2/ultra64
            SolidCompression=yes
            WizardStyle=modern
            DisableWelcomePage=no
            DisableDirPage=no
            DisableProgramGroupPage=yes
            DisableReadyPage=no
            DisableFinishedPage=no
            ArchitecturesAllowed=x64compatible
            ArchitecturesInstallIn64BitMode=x64compatible
            MinVersion=10.0.17763
            PrivilegesRequired=lowest
            UninstallDisplayIcon={app}\{#AppExeName}
            UninstallDisplayName={#AppName}
            VersionInfoVersion={#AppVersion}
            VersionInfoCompany={#AppPublisher}
            VersionInfoDescription={#AppName}
            CreateUninstallRegKey=yes
            UpdateUninstallLogAppName=yes
            CloseApplications=yes
            RestartApplications=no

            [Languages]
            Name: "en"; MessagesFile: "compiler:Default.isl"
            Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"

            [Tasks]
            Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}";

            [Dirs]
            Name: "{app}"; Flags: uninsalwaysuninstall

            [Files]
            Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs uninsrestartdelete
            Source: "{app}\unins*.exe"; DestDir: "{tmp}"; Flags: external skipifsourcedoesntexist deleteafterinstall

            [Icons]
            Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
            Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
            Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

            [Run]
            Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}"

            [UninstallRun]
            Filename: "{cmd}"; Parameters: "/C ""taskkill /f /im {#AppExeName} > nul 2>&1"""; RunOnceId: "KillApp"; Flags: runhidden

            [UninstallDelete]
            Type: dirifempty; Name: "{app}"

            [Code]
            var
              PreviousVersion: String;

            function GetUninstallString(): String;
              var
                sUnInstPath: String;
                sUnInstallString: String;
              begin
                sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppId}_is1');
                sUnInstallString := '';
                if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
                  RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
                Result := sUnInstallString;
              end;

            function GetPreviousVersion(): String;
              var
                sUnInstPath: String;
                sVersion: String;
              begin
                sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppId}_is1');
                sVersion := '';
                if not RegQueryStringValue(HKLM, sUnInstPath, 'DisplayVersion', sVersion) then
                  RegQueryStringValue(HKCU, sUnInstPath, 'DisplayVersion', sVersion);
                Result := sVersion;
              end;

            function IsUpgrade(): Boolean;
              begin
                Result := (GetUninstallString() <> '');
              end;

            function UnInstallOldVersion(): Integer;
              var
                sUnInstallString: String;
                iResultCode: Integer;
              begin
                Result := 0;
                sUnInstallString := GetUninstallString();
                if sUnInstallString <> '' then begin
                  sUnInstallString := RemoveQuotes(sUnInstallString);
                  if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES','', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
                    Result := 3
                  else
                    Result := 2;
                end else
                  Result := 1;
              end;

            procedure CurStepChanged(CurStep: TSetupStep);
              var
                ResultCode: Integer;
              begin
                if (CurStep = ssInstall) then
                  begin
                    Exec(ExpandConstant('{cmd}'), '/C "taskkill /f /im {#AppExeName} > nul 2>&1"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

                    if IsUpgrade() then
                      begin
                        PreviousVersion := GetPreviousVersion();
                        UnInstallOldVersion();
                      end;
                  end;
              end;

            function InitializeSetup(): Boolean;
              begin
                if IsUpgrade() then
                  begin
                    PreviousVersion := GetPreviousVersion();
                  end;
                  Result := True;
              end;

            function NextButtonClick(CurPageID: Integer): Boolean;
              begin
                if (CurPageID = wpWelcome) and IsUpgrade() then
                  begin
                    if MsgBox('A previous version (' + PreviousVersion + ') is already installed. Do you want to upgrade to version {#AppVersion}?',
                      mbConfirmation, MB_YESNO) = IDNO then
                      begin
                        Result := False;
                        Exit;
                      end;
                  end;
                  Result := True;
              end;
"@

        $ISS_CONTENT | Set-Content -Encoding UTF8 $ISS_FILE
        Write-Host "  - Created: $ISS_FILE" -ForegroundColor Gray

        # ==================== COMPILE INSTALLER ====================

        Write-Host "  - Compiling installer..." -ForegroundColor Gray
        & $ISCC $ISS_FILE

        if ($LASTEXITCODE -eq 0)
        {
            $installerFile = "dist\${APP_NAME}_v${APP_VERSION}_installer.exe"
            if (Test-Path $installerFile)
            {
                Write-Host "Windows Installer: $installerFile" -ForegroundColor Blue
            }

            # Clean up ISS file
            Remove-Item $ISS_FILE -ErrorAction SilentlyContinue
        }
        else
        {
            Write-Warning "Inno Setup compilation failed!"
        }
    }
}

# ==================== SUMMARY ====================

Write-Host "`nBUILD COMPLETED!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$distFiles = Get-ChildItem -Path "dist" -File | Sort-Object Name
if ($distFiles.Count -gt 0)
{
    Write-Host "Generated files:" -ForegroundColor Yellow
    foreach ($file in $distFiles)
    {
        $size = [math]::Round($file.Length / 1MB, 2)
        Write-Host "  - $( $file.Name ) ($size MB)" -ForegroundColor White
    }
}
else
{
    Write-Host "No files generated!" -ForegroundColor Red
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Ready for distribution!" -ForegroundColor Green
