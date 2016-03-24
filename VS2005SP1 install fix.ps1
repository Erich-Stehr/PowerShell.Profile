# from http://blogs.msdn.com/heaths/archive/2007/01/11/workaround-for-error-1718.aspx

$script:policyscope = get-itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\windows\safer\codeidentifiers -name PolicyScope -ea SilentlyContinue
if ($null -eq $script:policyscope) {
	new-itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\windows\safer\codeidentifiers -name PolicyScope -propertytype DWORD -value 1
	"# set policyscope to 1"
} else if (1 -ne $script:policyscope) {
	set-itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\windows\safer\codeidentifiers -name PolicyScope -value 1
	"set-itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\windows\safer\codeidentifiers -name PolicyScope -value $script:policyscope # to restore"
} else {
	remove-itemproperty -path HKLM:\SOFTWARE\Policies\Microsoft\windows\safer\codeidentifiers -name PolicyScope
	"# removed policyscope"'

}
net stop msiserver