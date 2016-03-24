#net stop spsearchhostcontroller
#net start spsearchhostcontroller
# stripped from http://blogs.msdn.com/b/russmax/archive/2013/04/01/why-sharepoint-2013-cumulative-update-takes-5-hours-to-install.aspx
# with timer and order additions from http://blogs.technet.com/b/tothesharepoint/archive/2013/03/13/how-to-install-update-packages-on-a-sharepoint-farm-where-search-component-and-high-availability-search-topologies-are-enabled.aspx
$timerSrv = get-service "SPTimerV4"
$srv4 = get-service "OSearch15" 
$srv5 = get-service "SPSearchHostController" 
Write-verbose "Pausing Search Service Application ($([DateTime]::Now.ToString('HH:mm:ss'))"
$ssa = get-spenterprisesearchserviceapplication 
$ssa.pause() 
Write-verbose "Stopping Search Services ($([DateTime]::Now.ToString('HH:mm:ss'))"
if ($timerSrv.Status -eq "Running") { $restartTimer=$true; $timerSrv.stop() }
if ($srv4.Status -eq "Running") { $restartSearch=$true; $srv4.stop() }
if ($srv5.Status -eq "Running") { $restartNoderunner=$true; $srv5.stop() }
do {
	$srv6 = get-service "SPSearchHostController"
	if ($srv6.Status -ne 'Stopped') { Write-verbose "Waiting ($([DateTime]::Now.ToString('HH:mm:ss'))" ; start-sleep -seconds 10 }
} until ($srv6.Status -eq 'Stopped')
Write-verbose "Search Services stopped, restarting ($([DateTime]::Now.ToString('HH:mm:ss'))"
if ($restartNoderunner) { $srv5.Start() }
if ($restartSearch) { $srv4.Start() }
if ($restartTimer) { $timerSrv.Start() }
$ssa.Resume()
Write-Verbose "restarted and resumed ($([DateTime]::Now.ToString('HH:mm:ss'))"