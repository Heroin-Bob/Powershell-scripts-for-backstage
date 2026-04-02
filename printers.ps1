function Show-PrinterMenu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "       PRINTER MANAGEMENT TOOLS           " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. List All Installed Printers"
    Write-Host " 2. List Printer Drivers"
    Write-Host " 3. View Print Jobs"
    Write-Host " 4. Restart Print Spooler"
    Write-Host " 5. Open Control Panel Printers"
    Write-Host "------------------------------------------"
    Write-Host " Q. Quit"
    Write-Host "==========================================" -ForegroundColor Cyan
}

while ($true) {
    Show-PrinterMenu
    $Choice = Read-Host "`nSelect an option"

    switch ($Choice) {
        "1" {
            Get-Printer | Select-Object Name, DriverName, PortName, PrinterStatus | Format-Table -AutoSize
        }
        "2" {
            Get-PrinterDriver | Select-Object Name, PrinterEnvironment, DriverPath | Format-Table -AutoSize
        }
        "3" {
            Get-PrintJob | Select-Object PrinterName, ID, DocumentName, JobStatus | Format-Table -AutoSize
        }
        "4" {
            Write-Host "Restarting Spooler..." -ForegroundColor Yellow
            Restart-Service -Name Spooler -Force
            Write-Host "Spooler restarted successfully." -ForegroundColor Green
        }
        "5" {
            Write-Host "Opening Control Panel..." -ForegroundColor Yellow
            control printers
        }
        "q" {
            return 
        }
        Default {
            Write-Host "Invalid selection, try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
            continue
        }
    }
    Write-Host "`n------------------------------------------" -ForegroundColor Gray
    Read-Host "Action complete. Press ENTER to return to Printer Menu"
}
