### Show-IsAppFabricInstalled.ps1 -- http://blogs.msdn.com/rjacobs/archive/2010/05/14/how-to-detect-if-windows-server-appfabric-is-installed.aspx
### Comments point out the -Filter argument to gwmi and the V2 Get-HotFix cmdlet

function SearchKB($KBID)
{
    $found = $FALSE;

    # Get all the info using WMI 
    $results = get-wmiobject -class “Win32_QuickFixEngineering” -namespace "root\CIMV2"

    foreach ($objItem in $results) 
    { 
        if ($objItem.HotFixID -match $KBID) 
        { 
            $found=$TRUE
        } 
    }

    $found;
}

SearchKB -KBID "KB970622";
