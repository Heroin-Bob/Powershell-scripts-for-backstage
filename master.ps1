<#
.SYNOPSIS
    DOS-Style Utility Dashboard
.DESCRIPTION
    Consolidates Admin, Network, Printer, PC Management (Services & Software), Tools, and User Management tasks into an interactive CLI GUI.
#>

# ==========================================
# ELEVATION CHECK
# ==========================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[WARNING] Running without Administrator privileges." -ForegroundColor Yellow
    Write-Host "Tasks like Spooler restarts, Uninstallations, and User Account changes will fail unless run as Admin.`n" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# ==========================================
# HELPER FUNCTIONS
# ==========================================
function Pause-Menu {
    param([string]$MenuName = "Menu")
    Write-Host "`n------------------------------------------" -ForegroundColor Gray
    Read-Host "Action complete. Press ENTER to return to $MenuName"
}

function Get-InstalledSoftwareList {
    # Queries 64-bit and 32-bit registry keys for installed apps
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $apps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and $_.ParentKeyName -eq $null } |
        Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, QuietUninstallString |
        Sort-Object DisplayName -Unique

    return $apps
}

function Invoke-PortableTool {
    param (
        [string]$ToolName,
        [string]$ZipName,
        [string]$DownloadUrl,
        [string]$ExePattern
    )

    $tempZipPath = Join-Path $env:TEMP $ZipName
    $extractDir  = Join-Path $env:TEMP ([System.IO.Path]::GetFileNameWithoutExtension($ZipName))

    try {
        # Check if already extracted in temp directory
        $existingExe = Get-ChildItem -Path $extractDir -Filter $ExePattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($existingExe -and (Test-Path $existingExe.FullName)) {
            Write-Host "`n$ToolName found in Temp ($($existingExe.FullName)). Launching..." -ForegroundColor Green
            Start-Process -FilePath $existingExe.FullName
        } else {
            Write-Host "`n$ToolName not found in Temp. Downloading mirror..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $tempZipPath -ErrorAction Stop
            
            Write-Host "Extracting archive..." -ForegroundColor Yellow
            if (Test-Path $extractDir) {
                Remove-Item $extractDir -Recurse -Force
            }
            Expand-Archive -Path $tempZipPath -DestinationPath $extractDir -Force

            $targetExe = Get-ChildItem -Path $extractDir -Filter $ExePattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($targetExe) {
                Write-Host "Launching $ToolName..." -ForegroundColor Green
                Start-Process -FilePath $targetExe.FullName
            } else {
                Write-Host "Could not locate '$ExePattern' in extracted folder." -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Failed to process or launch ${ToolName}: $_" -ForegroundColor Red
    }
}

# ==========================================
# SUB-MENU: PRINTER MANAGEMENT
# ==========================================
function Show-PrinterMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "          PRINTER MANAGEMENT TOOLS          " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. List All Installed Printers"
        Write-Host " 2. List Printer Drivers"
        Write-Host " 3. View Print Jobs"
        Write-Host " 4. Restart Print Spooler"
        Write-Host " 5. Open Control Panel Printers"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Main Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
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
                try {
                    Restart-Service -Name Spooler -Force -ErrorAction Stop
                    Write-Host "Spooler restarted successfully." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to restart Spooler: $_" -ForegroundColor Red
                }
            }
            "5" {
                Write-Host "Opening Control Panel..." -ForegroundColor Yellow
                control printers
            }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
                continue
            }
        }
        Pause-Menu "Printer Menu"
    }
}

