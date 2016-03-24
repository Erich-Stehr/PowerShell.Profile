$path = "C:\data\ScraperService\Temp\BackupSerpsFast.20151118.log"
$segSize = 200MB

try {
    $ext = [IO.Path]::GetExtension($path)
    $fstm = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $frdr = new-object IO.StreamReader $fstm
    $segmentIndex = 0
    while (!$frdr.EndOfStream) {
        $instr = $frdr.ReadLine()
        if (($fstmOut -ne $null)) { Write-Debug "$($fstmOut.Position.ToString('N0')) + $($instr.Length.ToString('N0'))" }
        if (($fstmOut -eq $null) -or (($fstmOut.Position + $instr.Length) -gt $segSize)) {
            $segmentIndex++
            if ($fstmOut -ne $null) {
                $fwrt.Close()
            }
            $fstmOut = [IO.File]::Open([IO.Path]::ChangeExtension($path, "." + $segmentIndex.ToString("D03") + $ext),
                [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
            $fwrt = new-object IO.StreamWriter $fstmOut
            $fwrt.AutoFlush = $true
        }
        $fwrt.WriteLine($instr)
    }
} finally {
    $fwrt.Close()
}