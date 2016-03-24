# Script created by Ingo Karstein (http://ikarstein.wordpress.com) <http://blog.karstein-consulting.com/2011/11/04/powershell-script-for-recreating-the-server-cache-related-to-error-in-windows-event-log-event-id-6482-application-server-administration-job-failed-for-service-instance-microsoft-office-server-searc/>
Write-Host "Script created by Ingo Karstein (http://ikarstein.wordpress.com)" -ForegroundColor DarkGreen

$cacheFolderRoot = Join-Path ${env:ProgramData} "Microsoft\SharePoint\Config"
$cacheFileCopy = Join-Path ${env:temp} "cacheFileTmp.ini.ik"

Write-Host "" -ForegroundColor DarkBlue
Write-Host "Starting" -ForegroundColor DarkBlue

if( Test-Path $cacheFileCopy -PathType Leaf) {
    write-host "Cache File copy lopcation does already exist. Please remove it: $($cacheFileCopy)" -ForegroundColor Red
    return
}

Write-Host "Looking for cache folder" -ForegroundColor DarkBlue
$cacheFolder =  @(GEt-ChildItem -Path $cacheFolderRoot | ? {Test-Path $_.FullName -PathType Container} | ? {Test-Path -Path (Join-Path $_.FullName "cache.ini") -PathType Leaf})

if( $cacheFolder -ne $null -and $cacheFolder.Count -eq 1) {
    $cacheFolder0 = $cacheFolder[0].FullName
    Write-Host "Cache folder found: $($cacheFolder0)" -ForegroundColor DarkBlue
    $cacheFile = join-path $cacheFolder0 "cache.ini"
    Write-Host "Cache ini file: $($cacheFile)" -ForegroundColor DarkBlue

    Write-Host "Stop SharePoint timer service" -ForegroundColor DarkBlue
    stop-service sptimerv4

    Write-Host "Copy cache.ini to it's temp location ($($cacheFileCopy))" -ForegroundColor DarkBlue
    copy-item -path $cacheFile -Destination $cacheFileCopy -force

    Write-Host "Set the content of cache.ini to ""1""" -ForegroundColor DarkBlue
    "1" | set-content $cacheFile -encoding ascii -force

    Write-Host "Remove all .XML files from the cache folder" -ForegroundColor DarkBlue
    get-childitem $cacheFolder0 -filter "*.xml" | remove-item -force -confirm:$false

    Write-Host "Start SharePoint timer service" -ForegroundColor DarkBlue
    start-service sptimerv4

    $xmlFound = -1
    $xmlFoundLast = -1
    $eqCount = 0

    Write-Host "Now the cache will be recreated... Waiting... This will take a minute or so..." -ForegroundColor DarkBlue
    write-host "(every second a dot will appear on the end of the next line)" -ForegroundColor gray
    do {
        write-host "." -nonewline -ForegroundColor Magenta
        start-sleep -second 1
        $xmlFoundLast = $xmlFound
        $xmlFound = (@(get-childitem $cacheFolder0 -filter "*.xml")).Count
        if( $xmlFound -eq $xmlFoundLast ) {
            $eqCount++
        } else {
            $eqCount = 0
        }
    } while ($eqCount -lt 30)
    
    Write-Host ""
    Write-Host "Done" -ForegroundColor DarkBlue

    $a = get-content $cacheFileCopy
    $b = get-content $cacheFile

    if( $a -ne $b ) {
        if( [int]$a -gt [int]$b ) {
            write-host "An error occured. the content of the cache file is not identically to it's value before processing." -ForegroundColor Red
            write-host "Old: $($a)"
            write-host "New: $($b)"    
        } else {
            write-host "MAYBE an error occured. the content of the cache file is not identically to it's value before processing." -ForegroundColor DarkYellow
            write-host "Old: $($a)"
            write-host "New: $($b)"    
        }
    } else {
        write-host "Processing finished successfully! You need to execute the  script on every server!!" -foregroundcolor darkgreen
        remove-item $cacheFileCopy -Force -confirm:$false
    }
} else {
    write-host "Could not find the cache folder or found too much cache folders!" -foregroundcolor red
}
