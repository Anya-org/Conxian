#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Clarinet Check Analyzer - Analyzes, categorizes, and repairs Clarinet check errors
.DESCRIPTION
    Runs clarinet check, parses output for errors/warnings, categorizes them,
    and attempts to fix common issues automatically.
#>

param(
    [switch]$Fix,
    [switch]$ReportOnly,
    [string]$OutputPath = "./clarinet-check-report.md"
)

$ErrorActionPreference = "Stop"

# Color codes for terminal output
$Red = "`e[31m"
$Yellow = "`e[33m"
$Green = "`e[32m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

# Error categories
$ErrorCategories = @{
    "Syntax" = @()
    "Type" = @()
    "Trait" = @()
    "ContractReference" = @()
    "Unresolved" = @()
    "Warning" = @()
    "Other" = @()
}

# Auto-fixable patterns
$AutoFixPatterns = @{
    # Missing trait implementations
    "missing-trait-method" = {
        param($contract, $method, $trait)
        Add-TraitMethod -Contract $contract -Method $method -Trait $trait
    }
    # Hardcoded addresses
    "hardcoded-address" = {
        param($contract, $line, $address)
        # Flag for manual review
        return "MANUAL: Replace hardcoded address $address in $contract"
    }
}

function Write-Header($text) {
    Write-Host "`n$Blue=== $text ===$Reset`n"
}

function Write-Error($text) {
    Write-Host "$Red[ERROR]$Reset $text"
}

function Write-Warning($text) {
    Write-Host "$Yellow[WARN]$Reset $text"
}

function Write-Success($text) {
    Write-Host "$Green[OK]$Reset $text"
}

function Write-Info($text) {
    Write-Host "$Cyan[INFO]$Reset $text"
}

function Run-ClarinetCheck {
    Write-Header "Running Clarinet Check"
    
    try {
        $output = clarinet check 2>&1
        return $output
    }
    catch {
        # clarinet check returns non-zero on errors, but we still want output
        return $_.Exception.Message + "`n" + ($output -join "`n")
    }
}

function Parse-ClarinetOutput($output) {
    $results = @{
        Errors = @()
        Warnings = @()
        Success = @()
        RawOutput = $output
    }
    
    $currentContract = $null
    $currentError = $null
    
    foreach ($line in $output) {
        # Parse contract validation start
        if ($line -match "Checking (.+\.\.\.)" -or $line -match "Validating (.+\.\.\.)") {
            $currentContract = $matches[1].TrimEnd('.')
            Write-Info "Checking: $currentContract"
        }
        
        # Parse error lines
        if ($line -match "error\[(.+?)\]") {
            $errorCode = $matches[1]
            $currentError = @{
                Contract = $currentContract
                Code = $errorCode
                Message = $line
                Type = Categorize-Error -ErrorCode $errorCode -Message $line
                LineNumber = $null
                Raw = $line
            }
        }
        
        # Parse line numbers
        if ($currentError -and $line -match "-->.*:(\d+):(\d+)") {
            $currentError.LineNumber = [int]$matches[1]
            $currentError.Column = [int]$matches[2]
        }
        
        # Parse warning lines
        if ($line -match "warning\[(.+?)\]" -or $line -match "⚠|warning:") {
            $warning = @{
                Contract = $currentContract
                Message = $line
                Type = "Warning"
                Raw = $line
            }
            $results.Warnings += $warning
            $ErrorCategories["Warning"] += $warning
        }
        
        # End of error block (empty line or new section)
        if ($currentError -and ($line -match "^$" -or $line -match "Checking|Validating")) {
            $results.Errors += $currentError
            $ErrorCategories[$currentError.Type] += $currentError
            $currentError = $null
        }
        
        # Success message
        if ($line -match "success|✓|valid|no errors" -and $currentContract) {
            $results.Success += $currentContract
        }
    }
    
    # Don't forget last error
    if ($currentError) {
        $results.Errors += $currentError
        $ErrorCategories[$currentError.Type] += $currentError
    }
    
    return $results
}

