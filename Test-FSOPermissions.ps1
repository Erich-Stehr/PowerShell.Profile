[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::None,SupportsShouldProcess=$false)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] 
	# path to directory/UNC to work with
	$path=$(throw "Requires directory/UNC path to work with"),
	[Parameter(ParameterSet="prepare")]
	[switch]
	# Prepare the directory with files to safely modify and delete
	$prepare=$false,
	[Parameter(Mandatory=$true,ParameterSet="prepare")]
	[string]
	# Owner of test files to be prepared
	$UserName
	)

<#
.SYNOPSIS
	Tests what basic file permissions the user has on the $path
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.EXAMPLE
	PS> 
#>
