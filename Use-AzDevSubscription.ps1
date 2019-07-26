#Dev Connect
Enable-AzureRmAlias
$spnAppId = new-object GUID
$tenantId = new-object GUID
$secpasswd = ConvertTo-SecureString (New-Object String) -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($spnAppId, $secpasswd)
Login-AzureRmAccount -ServicePrincipal -Credential $credential -TenantId $tenantID -Subscription (New-Object String)
