# '[string]::Join(" ", $args)' | out-file -enc ASCII $ProfilePath\JoinArgs.ps1

schtasks /create /sc daily /tn Demo /tr "$pshome\powershell.exe -nologo -noprofile & '$profilepath\joinargs.ps1' (Get-Date -f 'o') -whatif 2>&1 >>c:\Demo.log; sleep 30" /st 05:00 /du 0024:01 /ri 1440 /it /f

schtasks.exe /run /tn Demo
