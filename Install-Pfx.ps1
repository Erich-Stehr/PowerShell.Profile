param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string] 
	# .pfx certificate file
	$pathName=$(throw "Requires certificate file"),
	[Security.SecureString]
	# Password for .pfx certificate file
	$pfxPwd = $((Get-Credential -UserName $env:USERNAME -Message $pathName).Password),
	[System.Security.Cryptography.X509Certificates.X509Store]
	# certificate store to place certificate in (defaults to Cert:\LocalMachine\My; checks for $null to skip)
	$certStore = $(get-item Cert:\LocalMachine\My),
	[switch]
	# Pass certificate object to output
	$passThru = $false
	)
if (!(New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) ) {
	trap { break; } # Just stop on unhandled exceptions
	throw "Need to be administrator!"
}
#$pfxPwd = Read-Host -Prompt "Please enter the password for your PFX file " -AsSecureString 
$pfxCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pathName, $pfxPwd, "Exportable,MachineKeySet,PersistKeySet") 
if ($certStore -ne $null) {
	$certStore.Open("MaxAllowed") 
	$certStore.Add($pfxcert) 
	$certStore.Close() 
}
if ($passThru){
	$pfxCert
}

<#
.SYNOPSIS
	Installs contents of .pfx certificate file to local machine store, with exportable private key
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	System.Security.Cryptography.X509Certificates.X509Certificate2
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	install-pfx "$PWD\cert.pfx" # prompts for password with fullname to cert.pfx
#>
