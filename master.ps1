# ==============================================================================
# IT BACKSTAGE MASTER MENU
# ==============================================================================

# --- CONFIGURATION: Add or remove scripts here ---
# Simply add a new line: @{ Name = "Your Description"; Url = "Raw_GitHub_Link" }
$ScriptList = @(
    @{ 
        Name = "Printer Management"
        Url  = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/printers.ps1" 
    }
    @{ 
        Name = "Spam Filter Tools"
        Url  = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/spamfilter.ps1" 
    }
    @{ 
        Name = "Network Speedtest"
        Url  = "https://raw.githubusercontent.com/Heroin-Bob/Powershell-scripts-for-backstage/main/speedtest.ps1" 
    }
)

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       IT BACKSTAGE MASTER MENU           " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        # Formats the list with numbers starting at 1
        Write-Host (" {0}. {1}" -f ($i + 1), $ScriptList[$i].Name)
    }
    
    Write-Host "------------------------------------------" -ForegroundColor Cyan
    Write-Host " Q. Quit / Exit"
    Write-Host "==========================================" -ForegroundColor Cyan
}

# --- MAIN LOOP ---
while ($true) {
    Show-Menu
    $Selection = Read-Host "`nSelect an option"

    # Handle Exit
    if ($Selection -eq 'q') { 
        Write-Host "Exiting..." -ForegroundColor Yellow
        break 
    }

    # Validate numeric input and check if it's within the array range
    if ([int]::TryParse($Selection, [ref]$idx) -and $idx -le $ScriptList.Count -and $idx -gt 0) {
        $Target = $ScriptList[$idx - 1]
        
        Write-Host "`n[i] Calling: $($Target.Name)..." -ForegroundColor Magenta
        Write-Host "[i] URL: $($Target.Url)" -ForegroundColor DarkGray
        Write-Host "------------------------------------------`n"
        
        try {
            # irm (Invoke-RestMethod) grabs the raw text
            # iex (Invoke-Expression) runs that text as a command
            irm $Target.Url -ErrorAction Stop | iex
        }
        catch {
            Write-Host "`n[!] CRITICAL ERROR DURING EXECUTION:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor White
        }

        # --- THE FIX: This pause prevents the screen from clearing immediately ---
        Write-Host "`n------------------------------------------" -ForegroundColor Cyan
        Write-Host "Script execution finished or interrupted." -ForegroundColor Gray
        Read-Host "Press ENTER to return to the Master Menu"
    }
    else {
        Write-Host "Invalid selection. Please choose a number from the list or 'Q'." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}
