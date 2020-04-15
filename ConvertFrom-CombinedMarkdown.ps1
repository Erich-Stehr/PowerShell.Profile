begin { 
    $cd = [System.Environment]::CurrentDirectory
    [System.Environment]::CurrentDirectory = $PWD
    $lineOffset = 0
    $fileName = $null
    function Add-UnixUtf8Content($LiteralPath, $Value, [switch]$NoNewLine) {
        PSUsing ($sw = [IO.File]::AppendText($LiteralPath)) {
            $sw.Write($Value)
            if (!$NoNewLine) {$sw.Write("`n")}
        }
    }
}
process {
    if ($_ -match '^- # ([^\t]+)\t([\dT:-]+)\s#([\d-]+)?(.*)$') {
        # touch fileName with LastWriteTime
        if (![string]::IsNullOrWhiteSpace($filename)) {
            Set-FileTime -LiteralPath $fileName -Time $LastWriteTime -Modified
        }
        # parse file name, LastWriteTime, logDate, logExtra
        $fileName = $Matches[1]
        $LastWriteTime = $Matches[2]
        $logDate = $Matches[3]
        $logExtra = $Matches[4]
        Set-Content -LiteralPath $fileName -Value ([Byte[]]@()) -NoNewline -Encoding Byte
        $isDateline = $true
    } elseif ($isDateline) {
        $line = $_
        if ($line.StartsWith("    ")) {
            $line = $line.Substring(4)
        } 
        if (($null -ne $logDate) -and ($line -notmatch "^- $logDate")) {
            Add-UnixUtf8Content -LiteralPath $fileName -Value "- ${logDate}${logExtra}"
        }
        Add-UnixUtf8Content -LiteralPath $fileName -Value $line
        $isDateline = $false
    } elseif (![string]::IsNullOrWhiteSpace($filename)) {
        $line = $_
        if ($line.StartsWith("    ")) {
            $line = $line.Substring(4)
        } 
        Add-UnixUtf8Content -LiteralPath $fileName -Value $line
    } else {
        Write-Warning "Unheld line ${lineOffset}: $_"
    }
    ++$lineOffset
}
end {
    # touch fileName with LastWriteTime
    if (![string]::IsNullOrWhiteSpace($filename)) {
        Set-FileTime -LiteralPath $fileName -Time $LastWriteTime -Modified
    }
    [System.Environment]::CurrentDirectory = $cd
}