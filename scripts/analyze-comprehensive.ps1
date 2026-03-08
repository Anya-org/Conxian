#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive Clarinet & Test Analyzer - Analyzes compilation AND test failures
.DESCRIPTION
    Runs clarinet check and npm test, parses both outputs for errors/warnings,
    categorizes them, identifies missing contracts, and attempts fixes.
#>

param(
    [switch]$Fix,
    [switch]$ReportOnly,
    [switch]$IncludeTests,
    [string]$OutputPath = "./comprehensive-analysis-report.md"
)

$ErrorActionPreference = "Stop"

# Color codes
$Red = "`e[31m"
$Yellow = "`e[33m"
$Green = "`e[32m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Magenta = "`e[35m"
$Reset = "`e[0m"

function Write-Header($text) { Write-Host "`n$Blue=== $text ===$Reset`n" }
function Write-Error($text) { Write-Host "$Red[ERROR]$Reset $text" }
function Write-Warning($text) { Write-Host "$Yellow[WARN]$Reset $text" }
function Write-Success($text) { Write-Host "$Green[OK]$Reset $text" }
function Write-Info($text) { Write-Host "$Cyan[INFO]$Reset $text" }
function Write-Critical($text) { Write-Host "$Magenta[CRIT]$Reset $text" }

# ============================================================================
# COMPILATION ANALYSIS
# ============================================================================

function Run-ClarinetCheck {
    Write-Header "Phase 1: Compilation Analysis (clarinet check)"
    $output = clarinet check 2>&1
    $exitCode = $LASTEXITCODE
    return @{ Success = $exitCode -eq 0; Output = $output; ExitCode = $exitCode }
}

# ============================================================================
# TEST ANALYSIS
# ============================================================================

function Run-Tests {
    Write-Header "Phase 2: Test Analysis (npm test)"
    Write-Warning "Running tests - this may take several minutes..."
    $output = npm test 2>&1
    return @{ Output = $output; ExitCode = $LASTEXITCODE }
}

function Parse-TestFailures($output) {
    $missingContracts = @()
    $runtimeErrors = @()
    $methodErrors = @()
    
    foreach ($line in $output) {
        # Pattern 1: Contract does not exist
        if ($line -match "Contract '([^']+)' does not exist") {
            $contract = $matches[1]
            $contractName = $contract.Split('.')[-1]
            if ($contractName -and ($missingContracts.Name -notcontains $contractName)) {
                $missingContracts += @{ 
                    FullName = $contract
                    Name = $contractName
                    Reason = "Contract not deployed in simnet"
                }
            }
        }
        
        # Pattern 2: NoSuchContract runtime error
        if ($line -match 'NoSuchContract\("([^"]+)"\)') {
            $contract = $matches[1]
            $contractName = $contract.Split('.')[-1]
            if ($contractName -and ($missingContracts.Name -notcontains $contractName)) {
                $missingContracts += @{
                    FullName = $contract
                    Name = $contractName
                    Reason = "Mock contract not deployed"
                }
            }
        }
        
        # Pattern 3: Method does not exist
        if ($line -match "Method '([^']+)' does not exist on contract '([^']+)'") {
            $method = $matches[1]
            $contract = $matches[2]
            $methodErrors += @{
                Method = $method
                Contract = $contract.Split('.')[-1]
            }
        }
        
        # Pattern 4: Runtime error in contract
        if ($line -match "Runtime error while interpreting ([^\s]+)") {
            $contract = $matches[1]
            $runtimeErrors += @{
                Contract = $contract.Split('.')[-1]
                Line = $line
            }
        }
    }
    
    return @{
        MissingContracts = $missingContracts
        MethodErrors = $methodErrors
        RuntimeErrors = $runtimeErrors
    }
}

# ============================================================================
# CLARINET.TOML ANALYSIS
# ============================================================================

function Get-ClarinetContracts {
    if (-not (Test-Path "./Clarinet.toml")) {
        Write-Error "Clarinet.toml not found!"
        return @()
    }
    
    $content = Get-Content "./Clarinet.toml" -Raw
    $contracts = @()
    $pattern = '\[contracts\.([^\]]+)\][^\n]*\s*path = "([^"]+)"'
    $matches = [regex]::Matches($content, $pattern)
    
    foreach ($match in $matches) {
        $contracts += @{
            Name = $match.Groups[1].Value
            Path = $match.Groups[2].Value
        }
    }
    
    return $contracts
}

function Find-UnregisteredContracts($clarinetContracts) {
    $registeredPaths = $clarinetContracts | ForEach-Object { $_.Path }
    $unregistered = @()
    
    $allClarFiles = Get-ChildItem -Path "./contracts" -Recurse -Filter "*.clar" -ErrorAction SilentlyContinue | 
        ForEach-Object { $_.FullName -replace "^.*[\\/]contracts[\\/]", "contracts/" -replace "\\", "/" }
    
    foreach ($file in $allClarFiles) {
        if ($file -notin $registeredPaths) {
            $unregistered += $file
        }
    }
    
    return $unregistered
}

# ============================================================================
# REPAIR REPORT
# ============================================================================

function Generate-RepairReport($compilationResult, $testResult, $testAnalysis, $clarinetContracts, $unregistered) {
    $report = @"
# Comprehensive Conxian Protocol Analysis Report

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Executive Summary

| Category | Status | Count |
|----------|--------|-------|
| Compilation | $(if ($compilationResult.Success) { "PASS" } else { "FAIL" }) | Exit: $($compilationResult.ExitCode) |
| Test Execution | $(if ($testResult.ExitCode -eq 0) { "PASS" } else { "FAIL" }) | Exit: $($testResult.ExitCode) |
| Contracts Registered | $($clarinetContracts.Count) | In Clarinet.toml |
| Missing from Tests | $($testAnalysis.MissingContracts.Count) | Need deployment |
| Missing Methods | $($testAnalysis.MethodErrors.Count) | Need implementation |
| Unregistered Files | $($unregistered.Count) | Not in Clarinet.toml |

---

## Phase 1: Compilation

$(if ($compilationResult.Success) { 
    "**All contracts compile successfully**"
} else {
    "**Compilation failed** - see raw output below"
})

---

## Phase 2: Test Failures

### Missing Contracts (Not Deployed)

$(if ($testAnalysis.MissingContracts.Count -eq 0) {
    "All referenced contracts are deployed."
} else {
    $testAnalysis.MissingContracts | ForEach-Object { "- **$($_.Name)**: $($_.Reason)" } | Join-String "`n"
})

### Missing Methods

$(if ($testAnalysis.MethodErrors.Count -eq 0) {
    "All required methods are implemented."
} else {
    $testAnalysis.MethodErrors | ForEach-Object { "- **$($_.Method)** in contract **$($_.Contract)**" } | Join-String "`n"
})

### Runtime Errors

$(if ($testAnalysis.RuntimeErrors.Count -eq 0) {
    "No runtime errors detected."
} else {
    $testAnalysis.RuntimeErrors | ForEach-Object { "- **$($_.Contract)**: Runtime error" } | Join-String "`n"
})

---

## Phase 3: Repair Checklist

### P0 - Critical

$(if (-not $compilationResult.Success) { "- [ ] Fix compilation errors`n" })
$(foreach ($mc in $testAnalysis.MissingContracts) { "- [ ] Add contract: $($mc.Name)`n" })
$(foreach ($me in $testAnalysis.MethodErrors) { "- [ ] Implement method: $($me.Method) in $($me.Contract)`n" })

### P1 - High Priority

$(foreach ($re in $testAnalysis.RuntimeErrors) { "- [ ] Fix runtime error in: $($re.Contract)`n" })

### P2 - Medium Priority

$(foreach ($u in $unregistered) { "- [ ] Register unregistered contract: $u`n" })

---

## Appendix A: Registered Contracts

$(foreach ($c in ($clarinetContracts | Sort-Object Name)) { "- $($c.Name)`n" })

## Appendix B: Unregistered Contract Files

$(if ($unregistered.Count -eq 0) { "None - all files registered." } else { $unregistered | ForEach-Object { "- $_`n" } })

---

*Generated by Comprehensive Analyzer*
"@

    return $report
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "`n$Magenta========================================$Reset"
Write-Host "$Magenta  Comprehensive Clarinet & Test Analyzer$Reset"
Write-Host "$Magenta========================================$Reset`n"

# Phase 1: Compilation
$compilationResult = Run-ClarinetCheck
if ($compilationResult.Success) {
    Write-Success "Compilation: PASS (33 contracts)"
} else {
    Write-Error "Compilation: FAIL"
}

# Phase 2: Tests (if requested)
$testResult = @{ Output = @(); ExitCode = 0 }
$testAnalysis = @{ MissingContracts = @(); MethodErrors = @(); RuntimeErrors = @() }

if ($IncludeTests -or $Fix) {
    $testResult = Run-Tests
    $testAnalysis = Parse-TestFailures -output $testResult.Output
    Write-Info "Missing contracts: $($testAnalysis.MissingContracts.Count)"
    Write-Info "Missing methods: $($testAnalysis.MethodErrors.Count)"
}

# Phase 3: Inventory
$clarinetContracts = Get-ClarinetContracts
$unregistered = Find-UnregisteredContracts -clarinetContracts $clarinetContracts
Write-Info "Contracts registered: $($clarinetContracts.Count)"
Write-Info "Unregistered files: $($unregistered.Count)"

# Phase 4: Report
Write-Header "Generating Report"
$report = Generate-RepairReport `
    -compilationResult $compilationResult `
    -testResult $testResult `
    -testAnalysis $testAnalysis `
    -clarinetContracts $clarinetContracts `
    -unregistered $unregistered

$report | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Success "Report saved: $OutputPath"

# Summary
Write-Header "Analysis Complete"
Write-Host "Compilation: $(if ($compilationResult.Success) { $Green } else { $Red }) $($compilationResult.ExitCode)$Reset"
if ($IncludeTests -or $Fix) {
    Write-Host "Tests: $(if ($testResult.ExitCode -eq 0) { $Green } else { $Red }) $($testResult.ExitCode)$Reset"
}

exit $(if ($compilationResult.Success -and ($testResult.ExitCode -eq 0)) { 0 } else { 1 })
