# Set TLS 1.2/1.3 to ensure the connection isn't blocked by old security protocols
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Using a reliable 100MB test file from Cloudflare
$url = "https://speed.cloudflare.com/__down?bytes=104857600"
$tempFile = "$env:TEMP\speedtest.tmp"

Write-Host "Connecting to Cloudflare edge..." -ForegroundColor Cyan

try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Downloading using the built-in web request
    Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
    
    $stopwatch.Stop()
    
    $sizeInBits = (Get-Item $tempFile).Length * 8
    $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds
    $speedMbps = [Math]::Round(($sizeInBits / $elapsedSeconds) / 1Mb, 2)
    
    Write-Host "`n--- Speed Test Complete ---" -ForegroundColor Green
    Write-Host "Download Speed: $speedMbps Mbps"
    Write-Host "Time Taken:     $([Math]::Round($elapsedSeconds, 2))s"
}
catch {
    Write-Host "`nConnection Failed." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)"
    Write-Host "Note: Ensure your firewall allows outbound HTTPS traffic."
}
finally {
    if (Test-Path $tempFile) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
}
