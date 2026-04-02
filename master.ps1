# ==============================================================================
# IT BACKSTAGE MASTER MENU (DEEP CATCH VERSION)
# ==============================================================================

$ScriptList = @(
    @{ Name = "Printer Management"; Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/printers.ps1" }
    @{ Name = "Spam Filter Tools";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/spamfilter.ps1" }
    @{ Name = "Network Speedtest";  Url = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/speedtest.ps1" }
)

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       IT BACKSTAGE MASTER MENU           " -ForegroundColor White
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
        
        Write-Host "`n[i] Attempting to execute: $($Target.Name)..." -ForegroundColor Magenta
        
        # We wrap the execution in a script block & use the '&' operator 
        # This keeps the sub-script's 'exit' commands from killing the master menu
        & {
            try {
                $code = Invoke-RestMethod $Target.Url -ErrorAction Stop
                Invoke-Expression $code
            }
            catch {
                Write-Host "`n[!] EXECUTION ERROR:" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor White
                Write-Host "`nStack Trace for Debugging:" -ForegroundColor Gray
                Write-Host $_.ScriptStackTrace -ForegroundColor Gray
                
                # Mandatory 5-second hold so you CANNOT miss the message
                Write-Host "`n[!] Screen is locked for 5 seconds to allow reading error..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
        }

        Write-Host "`n------------------------------------------" -ForegroundColor Cyan
        Read-Host "Done. Press ENTER to return to the Master Menu"
    }
    else {
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}
