$archive='\\relemeas12\archive\SearchEngineResultPages'
$outpath = 'C:\TestSplitPath.out.txt'
$archive | Out-File -FilePath $outpath
icacls $archive | Out-File -FilePath $outpath
while (!(Test-Path $archive) -and ![String]::IsNullOrEmpty($archive))
{
    "Archive destination is not available at ${archive}" | Out-File -Append -FilePath $Outpath
    $archive = (Split-Path $archive)
}
$archive | Out-File -Append -FilePath $outpath
if ([String]::IsNullOrEmpty($archive)) { exit 1 } else { exit 0 }
<#
.EXAMPLE
	PS> New-Item -ItemType File -Path C:\TestSplitPath.txt,C:\TestSplitPath.out.txt
	PS> icacls C:\TestSplitPath.txt /grant "NT AUTHORITY\NETWORK SERVICE:(M)"
	PS> icacls C:\TestSplitPath.out.txt /grant "NT AUTHORITY\NETWORK SERVICE:(M)"
	PS> icacls "$PWD\Test-SplitPath.ps1" /grant "NT AUTHORITY\NETWORK SERVICE:(R)" # remember to allow reading the script(s)!
	PS> New-ScheduledTask -Action (New-ScheduledTaskAction -Execute "$pshome\powershell.exe" -Argument "`"$PWD\Test-SplitPath.ps1`" -Force -Confirm:`$False *>>C:\TestSplitPath.txt") -Principal (New-ScheduledTaskPrincipal -UserId "NETWORKSERVICE" -LogonType ServiceAccount -RunLevel Highest) -Trigger (New-ScheduledTaskTrigger -Once -At ([DateTime]::Now)) -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable) | Register-ScheduledTask "Test-SplitPath"
	PS> Start-ScheduledTask "Test-SplitPath"
#>

