# ==============================================================================
# IT BACKSTAGE MASTER MENU (BULLETPROOF LOGGING)
# ==============================================================================

# 1. Set a guaranteed path (Windows Temp folder)
$LogPath = "$env:TEMP\MasterMenu_Debug.txt"

# 2. Force start the log and verify
try {
    Stop-Transcript -ErrorAction SilentlyContinue
    Start-Transcript -Path $LogPath -Append -Force
    Write-Host "LOGGING STARTED AT: $LogPath" -ForegroundColor Green
}
catch {
    Write-Host "CANNOT START LOG: $($_.Exception.Message)" -ForegroundColor Red
    Pause
}

$ScriptList = @(
    @{ Name = "Printer Management"; Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/printers.ps1" }
    @{ Name = "Spam Filter Tools";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/spamfilter.ps1" }
    @{ Name = "Network Speedtest";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/speedtest.ps1" }
)

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       IT BACKSTAGE MASTER MENU           " -ForegroundColor White
    Write-Host "       LOG: $LogPath" -ForegroundColor DarkGray
    Write-Host "==========================================" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        Write-Host (" {0}. {1}" -f ($i + 1), $ScriptList[$i].Name)
    }
    Write-Host "------------------------------------------" -ForegroundColor Cyan
    Write-Host " Q. Quit"
    Write-Host "==========================================" -ForegroundColor Cyan
}

while ($true) {
    Show-Menu
    $Selection = Read-Host "`nSelect an option"

    if ($Selection -eq 'q') { break }

    if ([int]::TryParse($Selection, [ref]$idx) -and $idx -le $ScriptList.Count -and $idx -gt 0) {
        $Target = $ScriptList[$idx - 1]
        Write-Host "`n[i] Loading: $($Target.Name)..." -ForegroundColor Magenta
        
        & {
            try {
                $code = Invoke-RestMethod $Target.Url -ErrorAction Stop
                Invoke-Expression $code
            }
            catch {
                Write-Host "`n[!] SCRIPT ERROR:" -ForegroundColor Red
                $_.Exception.Message | Out-Default
                Write-Host "`nCheck log for full details: $LogPath" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
        Write-Host "`n------------------------------------------" -ForegroundColor Cyan
        Read-Host "Done. Press ENTER to return to the Master Menu"
    }
}

Stop-Transcript
