# from http://rkeithhill.wordpress.com/2013/07/25/using-powershell-to-modify-dcom-launch-activation-settings/
param (
		[Parameter(Mandatory=$true, Position=0)]
		[string]
		$Name='IUsr',

		[Parameter(Mandatory=$true, Position=1)]
		[string]
		$ComComponentName='foo'

)
function New-DComAccessControlEntry 
{
	param(
		[Parameter(Mandatory=$true, Position=0)]
		[string]
		$Domain,

		[Parameter(Mandatory=$true, Position=1)]
		[string]
		$Name,

		[string]
		$ComputerName = ".",

		[switch]
		$Group
	)
	
	#Create the Trusteee Object
	$Trustee = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_Trustee").CreateInstance()
	#Search for the user or group, depending on the -Group switch
	if (!$group) {
		$account = [WMI] "\\$ComputerName\root\cimv2:Win32_Account.Name='$Name',Domain='$Domain'"
	} else {
		$account = [WMI] "\\$ComputerName\root\cimv2:Win32_Group.Name='$Name',Domain='$Domain'"
	}
	
	#Get the SID for the found account.
	$accountSID = [WMI] "\\$ComputerName\root\cimv2:Win32_SID.SID='$($account.sid)'"
	
	#Setup Trusteee object
	$Trustee.Domain = $Domain
	$Trustee.Name = $Name
	$Trustee.SID = $accountSID.BinaryRepresentation
	
	#Create ACE (Access Control List) object.
	$ACE = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_ACE").CreateInstance()
	
	# COM Access Mask    
	#   Execute         =  1,
	#   Execute_Local   =  2,
	#   Execute_Remote  =  4,
	#   Activate_Local  =  8,
	#   Activate_Remote = 16
	
	#Setup the rest of the ACE.
	$ACE.AccessMask = 11 # Execute | Execute_Local | Activate_Local
	$ACE.AceFlags = 0
	$ACE.AceType = 0 # Access allowed
	$ACE.Trustee = $Trustee
	$ACE
} 
	
#$Name = 'IUsr
#$ComComponentName = 'foo'
# Configure the DComConfg settings for the component so it can be activated & launched locally
$dcom = Get-WMIObject Win32_DCOMApplicationSetting `
			-Filter "Description='$ComComponentName'" -EnableAllPrivileges
$sd = $dcom.GetLaunchSecurityDescriptor().Descriptor
$nsAce = $sd.Dacl | Where {$_.Trustee.Name -eq $Name}
if ($nsAce) {
	$nsAce.AccessMask = 11
} else {
	$newAce = New-DComAccessControlEntry $env:COMPUTERNAME -Name $Name
	$sd.Dacl += $newAce
}
$dcom.SetLaunchSecurityDescriptor($sd)