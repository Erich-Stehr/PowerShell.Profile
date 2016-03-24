param (
[switch] $tax=$true,
[switch] $searchdictionaryimport=$true,
[switch] $deploywsp=$true,
[switch] $createauthorsite=$true,
[switch] $createrendersite=$true,
[switch] $clean=$false,
[string] $environment=$([Environment]::MachineName)
)
if ($environment.StartsWith('/')) { 
	trap {break;}
	write-error "Environment '$environment' can't start with a slash, were you trying for a -switch?" -ea Stop
}
function ScriptRoot { Split-Path $MyInvocation.ScriptName }
$deployCmd = "$(ScriptRoot)\drop\scripts\Deploy.ps1"
$deployArgLine = "/env:$environment /tax:$tax /searchdictionaryimport:$searchdictionaryimport /deploywsp:$deploywsp /createauthorsite:$createauthorsite /createrendersite:$createrendersite"
if ($clean) { $deployArgLine += " /clean" }
"Deploying with: $deployCmd $deployArgLine"
#Invoke-Command -scriptblock { & $deployCmd $deployArgLine }
Invoke-Expression "$deployCmd $deployArgLine"

<#
.SYNOPSIS
	Wrapper around MBS PPR Deploy.ps1 script to provide PoSH argument handling and demonstrate PoSH Comment Based Help
.NOTES
	Place in CMS_Package3 to operate correctly.

	System.Environment.MachineName is upper-cased, so either make the Initializer.xml tag name upper case as well or use the (here optional) -env parameter.

	Try typing the path to the script, followed by a ' -' (without the quotes) and hit Tab several times.
.EXAMPLE
DeployLocal.ps1 -tax:$false -searchdictionaryimport:$false -deploywsp:$false -createauthorsite:$false -createrendersite
Rebuilds render sites
.EXAMPLE
DeployLocal.ps1 -clean
Clean deploy
#>