# ==========================================
# SUB-MENU: NETWORK & DOMAIN TOOLS
# ==========================================
function Show-NetworkMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "          NETWORK & DOMAIN TOOLS           " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. MX Lookup / Identify Spam Filter"
        Write-Host " 2. View Wi-Fi Interfaces Info"
        Write-Host " 3. List Saved Wi-Fi Profiles & View Passwords"
        Write-Host " 4. Scan Nearby Wireless Networks (BSSID)"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Main Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
            "1" {
                $domain = Read-Host "`nEnter the domain"
                if (-not [string]::IsNullOrWhiteSpace($domain)) {
                    try {
                        $mxRecords = Resolve-DnsName -Name $domain -Type MX -ErrorAction Stop
                        $exchangeString = ($mxRecords.NameExchange) -join " "

                        $filter = switch -Regex ($exchangeString) { 
                            "mail\.protection\.outlook\.com" { "Microsoft 365" } 
                            "netsol\.xion\.oxcs\.net"          { "Carrier Zone" } 
                            "relay1g\.spamh\.com"              { "Zix" } 
                            "arsmtp\.com"                      { "AppRiver" } 
                            "proofpoint\.com|ppe-hosted\.com" { "Proofpoint" } 
                            Default                            { "Unknown / Custom MX" } 
                        }

                        Write-Host "`nDetected MX Record(s):" -ForegroundColor Cyan
                        $mxRecords | Select-Object NameExchange, Preference | Format-Table -AutoSize
                        Write-Host "Spam Filter / Mail Provider: $filter" -ForegroundColor Green
                    } catch {
                        Write-Host "`nCould not resolve MX records for '$domain'." -ForegroundColor Red
                    }
                }
            }
            "2" {
                Write-Host "`nFetching Wi-Fi Interface Details...`n" -ForegroundColor Yellow
                netsh wlan show interfaces
            }
            "3" {
                Write-Host "`nSaved Wi-Fi Profiles:`n" -ForegroundColor Yellow
                netsh wlan show profiles
                
                $wifiName = Read-Host "`nEnter profile name to view security key (or press ENTER to skip)"
                if (-not [string]::IsNullOrWhiteSpace($wifiName)) {
                    Write-Host "`n------------------------------------------"
                    netsh wlan show profile name="$wifiName" key=clear
                }
            }
            "4" {
                Write-Host "`nScanning nearby networks...`n" -ForegroundColor Yellow
                netsh wlan show networks mode=bssid
            }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
                continue
            }
        }
        Pause-Menu "Network Menu"
    }
}

# ==========================================
# SUB-MENU: USER & ACCOUNT MANAGEMENT
# ==========================================
function Show-UserMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "       USER & ACCOUNT MANAGEMENT          " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. Manage Local Users (Password Reset, Lock, Delete)"
        Write-Host " 2. View/Modify Local Account Policies"
        Write-Host " 3. Active Sessions & Logoff Utility (qwinsta/rwinsta)"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Main Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
            "1" {
                Write-Host "`nLocal Users on this Device:`n" -ForegroundColor Yellow
                net user
                
                $targetUser = Read-Host "`nEnter username to manage (or press ENTER to skip)"
                if (-not [string]::IsNullOrWhiteSpace($targetUser)) {
                    Write-Host "`nAction for [$targetUser]:" -ForegroundColor Cyan
                    Write-Host " 1. Reset Password (Masked Input)"
                    Write-Host " 2. Unlock Account"
                    Write-Host " 3. Disable/Lock Account"
                    Write-Host " 4. Delete Account"
                    $userAction = Read-Host "Select action"

                    switch ($userAction) {
                        "1" {
                            $securePass = Read-Host "Enter new password" -AsSecureString
                            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
                            $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                            
                            net user "$targetUser" "$plainPass"
                        }
                        "2" {
                            net user "$targetUser" /active:yes
                        }
                        "3" {
                            net user "$targetUser" /active:no
                        }
                        "4" {
                            $confirm = Read-Host "Are you sure you want to DELETE user '$targetUser'? (Y/N)"
                            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                                net user "$targetUser" /delete
                            }
                        }
                        Default { Write-Host "Cancelled/Invalid option." -ForegroundColor Yellow }
                    }
                }
            }
            "2" {
                Write-Host "`nCurrent Account Policies:`n" -ForegroundColor Yellow
                net accounts
                
                Write-Host "`nPolicy Modifications:" -ForegroundColor Cyan
                Write-Host " 1. Change Max Password Age (/maxpwage)"
                Write-Host " 2. Skip / Return"
                $policyChoice = Read-Host "Select option"

                if ($policyChoice -eq "1") {
                    $days = Read-Host "Enter max password age in days (or UNLIMITED)"
                    net accounts /maxpwage:$days
                }
            }
            "3" {
                Write-Host "`nActive User Sessions (qwinsta):`n" -ForegroundColor Yellow
                qwinsta
                
                $sessionID = Read-Host "`nEnter Session ID to log off (or press ENTER to skip)"
                if (-not [string]::IsNullOrWhiteSpace($sessionID)) {
                    Write-Host "Logging off session $sessionID..." -ForegroundColor Yellow
                    rwinsta $sessionID
                    Write-Host "Session logoff command executed." -ForegroundColor Green
                }
            }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
                continue
            }
        }
        Pause-Menu "User Menu"
    }
}

