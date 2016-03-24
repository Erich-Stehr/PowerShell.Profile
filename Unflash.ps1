# -Activate, -Deactivate or toggle (default) whether Flash is allowed in IE
param ([switch]$Activate = $false, [switch]$Deactivate = $false)
(gp 'HKLM:\SOFTWARE\Classes\CLSID\{D27CDB6E-AE6D-11CF-96B8-444553540000}\InprocServer32').'(default)'
$script:targetRegPath = 'HKLM:\SOFTWARE\Microsoft\Internet Explorer\ActiveX Compatibility\{D27CDB6E-AE6D-11CF-96B8-444553540000}'
if (test-path $script:targetRegPath) {
	$flags = Get-ItemProperty -literalpath $script:targetRegPath -name 'Compatibility Flags'
	#Write-debug "$flags $(get-typename $flags)"
	$flags = [int]$flags.'Compatibility Flags'
	if (-not ($flags -is [int])) { $flags = [int]$flags.ToString().Split('=')[-1].Replace('}','') }

	if ($Activate) {
		$flags = $flags -band (-bnot 0x400)
	} elseif ($Deactivate) {
		$flags = $flags -bor 0x400
	} else {
		$flags = $flags -bxor 0x400
	}
	Set-ItemProperty -literalpath $script:targetRegPath -name 'Compatibility Flags' -value $flags
	"Flash has been $(if ($flags -band 0x400) { 'deactivated' } else { 'activated' })"
} else {
	"Flash doesn't seem to be installed on this system"
}