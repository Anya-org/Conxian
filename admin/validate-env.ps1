<#
.SYNOPSIS
Validates that required .env files exist in the workspace submodules and warns if they are missing.

.DESCRIPTION
This script checks the required repositories for .env files based on the schemas and examples provided.
#>

$repositories = @{
    "Conxian" = @("DEPLOYER_PRIVKEY", "NETWORK")
    "conxian-nexus" = @("DATABASE_URL", "REDIS_URL")
    "conxius-platform" = @("NODE_ENV", "GATEWAY_JWT_SECRET", "POSTGRES_USER", "POSTGRES_PASSWORD")
    "stacksorbit" = @("NETWORK", "STACKS_DEPLOYER_PRIVKEY", "HIRO_API_KEY")
}

# Use the parent directory of the script as the workspace root if not specified
$workspaceRoot = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { "." }
$missingFiles = 0
$missingVars = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Conxian Workspace Environment Validator " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($repo in $repositories.Keys) {
    $envPath = Join-Path $workspaceRoot "$repo\.env"
    
    Write-Host "Checking repository: $repo" -ForegroundColor Yellow
    
    if (-not (Test-Path $envPath)) {
        Write-Host "  [X] Missing .env file. Please copy from .env.example or .env.schema." -ForegroundColor Red
        $missingFiles++
        continue
    }

    Write-Host "  [OK] .env file found." -ForegroundColor Green
    
    $envContent = Get-Content $envPath
    $requiredVars = $repositories[$repo]
    
    foreach ($var in $requiredVars) {
        $found = $envContent | Select-String -Pattern "^$var=" -Quiet
        if ($found) {
            Write-Host "  [OK] Found required variable: $var" -ForegroundColor Green
        } else {
            Write-Host "  [X] Missing required variable: $var" -ForegroundColor Red
            $missingVars++
        }
    }
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
if ($missingFiles -eq 0 -and $missingVars -eq 0) {
    Write-Host "Validation Passed! All critical environment files and variables are set." -ForegroundColor Green
} else {
    Write-Host "Validation Failed." -ForegroundColor Red
    Write-Host "Missing .env files: $missingFiles" -ForegroundColor Red
    Write-Host "Missing required variables: $missingVars" -ForegroundColor Red
    Write-Host "Please reference admin/SECRETS.md for setup instructions." -ForegroundColor Red
}
Write-Host "==========================================" -ForegroundColor Cyan