# ==========================================
# SUB-MENU: PC SERVICES MANAGEMENT
# ==========================================
function Show-ServicesMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "        PC SERVICES MANAGEMENT             " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. Restart DNS Agent Services"
        Write-Host " 2. View All Running Services"
        Write-Host " 3. View All Stopped Services"
        Write-Host " 4. Search/Filter Services by Name"
        Write-Host " 5. Check Service Startup Type (Auto, Manual, Disabled)"
        Write-Host " 6. Restart/Start/Stop Specific Service"
        Write-Host " 7. Open Services MMC Console (services.msc)"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to PC Management Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
            "1" {
                Write-Host "`nRestarting DNS Agent Services..." -ForegroundColor Yellow
                try {
                    Get-Service -DisplayName "DNS Agent", "DNS Agent Service Manager" | Restart-Service -Force -ErrorAction Stop
                    Write-Host "DNS Agent services restarted successfully." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to restart DNS Agent services: $_" -ForegroundColor Red
                }
            }
            "2" {
                Write-Host "`n--- RUNNING SERVICES ---`n" -ForegroundColor Yellow
                Get-Service | Where-Object { $_.Status -eq 'Running' } | 
                    Select-Object Name, DisplayName, Status | Format-Table -AutoSize
            }
            "3" {
                Write-Host "`n--- STOPPED SERVICES ---`n" -ForegroundColor Yellow
                Get-Service | Where-Object { $_.Status -eq 'Stopped' } | 
                    Select-Object Name, DisplayName, Status | Format-Table -AutoSize
            }
            "4" {
                $searchTerm = Read-Host "`nEnter service name or display name keyword to search"
                if (-not [string]::IsNullOrWhiteSpace($searchTerm)) {
                    Write-Host "`n--- SEARCH RESULTS FOR '$searchTerm' ---`n" -ForegroundColor Yellow
                    Get-Service | Where-Object { $_.Name -like "*$searchTerm*" -or $_.DisplayName -like "*$searchTerm*" } | 
                        Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
                }
            }
            "5" {
                $svcName = Read-Host "`nEnter Service Name (or DisplayName keyword)"
                if (-not [string]::IsNullOrWhiteSpace($svcName)) {
                    Write-Host "`n--- SERVICE CONFIGURATION DETAILS ---`n" -ForegroundColor Yellow
                    Get-Service | Where-Object { $_.Name -like "*$svcName*" -or $_.DisplayName -like "*$svcName*" } | 
                        Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
                }
            }
            "6" {
                $targetSvc = Read-Host "`nEnter exact Service Name or Display Name"
                if (-not [string]::IsNullOrWhiteSpace($targetSvc)) {
                    Write-Host "`nSelect Action for [$targetSvc]:" -ForegroundColor Cyan
                    Write-Host " 1. Restart Service"
                    Write-Host " 2. Start Service"
                    Write-Host " 3. Stop Service"
                    $svcAction = Read-Host "Select action"

                    try {
                        switch ($svcAction) {
                            "1" { Restart-Service -Name $targetSvc -Force -ErrorAction Stop; Write-Host "Restarted successfully." -ForegroundColor Green }
                            "2" { Start-Service -Name $targetSvc -ErrorAction Stop; Write-Host "Started successfully." -ForegroundColor Green }
                            "3" { Stop-Service -Name $targetSvc -Force -ErrorAction Stop; Write-Host "Stopped successfully." -ForegroundColor Green }
                            Default { Write-Host "Invalid action selected." -ForegroundColor Red }
                        }
                    } catch {
                        Write-Host "Service action failed: $_" -ForegroundColor Red
                    }
                }
            }
            "7" {
                Write-Host "Opening Windows Services Management Console..." -ForegroundColor Yellow
                services.msc
            }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
                continue
            }
        }
        Pause-Menu "Services Menu"
    }
}

