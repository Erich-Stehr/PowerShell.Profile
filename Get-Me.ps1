#http://blogs.msdn.com/powershell/archive/2008/12/02/get-me-ps1.aspx
#Get-Me.ps1
#([Security.Principal.WindowsIdentity]::GetCurrent()).user.accountdomainsid.value
[Security.Principal.WindowsIdentity]::GetCurrent()
