function Show-MainMenu {
    Write-Host ""
    Write-Host "--- Printer Management Menu ---"
    Write-Host "1. List Printers"
    Write-Host "2. Remove Printers"
    Write-Host "3. Exit"
    Write-Host ""
}

$running = $true

while ($running) {
    Show-MainMenu
    $choice = Read-Host "Select an option (1-3)"

    switch ($choice) {
        "1" {
            Write-Host ""
            Get-Printer | Select-Object Name, PrinterStatus, DriverName | Format-Table -AutoSize
            Write-Host ""
        }
        "2" {
            Write-Host ""
            $printers = Get-Printer | Select-Object Name
            
            if ($printers.Count -eq 0) {
                Write-Host "No printers found to remove."
            } else {
                for ($i = 0; $i -lt $printers.Count; $i++) {
                    Write-Host "$($i + 1). $($printers[$i].Name)"
                }
                Write-Host ""
                
                $selection = Read-Host "Enter the number of the printer to remove (or 'C' to cancel)"
                
                if ($selection -match '^\d+$') {
                    $index = [int]$selection - 1
                    if ($index -ge 0 -and $index -lt $printers.Count) {
                        $targetPrinter = $printers[$index].Name
                        Remove-Printer -Name $targetPrinter
                        Write-Host "Successfully removed: $targetPrinter"
                    } else {
                        Write-Host "Invalid selection."
                    }
                } else {
                    Write-Host "Operation cancelled."
                }
            }
            Write-Host ""
        }
        "3" {
            Write-Host "`nExiting script...`n"
            $running = $false
        }
        Default {
            Write-Host "`nInvalid option, please try again.`n"
        }
    }
}
