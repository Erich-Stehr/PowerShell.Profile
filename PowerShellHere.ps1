# Add PowerShell Prompt Here to Explorer context menu for Windows PowerShell v1.0

New-Item HKLM:\SOFTWARE\Classes\Directory\shell\PowerShellHere
New-Item HKLM:\SOFTWARE\Classes\Directory\shell\PowerShellHere\command
Set-ItemProperty HKLM:\SOFTWARE\Classes\Directory\shell\PowerShellHere -Name "(Default)" -Value "PowerShell Prompt Here"
Set-ItemProperty HKLM:\SOFTWARE\Classes\Directory\shell\PowerShellHere\command -Name "(Default)" -Value "`"$PSHome\powershell.exe`" -NoExit -Command Set-Location -LiteralPath `'%L`'"

New-Item HKLM:\SOFTWARE\Classes\Drive\shell\PowerShellHere
New-Item HKLM:\SOFTWARE\Classes\Drive\shell\PowerShellHere\command
Set-ItemProperty HKLM:\SOFTWARE\Classes\Drive\shell\PowerShellHere -Name "(Default)" -Value "PowerShell Prompt Here"
Set-ItemProperty HKLM:\SOFTWARE\Classes\Drive\shell\PowerShellHere\command -Name "(Default)" -Value "`"$PSHome\powershell.exe`" -NoExit -Command Set-Location -LiteralPath `'%L`'"
