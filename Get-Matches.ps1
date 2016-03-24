### http://powershell.com/cs/blogs/tobias/archive/2011/10/27/regular-expressions-are-your-friend-part-1.aspx
# Usage: gc -readCount 0 file.txt | Get-Matches "(?<Name1>\w+) (?<Name2>\w+)"
function global:Get-Matches {
  param(
    [Parameter(Mandatory=$true)]
    $Pattern,
    
    [Parameter(ValueFromPipeline=$true)]
    $InputObject
  )
  
 begin {
  
    try {
   $regex = New-Object Regex($pattern) 
  } 
  catch {
   Throw "Get-Matches: Pattern not correct. '$Pattern' is no valid regular expression."
  }
  $groups = @($regex.GetGroupNames() | 
  Where-Object { ($_ -as [Int32]) -eq $null } |
  ForEach-Object { $_.toString() })
 } 

 process { 
  foreach ($line in $InputObject) {
   foreach ($match in ($regex.Matches($line))) {
    if ($groups.Count -eq 0) {
     ([Object[]]$match.Groups)[-1].Value
    } else {
     $rv = 1 | Select-Object -Property $groups
     $groups | ForEach-Object {
      $rv.$_ = $match.Groups[$_].Value
     }
     $rv
    }
   }
  }
 }
}

