$logFile = "$PWD\git_audit_log.txt"
"--- Git and Issue Audit Log ---" | Out-File -FilePath $logFile

$modules = git config --file .gitmodules --get-regexp path | ForEach-Object { ($_ -split ' ')[1] }

$repos = @(".") + $modules

foreach ($repo in $repos) {
    " " | Out-File -FilePath $logFile -Append
    "======================================" | Out-File -FilePath $logFile -Append
    "Repository: $repo" | Out-File -FilePath $logFile -Append
    "======================================" | Out-File -FilePath $logFile -Append
    
    if (Test-Path "$repo") {
        Push-Location $repo
        
        "-- Git Status --" | Out-File -FilePath $logFile -Append
        git status -s | Out-File -FilePath $logFile -Append
        
        "-- GitHub Issues --" | Out-File -FilePath $logFile -Append
        gh issue list --limit 10 2>&1 | Out-File -FilePath $logFile -Append
        
        Pop-Location
    } else {
        "Submodule not initialized or missing." | Out-File -FilePath $logFile -Append
    }
}

Write-Host "Audit completed. Review git_audit_log.txt and provide it to the agent."
