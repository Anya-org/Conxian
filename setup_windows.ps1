<#
.SYNOPSIS
    Conxian Windows Development Environment Setup
    Sets up LLVM MinGW toolchain for Rust/Clarity development on Windows.
.DESCRIPTION
    This script installs and configures LLVM MinGW for the secp256k1-sys dependency
    used by conxian-nexus and conxius-enclave-sdk. It writes .cargo/config.toml
    with the correct local paths and creates any necessary linker stubs.

    Idempotent — safe to re-run.
.NOTES
    Author: Conxian-Labs (Pty) Ltd
    Version: 1.0.0
#>

$ErrorActionPreference = "Stop"
$scriptVersion = "1.0.0"

# --- Configuration ---
$LLVM_MINGW_VERSION = "20260519"
$LLVM_MINGW_DIR = "llvm-mingw-$LLVM_MINGW_VERSION-ucrt-x86_64"
$LLVM_MINGW_URL = "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW_VERSION/$LLVM_MINGW_DIR.zip"
$INSTALL_BASE = "C:\tools\llvm-mingw"
$INSTALL_PATH = "$INSTALL_BASE\$LLVM_MINGW_DIR"
$CARGO_CONFIG_DIR = "$PWD\.cargo"
$CARGO_CONFIG = "$CARGO_CONFIG_DIR\config.toml"
$ARCH_TRIPLE = "x86_64-w64-mingw32"

Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Conxian Windows Dev Environment Setup v$scriptVersion   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Check prerequisites ---
Write-Host "▸ Checking prerequisites..." -ForegroundColor Yellow

$hasRustup = Get-Command rustup -ErrorAction SilentlyContinue
if (-not $hasRustup) {
    Write-Host "  ✗ rustup not found. Please install from: https://rustup.rs" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ rustup: $((rustup --version).Split(' ')[1])" -ForegroundColor Green

# Check the GNU target is installed
$rustupTargets = rustup target list --installed
if ($rustupTargets -notcontains "$ARCH_TRIPLE") {
    Write-Host "  Adding Rust target: $ARCH_TRIPLE..." -ForegroundColor Yellow
    rustup target add $ARCH_TRIPLE
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Failed to add Rust target" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  ✓ Rust target: $ARCH_TRIPLE" -ForegroundColor Green

$hasGit = Get-Command git -ErrorAction SilentlyContinue
if ($hasGit) { Write-Host "  ✓ git: $((git --version).Split(' ')[2])" -ForegroundColor Green }

Write-Host ""

# --- Step 2: Install LLVM MinGW ---
Write-Host "▸ Installing LLVM MinGW $LLVM_MINGW_VERSION..." -ForegroundColor Yellow

if (Test-Path "$INSTALL_PATH\bin\gcc.exe") {
    Write-Host "  ✓ Already installed at: $INSTALL_PATH" -ForegroundColor Green
} else {
    Write-Host "  Downloading from: $LLVM_MINGW_URL" -ForegroundColor Gray

    if (-not (Test-Path "$INSTALL_BASE")) {
        New-Item -ItemType Directory -Path "$INSTALL_BASE" -Force | Out-Null
    }

    $zipPath = "$env:TEMP\$LLVM_MINGW_DIR.zip"
    try {
        Invoke-WebRequest -Uri $LLVM_MINGW_URL -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        Write-Host "  Downloaded to: $zipPath" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Download failed: $_" -ForegroundColor Red
        Write-Host "  Please download manually from:" -ForegroundColor Yellow
        Write-Host "  $LLVM_MINGW_URL" -ForegroundColor Yellow
        Write-Host "  Then extract to: $INSTALL_PATH" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  Extracting (this may take a minute)..." -ForegroundColor Gray
    try {
        Expand-Archive -Path $zipPath -DestinationPath "$INSTALL_BASE" -Force -ErrorAction Stop
        Write-Host "  Extracted to: $INSTALL_PATH" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Extraction failed: $_" -ForegroundColor Red
        exit 1
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

$gccPath = "$INSTALL_PATH\bin\$ARCH_TRIPLE-gcc.exe"
if (-not (Test-Path $gccPath)) {
    Write-Host "  ✗ GCC not found at expected path: $gccPath" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Compiler: $($ARCH_TRIPLE)-gcc" -ForegroundColor Green

Write-Host ""

# --- Step 3: Create linker stubs (libgcc.a, libgcc_eh.a) ---
Write-Host "▸ Creating linker stubs..." -ForegroundColor Yellow

$libDir = "$INSTALL_PATH\$ARCH_TRIPLE\lib"
$stubFiles = @("libgcc.a", "libgcc_eh.a")
foreach ($stub in $stubFiles) {
    $stubPath = "$libDir\$stub"
    if (-not (Test-Path $stubPath)) {
        $null = New-Item -ItemType File -Path $stubPath -Force
        Write-Host "  Created stub: $stub" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Stub exists: $stub" -ForegroundColor Green
    }
}

Write-Host ""

# --- Step 4: Write .cargo/config.toml ---
Write-Host "▸ Writing cargo config..." -ForegroundColor Yellow

$normalizedPath = $INSTALL_PATH.Replace('\', '\\')

$configContent = @"
[target.x86_64-pc-windows-gnu]
linker = "$normalizedPath\\bin\\$ARCH_TRIPLE-gcc.exe"
rustflags = ["-C", "link-args=-L$normalizedPath\\$ARCH_TRIPLE\\lib -lunwind"]

[env]
CC_x86_64-pc-windows-gnu = "$normalizedPath\\bin\\$ARCH_TRIPLE-gcc.exe"
AR_x86_64-pc-windows-gnu = "$normalizedPath\\bin\\llvm-ar.exe"
"@

if (-not (Test-Path $CARGO_CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CARGO_CONFIG_DIR -Force | Out-Null
}

Set-Content -Path $CARGO_CONFIG -Value $configContent -Force
Write-Host "  Written to: $CARGO_CONFIG" -ForegroundColor Green

Write-Host ""

# --- Step 5: Verify ---
Write-Host "▸ Verifying setup..." -ForegroundColor Yellow

# Test compiler works
$testOut = & "$INSTALL_PATH\bin\$ARCH_TRIPLE-gcc.exe" --version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Compiler test: $testOut" -ForegroundColor Green
} else {
    Write-Host "  ✗ Compiler test failed" -ForegroundColor Red
    exit 1
}

# Test libunwind.a exists
if (Test-Path "$libDir\libunwind.a") {
    $unwindSize = (Get-Item "$libDir\libunwind.a").Length
    Write-Host "  ✓ libunwind.a ($( [math]::Round($unwindSize / 1KB) ) KB)" -ForegroundColor Green
} else {
    Write-Host "  ✗ libunwind.a not found — cargo will fail to link" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ✅ Setup complete!                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart your terminal (to pick up new env vars)" -ForegroundColor Gray
Write-Host "  2. Run: cargo check -p conxian-nexus" -ForegroundColor Gray
Write-Host "  3. Run: cargo test -p conxian-nexus" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: .cargo/config.toml is gitignored (local machine config)." -ForegroundColor Yellow
Write-Host "      Run this script on each new Windows dev machine." -ForegroundColor Yellow
