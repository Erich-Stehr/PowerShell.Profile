# https://stackoverflow.com/questions/9701840/how-to-create-a-shortcut-using-powershell # modified to allow URLs in SourceExe
param ( [string]$SourceExe, [string]$ArgumentsToSourceExe, [string]$DestinationPath )
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($DestinationPath)
$Shortcut.TargetPath = $SourceExe
if ($ArgumentsToSourceExe -ne $null) { $Shortcut.Arguments = $ArgumentsToSourceExe }
$Shortcut.Save()