param ($cred=$(get-credential "$env:USERDOMAIN\$env:USERNAME"))
Set-SPManagedAccount -Identity $cred.UserName -ExistingPassword $cred.Password -UseExistingPassword
"Remember to `"iisreset -noforce`" when done changing passwords!"
