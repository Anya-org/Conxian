$repos = @(
    ".",
    "Conxian",
    "conxian-gateway",
    "conxian-labs-site",
    "conxian-nexus",
    "conxian-ui",
    "conxius-platform",
    "conxius-wallet",
    "lib-conxian-core",
    "stacksorbit"
)

foreach ($repo in $repos) {
    Write-Host "========================================"
    Write-Host "Processing Repository: $repo"
    Write-Host "========================================"
    
    Push-Location $repo
    
    # Fetch all and prune
    Write-Host "Fetching and pruning..."
    git fetch --all -p
    
    # Determine default branch
    $defaultBranch = "main"
    $hasMain = git branch --list main
    if (-not $hasMain) {
        $hasMaster = git branch --list master
        if ($hasMaster) {
            $defaultBranch = "master"
        }
    }
    
    Write-Host "Default branch determined as: $defaultBranch"
    
    # Checkout default branch
    $currentBranch = git branch --show-current
    if ($currentBranch -ne $defaultBranch) {
        Write-Host "Checking out $defaultBranch..."
        git checkout $defaultBranch
    }
    
    # Pull latest changes
    Write-Host "Pulling latest changes..."
    git pull
    
    # Find and delete merged branches
    Write-Host "Cleaning up merged branches..."
    $mergedBranches = git branch --merged | Select-String -NotMatch "^\*|main|master" | ForEach-Object { $_.ToString().Trim() }
    
    $branchesDeleted = 0
    foreach ($branch in $mergedBranches) {
        if ($branch -and $branch -ne "") {
            Write-Host "Deleting merged branch: $branch"
            git branch -d $branch
            $branchesDeleted++
        }
    }
    
    if ($branchesDeleted -eq 0) {
        Write-Host "No merged branches to delete."
    }
    
    # Show remaining branches
    Write-Host "Remaining branches:"
    git branch
    
    Pop-Location
    Write-Host ""
}