function Categorize-Error($ErrorCode, $Message) {
    # Type errors
    if ($Message -match "type|expect.*got|mismatch|indeterminate") {
        return "Type"
    }
    # Trait errors
    if ($Message -match "trait|impl-trait|method.*missing|does not implement") {
        return "Trait"
    }
    # Contract reference errors
    if ($Message -match "unresolved|reference|contract.*not found|CircularReference|use of unresolved") {
        return "ContractReference"
    }
    # Syntax errors
    if ($Message -match "syntax|parse|unexpected|expected.*found") {
        return "Syntax"
    }
    # Unresolved function/variable
    if ($Message -match "undefined|unknown|not defined|unbound|Unresolved") {
        return "Unresolved"
    }
    
    return "Other"
}

function Group-ByContract($errors) {
    $grouped = @{}
    foreach ($error in $errors) {
        $contract = $error.Contract
        if (-not $grouped.ContainsKey($contract)) {
            $grouped[$contract] = @()
        }
        $grouped[$contract] += $error
    }
    return $grouped
}

function Group-ByErrorCode($errors) {
    $grouped = @{}
    foreach ($error in $errors) {
        $code = $error.Code
        if (-not $grouped.ContainsKey($code)) {
            $grouped[$code] = @()
        }
        $grouped[$code] += $error
    }
    return $grouped
}

function Show-ErrorSummary($results) {
    Write-Header "Error Summary"
    
    $totalErrors = $results.Errors.Count
    $totalWarnings = $results.Warnings.Count
    $totalSuccess = $results.Success.Count
    
    if ($totalErrors -eq 0) {
        Write-Success "No errors found! All contracts validated successfully."
        return
    }
    
    Write-Error "Total Errors: $totalErrors"
    Write-Warning "Total Warnings: $totalWarnings"
    Write-Success "Valid Contracts: $totalSuccess"
    
    Write-Header "By Category"
    foreach ($category in $ErrorCategories.Keys) {
        $count = $ErrorCategories[$category].Count
        if ($count -gt 0) {
            $color = if ($category -eq "Syntax") { $Red } elseif ($category -eq "Type") { $Red } elseif ($category -eq "Warning") { $Yellow } else { $Cyan }
            Write-Host "  $color$category$Reset`: $count"
        }
    }
    
    Write-Header "By Contract"
    $byContract = Group-ByContract -errors $results.Errors
    foreach ($contract in ($byContract.Keys | Sort-Object)) {
        $count = $byContract[$contract].Count
        Write-Host "  $Yellow$contract$Reset`: $count errors"
    }
}

function Show-DetailedErrors($results) {
    Write-Header "Detailed Errors"
    
    $byContract = Group-ByContract -errors $results.Errors
    
    foreach ($contract in ($byContract.Keys | Sort-Object)) {
        Write-Host "`n$Cyan$contract$Reset"
        Write-Host ("-" * ($contract.Length + 4))
        
        foreach ($error in $byContract[$contract]) {
            $line = if ($error.LineNumber) { "L$($error.LineNumber)" } else { "?" }
            $code = $error.Code
            Write-Host "  $Red[$code]$Reset at $Yellow$line$Reset - $($error.Type)"
            Write-Host "    $($error.Message)"
        }
    }
}

function Attempt-AutoFix($results) {
    Write-Header "Attempting Auto-Fixes"
    
    $fixed = 0
    $failed = 0
    $manual = @()
    
    # Group trait errors by contract
    $traitErrors = $ErrorCategories["Trait"]
    $contractTraitErrors = @{}
    
    foreach ($error in $traitErrors) {
        $contract = $error.Contract
        if (-not $contractTraitErrors.ContainsKey($contract)) {
            $contractTraitErrors[$contract] = @()
        }
        $contractTraitErrors[$contract] += $error
    }
    
    # Fix contract reference errors (if in Clarinet.toml)
    $refErrors = $ErrorCategories["ContractReference"]
    foreach ($error in $refErrors) {
        if ($error.Message -match "CircularReference|unresolved.*contract") {
            $manual += "Circular dependency in $($error.Contract) - requires architectural review"
        }
    }
    
    # Fix unresolved function errors
    $unresolvedErrors = $ErrorCategories["Unresolved"]
    foreach ($error in $unresolvedErrors) {
        if ($error.Message -match "use of unresolved function '([^']+)'") {
            $function = $matches[1]
            Write-Warning "Unresolved function '$function' in $($error.Contract) - may need contract dependency in Clarinet.toml"
        }
    }
    
    if ($fixed -gt 0) {
        Write-Success "Fixed $fixed issues automatically"
    }
    if ($failed -gt 0) {
        Write-Error "Failed to fix $failed issues"
    }
    if ($manual.Count -gt 0) {
        Write-Warning "Issues requiring manual intervention:"
        foreach ($item in $manual) {
            Write-Host "  - $item"
        }
    }
    
    if ($fixed -eq 0 -and $failed -eq 0 -and $manual.Count -eq 0) {
        Write-Info "No auto-fixable issues identified"
    }
    
    return @{
        Fixed = $fixed
        Failed = $failed
        Manual = $manual
    }
}

