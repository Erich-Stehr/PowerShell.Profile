$farmCred = (get-credential REDMOND\xhdevfm).GetNetworkCredential() 
$farmPhrase = (Get-Credential FarmPhrase).GetNetworkCredential() 
.\PSConfig.exe -CMD configdb -CREATE -SERVER "osgsecdev01.redmond.corp.microsoft.com" -DATABASE "XHUBDEV_Config_DB" -USER "$($farmCred.Username)" -PASSWORD "$($farmCred.Password)" -PASSPHRASE "$($farmPhrase.Password)" -ADMINCONTENTDATABASE "XHUBPPE_AdminContent_DB" -CMD helpcollections -INSTALLALL -CMD secureresources -CMD services -INSTALL -CMD installfeatures -CMD adminvs -PROVISION -PORT 443 -WINDOWSAUTHPROVIDER onlyusentlm -CMD applicationcontent -INSTALL 
# .\PSConfig.exe -cmd adminvs -UNPROVISION
# .\PSConfig.exe -cmd adminvs -PROVISION -PORT 443 -WINDOWSAUTHPROVIDER onlyusentlm
Set-SPCentralAdministration -Port 443 -Confirm:$false
# Set-SPAlternateURL -Identity "https://osgsecdev01" -Url "https://osgsecdev01.redmond.corp.microsoft.com" 
Set-SPAlternateURL -Identity "https://osgsecdev01" -Url "https://xhubdev.redmond.corp.microsoft.com" 


$appCred = (get-credential REDMOND\xhdevapp)
New-SPManagedAccount –Credential $appCred 
New-SPServiceApplicationPool -Name "XHUBDEV Application Pool" -Account "$($appCred.Username)" 
$ap = New-SPAuthenticationProvider
New-SPWebApplication -ApplicationPool "XHUBDEV Application Pool" -ApplicationPoolAccount "$($appCred.UserName)" -Name "XHUBDEV" -Url "https://osgsecdev01" -DatabaseName "XHUBDEV_Content_DB_Root" -Path "C:\Inetpub\vroots\XHUBDEV" -Port 443 -SecureSocketsLayer -AuthenticationProvider $ap -hostheader "osgsecdev01" 
New-SPSite https://osgsecdev01 -OwnerAlias "$([Environment]::UserDomain)\$([Environment]::UserName)"  -Name "XHubDev" -Template "STS#0" 
#Set-SPAlternateURL -Identity "https://osgsecdev01" -Url "https://xhubdev" 
#Set-SPAlternateURL -Identity "https://osgsecdev01.redmond.corp.microsoft.com" -Url "https://xhubdev.redmond.corp.microsoft.com" 
