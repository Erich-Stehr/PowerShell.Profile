$LMSParamsKey = 'HKLM:\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters' #KB 281308
$BackConnectHostNameKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0' #KB 896861
New-ItemProperty -Path $LMSParamsKey -Name DisableStrictNameChecking -PropertyType DWORD -Value 1 #KB 281308
New-ItemProperty -Path $BackConnectHostNameKey -Name BackConnectionHostNames -PropertyType MultiString -Value "wdn-portal01","wdn-portal01.mackie.com","asg.eaw.com","asg.loudtechinc.com","ffc.loudtechinc.com","mysites.loudtechinc.com","portal.loudtechinc.com","sandbox.loudtechinc.com","groupvelocity.loudtechinc.com"  #KB 896861
net stop iisadmin
net start iisadmin
net stop w3svc
net start w3svc