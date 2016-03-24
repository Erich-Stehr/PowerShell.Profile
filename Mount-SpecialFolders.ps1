# Mount-SpecialFolders.ps1 
# http://blogs.msdn.com/powershell/archive/2008/12/15/mount-specialfolders-ps1.aspx
# 
param($Folder="*", [SWITCH]$Verbose, [SWITCH]$PassThru) 
foreach ($f in [Enum]::GetValues([System.Environment+SpecialFolder]) |where {$_ -like $Folder}) { 
    $drive = New-PSDrive -Name $f -PSProvider FileSystem -Root ([Environment]::GetFolderPath($f)) -Scope Global -ErrorAction SilentlyContinue -Verbose:$verbose 
    if ($PassThru) 
    { 
        Write-Output $drive 
    } 
} 