# ==========================================
# SUB-MENU: SOFTWARE MANAGEMENT
# ==========================================
function Show-SoftwareMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "         SOFTWARE MANAGEMENT               " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. List Installed Software"
        Write-Host " 2. Uninstall Software"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to PC Management Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
            "1" {
                Write-Host "`nFetching installed software list...`n" -ForegroundColor Yellow
                $installedApps = Get-InstalledSoftwareList
                if ($installedApps) {
                    $installedApps | Select-Object DisplayName, DisplayVersion, Publisher | Format-Table -AutoSize
                } else {
                    Write-Host "No installed applications found." -ForegroundColor Red
                }
            }
            "2" {
                Write-Host "`nFetching installed software...`n" -ForegroundColor Yellow
                $installedApps = Get-InstalledSoftwareList

                if (-not $installedApps) {
                    Write-Host "No installed applications found." -ForegroundColor Red
                } else {
                    for ($i = 0; $i -lt $installedApps.Count; $i++) {
                        $app = $installedApps[$i]
                        Write-Host " [$($i + 1)] $($app.DisplayName)" -NoNewline
                        if ($app.DisplayVersion) { Write-Host " (v$($app.DisplayVersion))" -ForegroundColor Gray } else { Write-Host "" }
                    }

                    Write-Host "`n------------------------------------------"
                    $selection = Read-Host "Enter the NUMBER of the application to uninstall (or press ENTER to cancel)"
                    
                    if ($selection -match "^\d+$") {
                        $index = [int]$selection - 1
                        if ($index -ge 0 -and $index -lt $installedApps.Count) {
                            $targetApp = $installedApps[$index]
                            Write-Host "`nSelected: " -NoNewline
                            Write-Host "$($targetApp.DisplayName)" -ForegroundColor Cyan
                            
                            $confirm = Read-Host "Are you sure you want to trigger uninstallation for this software? (Y/N)"
                            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                                try {
                                    Write-Host "`nAttempting uninstallation..." -ForegroundColor Yellow
                                    
                                    $cmd = if ($targetApp.QuietUninstallString) { $targetApp.QuietUninstallString } else { $targetApp.UninstallString }

                                    if ([string]::IsNullOrWhiteSpace($cmd)) {
                                        Write-Host "No valid uninstall string recorded for this application." -ForegroundColor Red
                                    } elseif ($cmd -match "msiexec") {
                                        $msiGuid = [regex]::Match($cmd, '{[A-F0-9-]+}').Value
                                        if ($msiGuid) {
                                            Start-Process "msiexec.exe" -ArgumentList "/x $msiGuid /qn" -Wait -NoNewWindow
                                        } else {
                                            cmd.exe /c $cmd
                                        }
                                        Write-Host "Uninstallation command executed." -ForegroundColor Green
                                    } else {
                                        cmd.exe /c $cmd
                                        Write-Host "Uninstallation process launched." -ForegroundColor Green
                                    }
                                } catch {
                                    Write-Host "Failed to launch uninstaller: $_" -ForegroundColor Red
                                }
                            } else {
                                Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "Invalid selection number." -ForegroundColor Red
                        }
                    } else {
                        Write-Host "Cancelled / Invalid selection." -ForegroundColor Yellow
                    }
                }
            }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
                continue
            }
        }
        Pause-Menu "Software Menu"
    }
}

# ==========================================
# SUB-MENU: PC MANAGEMENT
# ==========================================
function Show-PCManagementMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "          PC MANAGEMENT TOOLS              " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. PC Services"
        Write-Host " 2. Software"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Main Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
            "1" { Show-ServicesMenu }
            "2" { Show-SoftwareMenu }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ==========================================
# PORTABLE TOOL SUB-MENUS
# ==========================================
function Show-BleachBitMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "         BLEACHBIT (18.2 MB)              " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Cache, temp file, and history cleaner." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "BleachBit" -ZipName "BleachBit.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/BleachBit.zip" -ExePattern "bleachbit*.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "BleachBit Menu"
    }
}

function Show-CPUZMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "           CPU-Z (2.77 MB)                " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Details CPU, motherboard, memory, and OS." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "CPU-Z" -ZipName "cpuz_x.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/cpuz_x.zip" -ExePattern "cpuz*.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "CPU-Z Menu"
    }
}

function Show-ExplorerPlusPlusMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "         EXPLORER++ (4.16 MB)             " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Multi-tabbed file manager for Windows." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "Explorer++" -ZipName "Explorer++.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/Explorer++.zip" -ExePattern "Explorer++.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "Explorer++ Menu"
    }
}

function Show-GeekUninstallerMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "       GEEK UNINSTALLER (3.16 MB)         " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Lightweight uninstaller with deep scanning." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "Geek Uninstaller" -ZipName "GeekUninstaller.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/GeekUninstaller.zip" -ExePattern "geek.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "Geek Uninstaller Menu"
    }
}

function Show-HWMonitorMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "          HWMONITOR (2.69 MB)             " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Voltage, temperature, and fan speed monitor." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "HWMonitor" -ZipName "HWMonitor.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/HWMonitor.zip" -ExePattern "HWMonitor*.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "HWMonitor Menu"
    }
}

