param ($cred=$((get-credential "$env:USERDOMAIN\$env:USERNAME").GetNetworkCredential()))
$hive = 'c:\Program Files\Common Files\microsoft shared\Web Server Extensions\14'
& "${hive}\bin\stsadm.exe" -o updatefarmcredentials -userlogin "$($cred.Domain)\$($cred.UserName)" -password $cred.Password
& "${hive}\bin\stsadm.exe" -o updateaccountpassword -userlogin "$($cred.Domain)\$($cred.UserName)" -password $cred.Password -noadmin
iisreset -noforce
