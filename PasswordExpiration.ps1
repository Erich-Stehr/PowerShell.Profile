param ([string]$dom = [Environment]::UserDomainName, [string]$usr = [Environment]::UserName)
$localRoot = new-object DirectoryServices.DirectoryEntry

# corrects issues with "A referral was returned to the server"; domain being the database connected to, not a property within
if ($dom -ne $localRoot.Name) {
	#$domainRoot = new-object DirectoryServices.DirectoryEntry ('LDAP://'+$localRoot.distinguishedName[0].Replace($localRoot.name, $dom))
	$domainRoot = [ADSI]('LDAP://'+$localRoot.distinguishedName[0].Replace($localRoot.name, $dom))
}
if (($domainRoot -eq $null) -or ($domainRoot.Name -eq $null)) {
	$domainRoot = $localRoot
}

$dirsrch = new-object System.DirectoryServices.DirectorySearcher $domainRoot

#$dirsrch.Filter="(&(objectCategory=person)(sAMAccountName=$usr))"
$dirsrch.Filter="(&(sAMAccountType=805306368)(sAMAccountName=$usr))"
$srchres = $dirsrch.FindOne()
if ($null -eq $srchres) { write-error "$usr not found" ; exit }
if (0x10000 -band $srchres.Properties.useraccountcontrol[0]) { "$usr doesn't expire!"; exit }
$pwdLastSet = [DateTime]::FromFileTime($srchres.Properties.pwdlastset[0])
if ($srchres.Properties.Contains("accountexpires")) { 
	if ($srchres.Properties.accountexpires[0] -gt [DateTime]::MaxValue.Ticks) {
		"$usr 'accountexpires' over maximum (last set $pwdLastSet)"
		#exit
	} else {
		"$usr forced expires $([DateTime]::FromFileTimeUTC($srchres.Properties.accountexpires[0]).ToString('u'))"
		#exit
	}
}

$dirsrch.Filter='(objectClass=top)'
$domRes = $dirsrch.FindOne()
$maxpwdspan = [TimeSpan]$domRes.properties.maxpwdage[0]

$expires = $pwdLastSet - $maxpwdspan
$upn = @($srchres.Properties.userprincipalname)[0]
if ($null -eq $upn) { $upn = "@@ $(@($srchres.Properties.mail)[0])" }
write-host $upn
write-host $expires