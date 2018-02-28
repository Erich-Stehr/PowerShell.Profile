# https://stackoverflow.com/questions/9701840/how-to-create-a-shortcut-using-powershell
param ( [string]$SourceExe, [string]$ArgumentsToSourceExe, [string]$DestinationPath )
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.TargetPath = $SourceExe
$Shortcut.Arguments = $ArgumentsToSourceExe
$Shortcut.Save()