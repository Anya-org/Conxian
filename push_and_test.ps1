$repos = Get-ChildItem -Directory | Where-Object { Test-Path "$($_.FullName)\.git" }
$repos += Get-Item .

foreach ($repo in $repos) {
    cd $repo.FullName
    Write-Host "Processing $($repo.Name)"
    
    # Check if there are any changes to commit
    $status = git status --porcelain
    if ($status) {
        git add .
        git commit -m "chore: remediate phase 6, ERP integration, and cleanup artifacts"
        git push
        Write-Host "Successfully pushed changes for $($repo.Name)"
    } else {
        Write-Host "No changes to commit for $($repo.Name)"
    }
    cd c:\Users\bmokoka\Conxian-Labs\conxian-business
}

Write-Host "Starting tests in platform repo..."
cd conxius-platform
pnpm install
npx playwright test
