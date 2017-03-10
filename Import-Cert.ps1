[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Medium,SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	[string[]]
	# certificate file names (bare names are in same directory as script)
	$name=$(throw "Requires certificate file paths to work with"),
	[string]
	# certificate store to import to
	$CertStoreLocation="Cert:\LocalMachine\My",
	[switch]
	$passThru=$false,
	[switch]
	# create fresh .cer file next to source .pfx files
	$CerFromPfx=$false
	)
Begin {
	function ScriptRoot { if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.ScriptName } }

	$PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("name")) #https://social.technet.microsoft.com/Forums/scriptcenter/en-US/f07fd26a-ec59-44a4-8143-dea182ffae70/powershell-mandatory-parameters-lose-pipeline-input?forum=ITCG
	$yesToAll = $false
	$noToAll = $false
	# from AD-MSODS-Core .\src\dev\mgmtsys\DMS\Common\UnitTestHelper\OneboxCertHelper.cs
	$password = & {
		$decryptedBytes = $null
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Security")
		try {
			$encryptedBytes = [IO.File]::ReadAllBytes([IO.Path]::Combine((ScriptRoot), "EncryptedPassword"))
			$decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
			$result = (New-Object System.Security.SecureString)
			#$sb = New-Object System.Text.StringBuilder # to use certutil, we'll need the unencrypted password
			$rdr = New-Object System.IO.StreamReader @((New-Object System.IO.MemoryStream (,$decryptedBytes)),
			 (New-Object System.Text.UnicodeEncoding @($false, $true, $true)))
			while (($ch = $rdr.Read()) -gt 0) {
				$result.AppendChar($ch)
				#[void]$sb.Append([char]$ch)
			}

			return $result#, $sb.ToString()
		} finally {
			$ex = $_
			if ($decryptedBytes -ne $null) { 0..($decryptedBytes.Count-1) | % {$decryptedBytes[$_] = 0} }
			if ($null -ne $ex) {throw $ex}
		}
	}
	$certStore = get-item $certStoreLocation

	[void][System.Reflection.Assembly]::LoadWithPartialName("System.Security")
	if (!(New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator) ) {
		trap { break; } # Just stop on unhandled exceptions
		throw "Need to be administrator!"
	}

	function DoIt($thisOne) {
		try {
			$operating = $true
		} catch {
            $operating = $false
		}
		if ($operating) {
			$certFile = $null
			$cert = $null
			$file = [IO.Path]::Combine((ScriptRoot), [IO.Path]::Combine([IO.Path]::GetDirectoryName($thisOne), [IO.Path]::GetFileNameWithoutExtension($thisOne)))
			if ([IO.File]::Exists($file+".pfx")) {
				$certFile = $file+".pfx"
			} elseif ([IO.File]::Exists($file+".cer")) {
				$certFile = $file+".cer"
			} else {
				Write-Error "Could not locate .pfx or .cer for $file"
				return
			}
			# ShouldProcess provides -Confirm/-WhatIf, $action/args[1] defaults to script name, additional arguments change semantics
			if ($pscmdlet.ShouldProcess($thisOne)) {
				# cmdlets within need `-Confirm:$false` since we've already asked
				if ($certFile.EndsWith('.pfx')) {
					# $cert = Import-PfxCertificate -Confirm:$false -Exportable -Password $password -FilePath $certFile -CertStoreLocation $CertStoreLocation  # BUGBUG `-Authentication CredSSP`? Not accepting with or without -Exportable
					# certutil -p $password[1] -importpfx My "$certFile" # rejects with 0x80092007 CRYPT_E_SELF_SIGNED
					$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile, $password, "Exportable,MachineKeySet,PersistKeySet")
					if ($certStore -ne $null) {
						Write-Debug "$($certStore.Location) \ $($certStore.Name)"
						$certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::MaxAllowed)
						$certStore.Add($cert)
						$certStore.Close()
					}
					if ($CerFromPfx) {
						Set-Content -Path ([IO.Path]::ChangeExtension($certFile, '.cer')) -Value ($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::SerializedCert)) -Encoding Byte -Force
					}
				} else {
					$cert = Import-Certificate -Confirm:$false -FilePath $certFile -CertStoreLocation $CertStoreLocation
				}
			}
			if ($null -eq $cert) { Write-Warning "No return from $certFile"}
            if ($passThru) { $cert }
		}
	}

}
Process {
    if ($PIPELINEINPUT -and ($_ -ne $null)) {
        $name = $_
    }
    $name | %{
        DoIt $_
    }
}
End {
}

<#
.SYNOPSIS
	install certificates, preferring .pfx over .cer if available
.DESCRIPTION
	install certificates named in $name to $CertStoreLocation, preferring .pfx
	(including private key as exportable) over .cer and combining with script
	directory as base
.INPUTS
	accepts certificate names from pipeline
.OUTPUTS
	string[] status messages, -passThru includes X509Certificate2's
.EXAMPLE
#>
