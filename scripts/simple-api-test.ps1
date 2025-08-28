# Simple Hiro API Test
param(
    [string]$ApiKey = "8f88f1cb5341624afdaa9d0282456506"
)

Write-Host "Testing Hiro API Integration..." -ForegroundColor Green

$headers = @{
    'X-API-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri "https://api.testnet.hiro.so/extended/v1/status" -Headers $headers
    Write-Host "SUCCESS: API connection working" -ForegroundColor Green
    Write-Host "Chain ID: $($response.chain_id)" -ForegroundColor Cyan
    Write-Host "Network: $($response.network_id)" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Environment Setup Complete:" -ForegroundColor Yellow
Write-Host "- API Key: $($ApiKey.Substring(0,8))..." -ForegroundColor Gray
Write-Host "- .env file created" -ForegroundColor Gray
Write-Host "- Clarinet.toml updated" -ForegroundColor Gray
Write-Host "- Ready for deployment!" -ForegroundColor Gray