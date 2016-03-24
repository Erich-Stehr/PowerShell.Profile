param ($repositoriesDirectory=$("C:\repos","h:\users\erichs\repos") )
$repositoriesDirectory = ,(Split-Path $MyInvocation.MyCommand.Definition) + (Split-Path $MyInvocation.InvocationName) + $repositoriesDirectory
$script:repositories = @($repositoriesDirectory | % { dir $_ -ea SilentlyContinue } | ? {$_.PSIsContainer -and (test-path "$($_.FullName)\format")} )
$repositories | % { if ($_ -ne $null) { $_.Name ; svn log "svn://localhost/$($_.Name)" -l 1 } }
