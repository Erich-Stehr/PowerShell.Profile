[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::None,SupportsShouldProcess=$false)]
param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string[]] 
	# (local) site url to work with
	$proxy,
	[switch]
	$force=$false
	)
Begin {
	$wc = New-Object System.Net.WebClient
	$PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("proxy")) #https://social.technet.microsoft.com/Forums/scriptcenter/en-US/f07fd26a-ec59-44a4-8143-dea182ffae70/powershell-mandatory-parameters-lose-pipeline-input?forum=ITCG

	function CheckProxy($proxyUrl) {
		$result = ""

		$WebProxy = New-Object System.Net.WebProxy ($proxyUrl,$true)
		$WebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
		$wc.Proxy = $WebProxy
		try {
			$result = $wc.DownloadString("https://www.google.com/search?q=myip")
		} catch {
			Write-Error "Proxy failed: $proxyUrl`n$_"
		}
		return (New-object PSObject -property @{'ProxyUrl'=$proxyUrl;'Succeeded'=($result -match "myip")})
	}
}
Process {
	if ($PIPELINEINPUT) {
		CheckProxy $_
	}
	else {
		$proxy | % {
			CheckProxy $_
		}
	}
}
End {
}

<#
.SYNOPSIS
	x
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
