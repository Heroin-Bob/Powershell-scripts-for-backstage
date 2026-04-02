# ==============================================================================
# IT BACKSTAGE MASTER MENU (MANUAL LOGGING)
# ==============================================================================

# 1. Setup Manual Log
$LogPath = "$env:TEMP\MasterMenu_Manual.txt"
"--- New Session Started: $(Get-Date) ---" | Out-File -FilePath $LogPath -Append

function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$TimeStamp] $Message" | Out-File -FilePath $LogPath -Append
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
    Write-Host "       LOGGING TO: $LogPath" -ForegroundColor Yellow
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

    if ($Selection -eq 'q') { 
        Write-Log "User exited script."
        break 
    }

    if ([int]::TryParse($Selection, [ref]$idx) -and $idx -le $ScriptList.Count -and $idx -gt 0) {
        $Target = $ScriptList[$idx - 1]
        Write-Host "`n[i] Loading: $($Target.Name)..." -ForegroundColor Magenta
        Write-Log "Attempting to load: $($Target.Name) from $($Target.Url)"
        
        & {
            try {
                $code = Invoke-RestMethod $Target.Url -ErrorAction Stop
                Write-Log "Download successful. Executing code..."
                Invoke-Expression $code
            }
            catch {
                $Err = $_.Exception.Message
                Write-Host "`n[!] SCRIPT ERROR:" -ForegroundColor Red
                Write-Host $Err -ForegroundColor White
                Write-Log "ERROR: $Err"
                Write-Log "Stack: $($_.ScriptStackTrace)"
                Start-Sleep -Seconds 3
            }
        }
        Write-Host "`n------------------------------------------" -ForegroundColor Cyan
        Read-Host "Done. Press ENTER to return to the Master Menu"
    }
    else {
        Write-Log "Invalid user input: $Selection"
    }
}
