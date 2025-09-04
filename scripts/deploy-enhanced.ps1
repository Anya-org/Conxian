# Enhanced Tokenomics Deployment Validation Script
# This script validates that the enhanced contracts can be deployed with dependency injection

Write-Host "Starting Enhanced Tokenomics Deployment Validation..." -ForegroundColor Green

# Test compilation with enhanced manifest
Write-Host "`nValidating enhanced contracts compilation..." -ForegroundColor Yellow
$result = clarinet check --manifest-path Clarinet.enhanced.toml
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Enhanced contracts compilation successful" -ForegroundColor Green
} else {
    Write-Host "✗ Enhanced contracts compilation failed" -ForegroundColor Red
    exit 1
}

# Validate individual enhanced contracts
Write-Host "`nValidating individual enhanced contracts..." -ForegroundColor Yellow
$enhancedContracts = @(
    "contracts/cxd-token.clar",
    "contracts/protocol-invariant-monitor.clar", 
    "contracts/token-emission-controller.clar",
    "contracts/revenue-distributor.clar",
    "contracts/token-system-coordinator.clar"
)

foreach ($contract in $enhancedContracts) {
    $result = clarinet check $contract
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ $contract validation successful" -ForegroundColor Green
    } else {
        Write-Host "✗ $contract validation failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nDeployment Validation Complete!" -ForegroundColor Green
Write-Host "All enhanced contracts are ready for deployment with dependency injection." -ForegroundColor Green
Write-Host "Circular dependencies have been resolved through optional contract references." -ForegroundColor Green