function Show-IObitUninstallerMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "   IOBIT UNINSTALLER PORTABLE (15.9 MB)   " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Removes stubborn programs and leftovers." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "IObit Uninstaller Portable" -ZipName "IObitUninstallerPortable.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/IObitUninstallerPortable.zip" -ExePattern "*Uninstaller*.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "IObit Uninstaller Menu"
    }
}

function Show-KuduMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "         KUDU PORTABLE (152 MB)           " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " PC cleaning, debloating, and performance suite." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "Kudu Portable" -ZipName "KuduPortable.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/KuduPortable.zip" -ExePattern "*Kudu*.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "Kudu Menu"
    }
}

function Show-SeaMonkeyMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "         SEAMONKEY (62.9 MB)              " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " Web browser, email client, and editor suite." -ForegroundColor Gray
        Write-Host "------------------------------------------"
        Write-Host " 1. Open from temp"
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Tools Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"
        switch ($Choice.ToLower()) {
            "1" {
                Invoke-PortableTool -ToolName "SeaMonkey" -ZipName "SeaMonkey64.zip" -DownloadUrl "https://github.com/Heroin-Bob/Powershell-scripts-for-backstage/releases/download/mirror/SeaMonkey64.zip" -ExePattern "seamonkey.exe"
            }
            "b" { return }
            Default { Write-Host "Invalid selection, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        Pause-Menu "SeaMonkey Menu"
    }
}

# ==========================================
# SUB-MENU: TOOLS
# ==========================================
function Show-ToolsMenu {
    while ($true) {
        Clear-Host
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "                  TOOLS                   " -ForegroundColor White
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host " 1. BleachBit (18.2 MB)"
        Write-Host "    System cleaner for cache, temp files, and privacy."
        Write-Host " 2. CPU-Z (2.77 MB)"
        Write-Host "    Details CPU, motherboard, memory, and OS."
        Write-Host " 3. Explorer++ (4.16 MB)"
        Write-Host "    Lightweight tabbed file manager for Windows."
        Write-Host " 4. Geek Uninstaller (3.16 MB)"
        Write-Host "    Uninstalls apps and performs deep leftover scans."
        Write-Host " 5. HWMonitor (2.69 MB)"
        Write-Host "    Reads hardware sensors for voltage, temp, and fans."
        Write-Host " 6. IObit Uninstaller Portable (15.9 MB)"
        Write-Host "    Removes unwanted software and browser extensions."
        Write-Host " 7. Kudu Portable (152 MB)"
        Write-Host "    System maintenance, debloating, and performance suite."
        Write-Host " 8. SeaMonkey (62.9 MB)"
        Write-Host "    All-in-one web browser, email, and editing suite."
        Write-Host "------------------------------------------"
        Write-Host " B. Back to Main Menu"
        Write-Host "==========================================" -ForegroundColor Cyan

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice.ToLower()) {
            "1" { Show-BleachBitMenu }
            "2" { Show-CPUZMenu }
            "3" { Show-ExplorerPlusPlusMenu }
            "4" { Show-GeekUninstallerMenu }
            "5" { Show-HWMonitorMenu }
            "6" { Show-IObitUninstallerMenu }
            "7" { Show-KuduMenu }
            "8" { Show-SeaMonkeyMenu }
            "b" { return }
            Default {
                Write-Host "Invalid selection, try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ==========================================
# MAIN DASHBOARD LOOP
# ==========================================
while ($true) {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "         SYSTEM ADMIN DASHBOARD           " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " 1. Printer Management"
    Write-Host " 2. Network & Domain Tools"
    Write-Host " 3. User & Account Management"
    Write-Host " 4. PC Management"
    Write-Host " 5. Tools"
    Write-Host "------------------------------------------"
    Write-Host " Q. Quit"
    Write-Host "==========================================" -ForegroundColor Green

    $MainMenuChoice = Read-Host "`nSelect a Category"

    switch ($MainMenuChoice.ToLower()) {
        "1" { Show-PrinterMenu }
        "2" { Show-NetworkMenu }
        "3" { Show-UserMenu }
        "4" { Show-PCManagementMenu }
        "5" { Show-ToolsMenu }
        "q" { 
            Clear-Host
            Write-Host "Exiting Dashboard. Have a great day!" -ForegroundColor Green
            return 
        }
        Default {
            Write-Host "Invalid selection, try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
