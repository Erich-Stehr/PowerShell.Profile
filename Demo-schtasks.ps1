# '[string]::Join(" ", $args)' | out-file -enc ASCII $ProfilePath\JoinArgs.ps1

schtasks /delete /tn Demo /f
#schtasks /create /sc daily /tn Demo /tr "$pshome\powershell.exe -nologo -noprofile & '$profilepath\joinargs.ps1' (Get-Date -f 'o') -whatif 2>&1 >>c:\Demo.log; sleep 30" /st 05:00 /du 0024:01 /ri 1440 /it /f
schtasks /create /sc daily /mo 1 /tn Demo /tr "$pshome\powershell.exe -nologo -noprofile & '$profilepath\joinargs.ps1' (Get-Date -f 'o') -whatif *>&1 >>c:\Demo.log; sleep 30" /st 05:00 /np /f

schtasks.exe /run /tn Demo

schtasks.exe /query /tn Demo /fo list
