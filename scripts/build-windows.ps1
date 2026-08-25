# RustDesk custom Windows client build script
# Run on Windows PowerShell 5.1+ (run as Administrator recommended)
# Usage: powershell -ExecutionPolicy Bypass -File .\build-windows.ps1
#   Optional flags:
#     -SkipFlutterInstall   skip Flutter SDK download (if already installed)
#     -SkipVcpkgInstall     skip vcpkg dependencies (if already installed)
#     -SkipBridgeGen        skip flutter_rust_bridge_codegen step

param(
    [switch]$SkipFlutterInstall,
    [switch]$SkipVcpkgInstall,
    [switch]$SkipBridgeGen,
    [string]$RustVersion = "1.75.0",
    [string]$FlutterVersion = "3.24.5",
    [string]$VcpkgCommitId = "120deac3062162151622ca4860575a33844ba10b"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# 1) Check Visual Studio Build Tools (REQUIRED for vcpkg MSVC triplet)
# ---------------------------------------------------------------------------
Write-Step "Checking Visual Studio C++ build tools (REQUIRED)"
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = $null
$vsInstanceValid = $false
if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -property installationPath 2>$null
    if ($vsPath -and (Test-Path $vsPath)) {
        $vsInstanceValid = $true
        Write-Host "  Found VS at: $vsPath" -ForegroundColor Green
        # Make sure the VC tools are present (vswhere reports installs even if workload is missing)
        $vcTools = & $vsWhere -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if (-not $vcTools) {
            $vsInstanceValid = $false
            Write-Host "  [WARN] VS is installed but 'C++ build tools' workload is missing." -ForegroundColor Yellow
        }
    }
}
if (-not $vsInstanceValid) {
    Write-Host "  [ERROR] A working Visual Studio 2022 Build Tools installation is REQUIRED." -ForegroundColor Red
    Write-Host "  vcpkg needs MSVC to compile libvpx/libyuv/opus/aom." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Quick install (run in a NEW admin PowerShell):" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_BuildTools.exe' -OutFile `"`$env:TEMP\vs_BuildTools.exe`"" -ForegroundColor White
    Write-Host "    & `"`$env:TEMP\vs_BuildTools.exe`" --quiet --wait --norestart --nocache ``" -ForegroundColor White
    Write-Host "      --add Microsoft.VisualStudio.Workload.VCTools ``" -ForegroundColor White
    Write-Host "      --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ``" -ForegroundColor White
    Write-Host "      --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ``" -ForegroundColor White
    Write-Host "      --includeRecommended" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or download the installer manually:" -ForegroundColor Cyan
    Write-Host "    https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor White
    Write-Host "  Tick 'Desktop development with C++' during install." -ForegroundColor White
    Write-Host ""
    Write-Host "  REBOOT after install, then re-run this script." -ForegroundColor Magenta
    exit 1
}

# ---------------------------------------------------------------------------
# 2) Ensure Rust
# ---------------------------------------------------------------------------
Write-Step "Checking/installing Rust $RustVersion"
if (-not (Test-Command "rustc")) {
    Write-Host "  Installing rustup..."
    $rustupInit = "$env:TEMP\rustup-init.exe"
    Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupInit -UseBasicParsing
    & $rustupInit -y --default-toolchain $RustVersion --profile minimal
    $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
}
& rustup default $RustVersion | Out-Null
& rustc --version

# ---------------------------------------------------------------------------
# 3) Ensure LLVM
# ---------------------------------------------------------------------------
Write-Step "Checking LLVM"
if (-not (Test-Command "clang")) {
    Write-Host "  [WARN] LLVM not found." -ForegroundColor Yellow
    Write-Host "  Please install LLVM 15.0.6:" -ForegroundColor Yellow
    Write-Host "  https://github.com/llvm/llvm-project/releases/download/llvmorg-15.0.6/LLVM-15.0.6-win64.exe" -ForegroundColor Yellow
    Write-Host "  Tick 'Add LLVM to the system PATH' during install." -ForegroundColor Yellow
    Read-Host "  Press Enter to continue once installed (or Ctrl+C to abort)"
} else {
    & clang --version | Select-Object -First 1
}

# ---------------------------------------------------------------------------
# 4) Ensure Git (auto-discover common install paths)
# ---------------------------------------------------------------------------
Write-Step "Checking git"
if (-not (Test-Command "git")) {
    Write-Host "  git not on PATH, searching common install locations..." -ForegroundColor Yellow
    $gitCandidates = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files\Git\bin\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\bin\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\git.exe"
    )
    $gitFound = $null
    foreach ($cand in $gitCandidates) {
        if (Test-Path $cand) {
            $gitFound = $cand
            break
        }
    }
    if ($gitFound) {
        $gitDir = Split-Path -Parent $gitFound
        Write-Host "  Found git at: $gitDir" -ForegroundColor Green
        Write-Host "  Adding to current PATH and User PATH..." -ForegroundColor Green
        $env:Path = "$gitDir;$env:Path"
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$gitDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$gitDir;$userPath", "User")
        }
    } else {
        Write-Host "  [ERROR] Git not found anywhere." -ForegroundColor Red
        Write-Host "  Please install Git from https://git-scm.com/download/win" -ForegroundColor Red
        Write-Host "  IMPORTANT: When installing, select 'Git from the command line and also from 3rd-party software'" -ForegroundColor Red
        Write-Host "  This adds git to your PATH automatically. After install, re-run this script." -ForegroundColor Red
        exit 1
    }
}
& git --version

# ---------------------------------------------------------------------------
# 5) Ensure Python
# ---------------------------------------------------------------------------
Write-Step "Checking python"
if (-not (Test-Command "python")) {
    Write-Host "  [ERROR] Python not found. Install Python 3.11+ from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "  Make sure to tick 'Add python.exe to PATH' during install." -ForegroundColor Red
    exit 1
}
& python --version

