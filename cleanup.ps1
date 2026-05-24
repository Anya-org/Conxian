$itemsToIgnore = @('node_modules/', 'test-results/', 'playwright-report/', '.env')

$repos = Get-ChildItem -Directory | Where-Object { Test-Path "$($_.FullName)\.git" }
$repos += Get-Item .

foreach ($repo in $repos) {
    cd $repo.FullName
    Write-Host "Processing $($repo.Name)"
    $gitignore = ".gitignore"
    if (-not (Test-Path $gitignore)) {
        New-Item -ItemType File -Path $gitignore | Out-Null
    }
    
    $content = Get-Content $gitignore
    foreach ($item in $itemsToIgnore) {
        $found = $false
        if ($content -ne $null) {
            foreach ($line in $content) {
                if ($line.Trim() -eq $item.Trim()) {
                    $found = $true
                    break
                }
            }
        }
        if (-not $found) {
            Add-Content -Path $gitignore -Value $item
        }
        
        # Untrack silently
        $toRemove = $item.TrimEnd('/')
        git rm -r --ignore-unmatch --cached $toRemove 2>$null
    }
    git add $gitignore
    cd c:\Users\bmokoka\Conxian-Labs\conxian-business
}
