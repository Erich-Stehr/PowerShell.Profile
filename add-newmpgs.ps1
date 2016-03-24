param ([string]$target= 'Episode capture list.txt', [string]$location=$pwd, [string]$extension='.mpg')
$local:pickup = @{}; 
# mark hashtable as needing to be picked up from the files presented
dir (join-path $location "*$extension") | % { $pickup[($_.name)] = $true }
# mark the files from the target as having been picked up 
gc -path $target | ? { $_ -match $extension } | % { $pickup[($_)] = $false } 
# take the files that are still marked as needing pickup, and add their sorted names to the target
$pickup.Keys | ? { $pickup[$_] } | sort-object | add-content -path $target