# ---------------------------------------------------------------------------
# 6) Ensure vcpkg + dependencies
# ---------------------------------------------------------------------------
if (-not $SkipVcpkgInstall) {
    Write-Step "Checking/installing vcpkg and C++ dependencies (libvpx/libyuv/opus/aom)"
    $vcpkgRoot = "C:\vcpkg"
    if (-not (Test-Path $vcpkgRoot)) {
        Write-Host "  Cloning vcpkg (this may take a minute)..."
        $cloneLog = & git clone https://github.com/microsoft/vcpkg $vcpkgRoot *>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [ERROR] git clone failed:" -ForegroundColor Red
            $cloneLog | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            exit 1
        }
    }
    Push-Location $vcpkgRoot
    if (-not (Test-Path "vcpkg.exe")) {
        Write-Host "  Bootstrapping vcpkg..."
        $bootLog = cmd /c "bootstrap-vcpkg.bat -disableMetrics" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [ERROR] vcpkg bootstrap failed:" -ForegroundColor Red
            $bootLog | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            Pop-Location
            exit 1
        }
    }
    Write-Host "  Installing x64-windows-static packages (this can take 20-40 min on first run)..."
    Write-Host "    -> libvpx, libyuv, opus, aom" -ForegroundColor Gray
    $installLog = & .\vcpkg.exe install libvpx:x64-windows-static libyuv:x64-windows-static opus:x64-windows-static aom:x64-windows-static 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] vcpkg install failed. Tail of output:" -ForegroundColor Red
        $installLog | Select-Object -Last 30 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Pop-Location
        exit 1
    }
    Pop-Location
    $env:VCPKG_ROOT = $vcpkgRoot
    [Environment]::SetEnvironmentVariable("VCPKG_ROOT", $vcpkgRoot, "User")
} else {
    Write-Step "Skipping vcpkg (using existing VCPKG_ROOT=$env:VCPKG_ROOT)"
    if (-not $env:VCPKG_ROOT) {
        $env:VCPKG_ROOT = "C:\vcpkg"
    }
}

# ---------------------------------------------------------------------------
# 7) Ensure Flutter
# ---------------------------------------------------------------------------
if (-not $SkipFlutterInstall) {
    Write-Step "Checking/installing Flutter $FlutterVersion"
    $flutterExe = "C:\flutter\bin\flutter.exe"
    if (-not (Test-Path $flutterExe)) {
        Write-Host "  Downloading Flutter $FlutterVersion (~700MB, this can take a while)..."
        $flutterZip = "$env:TEMP\flutter.zip"
        Invoke-WebRequest -Uri "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip" -OutFile $flutterZip -UseBasicParsing
        Write-Host "  Extracting to C:\flutter ..."
        Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force
    }
    $env:Path = "C:\flutter\bin;$env:Path"
    [Environment]::SetEnvironmentVariable("Path", "$([Environment]::GetEnvironmentVariable('Path','User'));C:\flutter\bin", "User")
} else {
    Write-Step "Skipping Flutter install (assuming flutter is on PATH)"
}
& flutter --version 2>&1 | Select-Object -First 3

# ---------------------------------------------------------------------------
# 8) Prepare source
# ---------------------------------------------------------------------------
Write-Step "Preparing RustDesk source"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageDir = Split-Path -Parent $scriptDir
$sourceDir = Join-Path $packageDir "rustdesk"
if (-not (Test-Path $sourceDir)) {
    Write-Host "  [ERROR] rustdesk directory not found at: $sourceDir" -ForegroundColor Red
    Write-Host "  The rustdesk source tree should be in the package root." -ForegroundColor Red
    exit 1
}
Set-Location $sourceDir
Write-Host "  Source: $PWD" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 9) Init submodules
# ---------------------------------------------------------------------------
Write-Step "Initializing submodules"
if (Test-Path "libs\hbb_common\.git") {
    Remove-Item -Recurse -Force "libs\hbb_common"
}
$subLog = & git submodule update --init --recursive --depth=1 *>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [WARN] submodule update had issues, retrying once..." -ForegroundColor Yellow
    $subLog = & git submodule update --init --recursive --depth=1 *>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] submodule update failed:" -ForegroundColor Red
        $subLog | Select-Object -Last 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 10) Install flutter_rust_bridge_codegen
# ---------------------------------------------------------------------------
if (-not $SkipBridgeGen) {
    Write-Step "Installing flutter_rust_bridge_codegen (this may take a few minutes)"
    & cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked

    Write-Step "Generating bridge code"
    & flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/windows/runner/bridge_generated.h
}

# ---------------------------------------------------------------------------
# 11) Fetch Flutter deps
# ---------------------------------------------------------------------------
Write-Step "Fetching Flutter dependencies"
Push-Location flutter
& flutter pub get
Pop-Location

# ---------------------------------------------------------------------------
# 12) Build
# ---------------------------------------------------------------------------
Write-Step "Building RustDesk Windows client (estimated 30-60 minutes)"
& python build.py --flutter --hwcodec --portable

# ---------------------------------------------------------------------------
# 13) Done
# ---------------------------------------------------------------------------
Write-Step "Build complete!"
$portableExe = Join-Path $PWD "rustdesk_portable.exe"
$installExe  = Join-Path $PWD "rustdesk-1.4.9-install.exe"
Write-Host "  Portable: $portableExe" -ForegroundColor Green
Write-Host "  Installer: $installExe" -ForegroundColor Green
Write-Host ""
Write-Host "Distribute the .exe to your users. They will connect to fxing.pathea.com automatically." -ForegroundColor Green
