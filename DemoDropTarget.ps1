param (
    [switch]$installDesktop=$false,
    [Parameter(ValueFromRemainingArguments=$true)]
    $Path
)

function New-FileShortcut( [string]$SourceExe, [string]$ArgumentsToSourceExe, [string]$DestinationPath )
{
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($DestinationPath)
    $Shortcut.TargetPath = $SourceExe
    $Shortcut.Arguments = $ArgumentsToSourceExe
    $Shortcut.Save()
}

if ($installDesktop) {
	New-FileShortcut "powershell.exe" "-noprofile -executionpolicy Bypass -file `"$PSScriptPath\$($MyInvocation.InvocationName)`"" "$([Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop))\DemoDropTarget.lnk"
}

'Paths'
$Path
Start-Sleep -Seconds 20

# From  <https://stackoverflow.com/questions/9701840/how-to-create-a-shortcut-using-powershell> and <https://stackoverflow.com/questions/2819908/drag-and-drop-to-a-powershell-script>