function Generate-Report($results, $fixResults, $outputPath) {
    $report = @"
# Clarinet Check Analysis Report

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Summary

| Metric | Count |
|--------|-------|
| Total Errors | $($results.Errors.Count) |
| Total Warnings | $($results.Warnings.Count) |
| Valid Contracts | $($results.Success.Count) |
| Auto-Fixed | $($fixResults.Fixed) |
| Needs Manual Fix | $($fixResults.Manual.Count) |

## Error Categories

"@

    foreach ($category in ($ErrorCategories.Keys | Sort-Object)) {
        $count = $ErrorCategories[$category].Count
        if ($count -gt 0) {
            $report += "- **$category**: $count errors/warnings`n"
        }
    }
    
    $report += "`n## Errors by Contract`n`n"
    
    $byContract = Group-ByContract -errors $results.Errors
    foreach ($contract in ($byContract.Keys | Sort-Object)) {
        $report += "### $contract`n`n"
        foreach ($error in $byContract[$contract]) {
            $line = if ($error.LineNumber) { "Line $($error.LineNumber)" } else { "Unknown line" }
            $report += "- **[$($error.Code)]** $line - $($error.Type)`n"
            $report += "  - $($error.Message)`n"
        }
        $report += "`n"
    }
    
    if ($results.Warnings.Count -gt 0) {
        $report += "## Warnings`n`n"
        foreach ($warning in $results.Warnings) {
            $report += "- **$($warning.Contract)**: $($warning.Message)`n"
        }
        $report += "`n"
    }
    
    if ($fixResults.Manual.Count -gt 0) {
        $report += "## Issues Requiring Manual Intervention`n`n"
        foreach ($item in $fixResults.Manual) {
            $report += "- [ ] $item`n"
        }
        $report += "`n"
    }
    
    if ($results.Errors.Count -eq 0) {
        $report += "## ✅ All Clear`n`nNo errors detected. All contracts pass validation.`n"
    }
    
    $report += @"

## Raw Output

<details>
<summary>Click to expand full clarinet check output</summary>

```
$($results.RawOutput -join "`n")
```

</details>
"@

    $report | Out-File -FilePath $outputPath -Encoding UTF8
    Write-Success "Report saved to: $outputPath"
}

# === MAIN ===

Write-Host "`n$Cyan========================================$Reset"
Write-Host "$Cyan  Clarinet Check Analyzer & Repair Tool$Reset"
Write-Host "$Cyan========================================$Reset`n"

# Run clarinet check
$rawOutput = Run-ClarinetCheck

# Parse output
$results = Parse-ClarinetOutput -output ($rawOutput -split "`n")

# Show summary
Show-ErrorSummary -results $results

# Show detailed errors
if ($results.Errors.Count -gt 0) {
    Show-DetailedErrors -results $results
}

# Attempt auto-fixes
$fixResults = $null
if ($Fix -and -not $ReportOnly) {
    $fixResults = Attempt-AutoFix -results $results
}
else {
    $fixResults = @{
        Fixed = 0
        Failed = 0
        Manual = @()
    }
}

# Generate report
Generate-Report -results $results -fixResults $fixResults -outputPath $OutputPath

Write-Host "`n$Cyan========================================$Reset"
if ($results.Errors.Count -eq 0) {
    Write-Success "All contracts validated successfully!"
}
else {
    Write-Error "Found $($results.Errors.Count) errors that need attention."
    Write-Info "See $OutputPath for full details."
}
Write-Host "$Cyan========================================$Reset`n"

# Return exit code
exit $results.Errors.Count
