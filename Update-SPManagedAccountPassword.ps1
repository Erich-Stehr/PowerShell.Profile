[CmdletBinding(ConfirmImpact='Medium',SupportsShouldProcess=$false)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[string]
	$dom = [Environment]::UserDomainName, 
	[string]
	$usr = [Environment]::UserName,
	$newCred=$(Get-Credential "$dom\$usr"),
	[switch]
	#whether to reset AD password for account
	$changeAdPassword=$false,
	[switch]
	#whether to reset managed account password from credential
	$changeManagedPassword=$true
	)
#check for SP addin (from SharePoint 2010's Registration.ps1 without set-location, checking core PS version instead of host)
if (!(get-pssnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue)) {
		$ver = $PSVersionTable
		if ($ver -eq $null) {
			trap {break;} # old style stop-on-throw-within-this-scriptblock
			throw "PowerShell version 1 can't access SharePoint"
		}
		if ($ver.PSVersion.Major -gt 1)  {$Host.Runspace.ThreadOptions = "ReuseThread"}
		Add-PsSnapin Microsoft.SharePoint.PowerShell -ea Stop
}
trap {break;} # stop on error, old-style
if ($changeAdPassword) {
	$localRoot = new-object DirectoryServices.DirectoryEntry

	# corrects issues with "A referral was returned to the server"; domain being the database connected to, not a property within
	if ($dom -ne $localRoot.Name) {
	        #$domainRoot = new-object DirectoryServices.DirectoryEntry ('LDAP://'+$localRoot.distinguishedName[0].Replace($localRoot.name, $dom))
	        $domainRoot = [ADSI]('LDAP://'+$localRoot.distinguishedName[0].Replace($localRoot.name, $dom))
	} else {
	        $domainRoot = $localRoot
	}
	
	$dirsrch = new-object System.DirectoryServices.DirectorySearcher $domainRoot
	
	#$dirsrch.Filter="(&(objectCategory=person)(sAMAccountName=$usr))"
	$dirsrch.Filter="(&(sAMAccountType=805306368)(sAMAccountName=$usr))"
	$srchres = $dirsrch.FindOne()
	if ($null -eq $srchres) { write-error "$usr not found" ; exit }

	$adsiUser = [ADSI]($srchres.Path)
	$adsiUser.psbase.invoke("SetPassword",($newCred.GetNetworkCredential().Password))
	$adsiUser.psbase.CommitChanges()
}
if ($changeManagedPassword) {
	$m = Get-SPManagedAccount -Identity $newcred.Username
	Set-SPManagedAccount -Identity $m  -ExistingPassword $newCred.Password –confirm
	Write-Warning "Execute IISRESET once last account is updated!"
}
<#
.SYNOPSIS
	Update password on managed account (-ExistingPassword), optionally updating AD password as well
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT
	ADSI
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
