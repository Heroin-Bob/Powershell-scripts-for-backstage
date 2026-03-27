# Define a test file (100MB file from Microsoft/Azure CDNs)
$testUrl = "https://speedtest.tele2.net/100MB.zip"
$tempFile = "$env:TEMP\speedtest.tmp"

Write-Host "Starting download speed test... please wait." -ForegroundColor Cyan

try {
    $webClient = New-Object System.Net.WebClient
    
    # Start the stopwatch
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Download the file
    $webClient.DownloadFile($testUrl, $tempFile)
    
    # Stop the stopwatch
    $stopwatch.Stop()
    
    # Get file size in bits
    $fileSizeInBytes = (Get-Item $tempFile).Length
    $fileSizeInBits = $fileSizeInBytes * 8
    
    # Calculate Mbps (Megabits per second)
    $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds
    $speedMbps = [Math]::Round(($fileSizeInBits / $elapsedSeconds) / 1Mb, 2)
    
    Write-Host "`nTest Results:" -ForegroundColor Green
    Write-Host "--------------------------"
    Write-Host "Download Speed: $speedMbps Mbps"
    Write-Host "Time Elapsed:   $([Math]::Round($elapsedSeconds, 2)) seconds"
    Write-Host "--------------------------"
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Clean up the temp file
    if (Test-Path $tempFile) { Remove-Item $tempFile }
}
