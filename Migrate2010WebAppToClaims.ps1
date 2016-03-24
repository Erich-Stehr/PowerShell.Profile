# from http://msdn.microsoft.com/en-us/library/ff953202.aspx
param ($WebAppName=$("http://$([Environment]::MachineName)"), $account="MACKIE\SPAdmin")
$wa = get-SPWebApplication $WebAppName

Set-SPwebApplication $wa -AuthenticationProvider (New-SPAuthenticationProvider) -Zone Default
#This causes a prompt about migration. Click Yes and continue.

#The following step sets the user as an administrator for the site. 
$wa = get-SPWebApplication $WebAppName
$account = (New-SPClaimsPrincipal -identity $account -identitytype 1).ToEncodedString()

#After the user is added as an administrator, we set the policy so that the user can have the correct access.
$zp = $wa.ZonePolicies("Default")
$p = $zp.Add($account,"PSPolicy")
$fc=$wa.PolicyRoles.GetSpecialRole("FullControl")
$p.PolicyRoleBindings.Add($fc)
$wa.Update()

#The final step is to trigger the user-migration process.
$wa = get-SPWebApplication $WebAppName
$wa.MigrateUsers($true)

