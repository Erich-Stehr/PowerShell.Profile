param ([string]$dom = [Environment]::UserDomainName, [string]$usr = [Environment]::UserName, $newCred=$((Get-Credential "$dom\$usr").GetNetworkCredential()))
trap {break;} # stop on error, old-style
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
$adsiUser.psbase.invoke("SetPassword",($newCred.Password))
$adsiUser.psbase.CommitChanges()
