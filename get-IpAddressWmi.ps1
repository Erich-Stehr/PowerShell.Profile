# https://blogs.technet.microsoft.com/heyscriptingguy/2014/04/10/powertip-use-powershell-to-get-ip-addresses/ # comment 
gwmi Win32_NetworkadapterConfiguration | ? {$_.ipaddress.length -gt 0 } | select -ExpandProperty IPaddress

# https://blogs.msdn.microsoft.com/powershell/2006/06/26/windows-powershell-one-liner-name-to-ip-address/ # [System.Net.Dns]::GetHostAddresses($env:computername)
