# From http://technet.microsoft.com/en-us/library/ff381249.aspx and http://stackoverflow.com/questions/313622/powershell-script-to-change-service-account
param ($cred=$((get-credential "$env:USERDOMAIN\$env:USERNAME").GetNetworkCredential()))

function BounceServiceAccountCredentials($servicename, $account="$($cred.Domain)\$($cred.UserName)", $password=$($cred.Password))
{
	$svc=gwmi win32_service -filter "name='$servicename'"
	$svc.StopService() 
	$svc.change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null) 
	$svc.StartService()
}

BounceServiceAccountCredentials "FASTSearchService"
BounceServiceAccountCredentials "FASTSearchBrowserEngine"
BounceServiceAccountCredentials "FASTSearchMonitoring"
BounceServiceAccountCredentials "QRProxyService"
BounceServiceAccountCredentials "FASTSearchSamAdmin"
BounceServiceAccountCredentials "FASTSearchSamWorker"

"Manually reset the 'FASTSearchAdminAppPool' from IIS Manager!"
