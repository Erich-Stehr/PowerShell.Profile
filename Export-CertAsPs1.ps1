[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Low,SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
	[System.Security.Cryptography.X509Certificates.X509Certificate2[]]
	# certificate (from `gci Cert:\**\My\*` or others)
	$certificate,# =$(throw "Requires certificate(s) to work with"),
	[Parameter(Mandatory=$true)]
	[string]
	# path to file
	$destination=$(throw "Requires destination path"),
	[System.Security.SecureString]
	# password for encryption
	$password=$((Get-Credential encryptionPassword).Password)
	)
Begin {
	function ScriptRoot { if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.ScriptName } }

	$PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("certificate")) #https://social.technet.microsoft.com/Forums/scriptcenter/en-US/f07fd26a-ec59-44a4-8143-dea182ffae70/powershell-mandatory-parameters-lose-pipeline-input?forum=ITCG
	$yesToAll = $false
	$noToAll = $false

	[void][System.Reflection.Assembly]::LoadWithPartialName("System.Security")
	if (!(New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) ) {
		trap { break; } # Just stop on unhandled exceptions
		throw "Need to be administrator!"
	}
	$certCount = 0

	function DoIt($thisOne) {
		try {
			$operating = $true
		} catch {
            $operating = $false
		}
		if ($operating) {
			if ($_ -eq $null) {
				return
			}
			# ShouldProcess provides -Confirm/-WhatIf, $action/args[1] defaults to script name, additional arguments change semantics
			if ($pscmdlet.ShouldProcess($thisOne)) {
				# cmdlets within need `-Confirm:$false` since we've already asked
					try {
					$bytes = $thisOne.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $password)
					} catch {
						throw "Failed to handle $($thisOne.Thumbprint): $_"
						return
					}
					Add-Content -Path $destination -Value "`$cert$($certCount)=@'`n`r$([Convert]::ToBase64String($bytes, [Base64FormattingOptions]::InsertLineBreaks))`n`r'@"
					Add-Content -Path $destination -Value "`$certHashString$($certCount)='$($thisOne.GetCertHashString())'"
					Add-Content -Path $destination -Value @"
`$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2([Convert]::FromBase64String(`$cert$($certCount)), `$password, "Exportable,MachineKeySet,PersistKeySet")
if (`$cert.GetCertHashString() -ne `$certHashString$($certCount)) {
	trap {break;}
	throw "Hash failure in cert$($certCount): `$(`$cert.GetCertHashString()) instead of `$certHashString$($certCount))"
} else {
	`$certStore = (get-item Cert:\LocalMachine\My)
	`$certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::MaxAllowed)
	`$certStore.Add(`$cert)
	`$certStore.Close()
}
"@
			}
		}
	}
	Set-Content $destination -Value "param (`$password)"
}
Process {
    if ($PIPELINEINPUT -and ($_ -ne $null)) {
        $certificate = $_
    }
    $certificate | %{
        DoIt $_
		$certCount++
    }
}
End {
}

<#
.SYNOPSIS
	Export certificates as a PowerShell script for PSEXEC execution
.DESCRIPTION
	take input certificate(s), presumably including private keys, and export
	as a PowerShell script which is executable from PSEXEC without additional
	files to be copied over
.INPUTS
	accepts certificates from pipeline
.OUTPUTS
	script file at $destination
.EXAMPLE
	dir Cert:\LocalMachine\My | ? { $_.NotBefore -gt [DateTime]::Today } | Export-CertAsPs1 -Destination certscript.ps1 -Password $pass
#>
