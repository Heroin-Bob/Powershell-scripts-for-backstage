# ==============================================================================
# IT BACKSTAGE MASTER MENU (WITH LOGGING)
# ==============================================================================

# Define the log path
$LogPath = Join-Path $HOME "Downloads\MasterLog.txt"

# Start the transcript (Logging)
# -Append ensures we don't overwrite previous errors
# -Force ensures it creates the folder/file if needed
Start-Transcript -Path $LogPath -Append -Confirm:$false

$ScriptList = @(
    @{ Name = "Printer Management"; Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/printers.ps1" }
    @{ Name = "Spam Filter Tools";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/spamfilter.ps1" }
    @{ Name = "Network Speedtest";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/speedtest.ps1" }
)

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       IT BACKSTAGE MASTER MENU           " -ForegroundColor White
    Write-Host "       Logging to: Downloads\MasterLog.txt" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        Write-Host (" {0}. {1}" -f ($i + 1), $ScriptList[$i].Name)
    }
    Write-Host "------------------------------------------" -ForegroundColor Cyan
    Write-Host " Q. Quit"
    Write-Host "==========================================" -ForegroundColor Cyan
}

try {
    while ($true) {
        Show-Menu
        $Selection = Read-Host "`nSelect an option"

        if ($Selection -eq 'q') { break }

        if ([int]::TryParse($Selection, [ref]$idx) -and $idx -le $ScriptList.Count -and $idx -gt 0) {
            $Target = $ScriptList[$idx - 1]
            
            Write-Host "`n[i] Executing: $($Target.Name)..." -ForegroundColor Magenta
            
            & {
                try {
                    $code = Invoke-RestMethod $Target.Url -ErrorAction Stop
                    Invoke-Expression $code
                }
                catch {
                    Write-Host "`n[!] ERROR DETECTED:" -ForegroundColor Red
                    $_.Exception.Message | Out-Default # Forces error to console AND log
                }
            }

            Write-Host "`n------------------------------------------" -ForegroundColor Cyan
            Read-Host "Done. Press ENTER to return to the Master Menu"
        }
    }
}
finally {
    # Stop the transcript when the user quits or the script crashes
    Stop-Transcript
    Write-Host "Log saved to: $LogPath" -ForegroundColor Green
}
