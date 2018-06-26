# '[string]::Join(" ", $args)' | out-file -enc ASCII $ProfilePath\JoinArgs.ps1

schtasks /delete /tn Demo /f
#schtasks /create /sc daily /tn Demo /tr "$pshome\powershell.exe -nologo -noprofile & '$profilepath\joinargs.ps1' (Get-Date -f 'o') -whatif 2>&1 >>c:\Demo.log; sleep 30" /st 05:00 /du 0024:01 /ri 1440 /it /f
#    /du -gt /ri
#    /it requires password
schtasks /create /sc daily /mo 1 /tn Demo /tr "$pshome\powershell.exe -nologo -noprofile & '$profilepath\joinargs.ps1' (Get-Date -f 'o') -whatif *>&1 >>c:\Demo.log; sleep 30" /st 05:00 /np /f
#    /np (aka setting "Do not store password") requires "Log on as a batch job" permission (gpedit.msc > Computer Configuration > Windows Settings > Security Settings > Local Policies > User Rights Assignment > Log on as a Batch Job)

schtasks.exe /run /tn Demo

schtasks.exe /query /tn Demo /fo list
