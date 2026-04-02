# --- CONFIGURATION: Add or remove scripts here ---
$ScriptList = @(
    @{ Name = "Printer Management"; Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/printers.ps1" }
    @{ Name = "Spam Filter Tools";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/spamfilter.ps1" }
    @{ Name = "Network Speedtest";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/speedtest.ps1" }
)

function Show-MasterMenu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "         BACKSTAGE MASTER MENU            " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        Write-Host (" {0}. {1}" -f ($i + 1), $ScriptList[$i].Name)
    }
    
    Write-Host " Q. Quit"
    Write-Host "==========================================" -ForegroundColor Cyan
}

while ($true) {
    Show-MasterMenu
    $Selection = Read-Host "Select an option"

    if ($Selection -eq 'q') { break }

    # Validate numeric input
    if ([int]::TryParse($Selection, [ref]$idx) -and $idx -le $ScriptList.Count -and $idx -gt 0) {
        $TargetScript = $ScriptList[$idx - 1]
        Write-Host "Loading $($TargetScript.Name)..." -ForegroundColor Yellow
        
        # Execute the remote script in the current session
        try {
            irm $TargetScript.Url | iex
        }
        catch {
            Write-Host "Error launching script: $($_.Exception.Message)" -ForegroundColor Red
            Pause
        }
    }
    else {
        Write-Host "Invalid selection, please try again." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}
