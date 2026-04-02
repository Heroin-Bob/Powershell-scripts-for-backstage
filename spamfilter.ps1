# 1. Get user input 
$domain = Read-Host "Enter the domain" 

# 2. Perform the MX lookup and capture only the relevant lines 
$mxRecords = nslookup -q=mx $domain 2>$null | Out-String 

# 3. Identify the Spam Filter using a Switch statement for better readability 
$filter = switch -Regex ($mxRecords) { 
    "mail.protection.outlook.com" { "Microsoft" } 
    "netsol.xion.oxcs.net"        { "Carrier Zone" } 
    "relay1g.spamh.com"           { "Zix" } 
    "arsmtp.com"                  { "AppRiver" } 
    "proofpoint.com|ppe-hosted.com" { "Proofpoint" } 
    Default                       { $null } 
} 

# 4. Output the results 
if ($filter) { 
    Write-Host "Spam Filter is: $filter" -ForegroundColor Cyan 
} else { 
    Write-Host "No specific filter recognized. Raw MX output:" -ForegroundColor Yellow 
    Write-Output $mxRecords.Trim() 
} 
