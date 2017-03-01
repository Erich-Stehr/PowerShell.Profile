[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Low,SupportsShouldProcess=$false)]
param (
	[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
	[Alias('sAMAccountName','MailNickname')]
	[string[]] 
	# 'true' name at Microsoft or bearer object
	$name,
	[string]
	# ADSI catalog root to search
	$rootName=$("GC://"+([adsi]"GC://rootDSE").Properties['rootdomainnamingcontext']) #"GC://DC=corp,DC=microsoft,DC=com"
	)
Begin {
	$domainRoot = [ADSI]$rootName
	$searcher = New-Object System.DirectoryServices.DirectorySearcher $domainRoot

	function DoIt($thisOne) {
		$searcher.Filter="(&(sAMAccountType=805306368)(sAMAccountName=$name))"
		Write-Debug $searcher.Filter
		$dirEntry = $null
		try {
			$dirEntry = $searcher.FindOne()
		} catch {
			Write-Error $_ # keep running the pipeline, but pass the error back
		}
		if ($null -eq $dirEntry) {
			return $thisOne
		} else {
			$thisOne |
			Add-Member -NotePropertyName "userprincipalname" -NotePropertyValue $dirEntry.Properties["userprincipalname"] -PassThru |
			Add-Member -NotePropertyName "mail" -NotePropertyValue $dirEntry.Properties["mail"] -PassThru |
			Add-Member -NotePropertyName "sAMAccountName" -NotePropertyValue $dirEntry.Properties["sAMAccountName"] -PassThru
		}
	}
}
Process {
        DoIt $_
}
End {
}

<#
.SYNOPSIS
	Searches ADSI catalog for users
.DESCRIPTION
	Given objects with user aliases, search the given catalog for the name and
	add UPN, mail, and sAMAccountName if present from the catalog to the incoming name
.INPUTS
	object with Name or aliased property
.OUTPUTS
	objects with added data if present
.EXAMPLE
	.\Invoke-SqlCommand.ps1 -datasource novatoposqlprod-westus2.database.windows.net -database OrionV2prod -Credential $prodCred -sql "Select ID, Name, Email, Domain, IsAdmin, IsWebAdmin, LastAccessCheck FROM Users WHERE IsGroupAlias = 0" | .\Test-GCUser.ps1 | ? {$_.mail -ne $null} | Send-MailMessage -To $_.mail -Subject "Testing" -Body "Test for $($_.sAMAccountName)"
#> 