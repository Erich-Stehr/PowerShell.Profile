# Sahik Malik : PowerShell script to update user profile properties
# from http://blah.winsmarts.com/2013-7-PowerShell_script_to_update_user_profile_properties.aspx
# param'ed 2012/07/04
param (
	$csvfile="users.csv", 
	$mySiteUrl = $(throw "enteryourmysiteurlhere"),
	$upAttribute = $(throw "attributeToUpdate"),
)
$site = Get-SPSite $mySiteUrl
$context = Get-SPServiceContext $site
$profileManager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($context)
$csvData = Import-Csv $csvfile
foreach ($line in $csvData)
{
	if ($profileManager.UserExists($line.username))
	{
		$up = $profileManager.GetUserProfile($line.username)
		$up[$upAttribute].Value = $line.attributeval
		$up.Commit()
	}
	else
	{
		write-host $line.username " profile not found"
	}
}
$site.Dispose()