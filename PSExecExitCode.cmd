%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe -nologo -noprofile -noninteractive -executionpolicy remotesigned -command "write-output '!'; exit 100"
exit /b %ERRORLEVEL%
