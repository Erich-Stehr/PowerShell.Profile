# http://get-powershell.com/post/2008/11/14/PowerShell-and-TFS-Work-Items.aspx
function global:Get-TfsServer {
param([string] $serverName = "itstfs")
 
# load the required dll
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")
 
$propertiesToAdd = (
        ('VCS', 'Microsoft.TeamFoundation.VersionControl.Client', 'Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer'),
        ('WIT', 'Microsoft.TeamFoundation.WorkItemTracking.Client', 'Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore'),
        ('CSS', 'Microsoft.TeamFoundation', 'Microsoft.TeamFoundation.Server.ICommonStructureService'),
        ('GSS', 'Microsoft.TeamFoundation', 'Microsoft.TeamFoundation.Server.IGroupSecurityService')
    )
 
    # fetch the TFS instance, but add some useful properties to make life easier
    # Make sure to "promote" it to a psobject now to make later modification easier
    [psobject] $tfs = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($serverName)
    foreach ($entry in $propertiesToAdd) {
        $scriptBlock = '
            [System.Reflection.Assembly]::LoadWithPartialName("{0}") > $null
            $this.GetService([{1}])
        ' -f $entry[1],$entry[2]
        $tfs | add-member scriptproperty $entry[0] $ExecutionContext.InvokeCommand.NewScriptBlock($scriptBlock)
    }
    return $tfs
}
 
function Get-TfsWorkItem {
param($title = "*",
      $user="Andy Schneider",
      $Project='InfrastructureAutomation'
      )  
        
$WIQL = @"
SELECT [System.Id], [System.WorkItemType], [System.State], [System.AssignedTo], [System.Title] 
FROM WorkItems 
where [System.TeamProject] = '$Project'  AND [System.AssignedTo] = '$user' 
ORDER BY [System.WorkItemType], [System.Id] 
"@
 
$tfs = Get-TfsServer 
$workItems = $tfs.wit.query($WIQL)
return $workItems | where {$_.Title -like $title}
return $tfs
}
 
function Update-WorkItem {
param($item,$field,$value)
if (!$item.IsOpen) {$item.open()}
$item.Fields[$field].Value = $value
$item.Save()
return $item
}
 
 
function Update-TfsWorkItemTime {
param ($item,$hours)
 
begin {}
 
process {
 
  if ($_ -is [Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItem]) {
    $item = $_
    if (!$item.IsOpen) {$item.open()}
    if ($item.Fields["State"].Value = "Not Started") {$item.Fields["State"].Value = "In Progress"}
    $remainingWork = $item.Fields["Remaining Work"].Value
    $completedWork = $item.Fields["Completed Work"].Value
    $item.Fields["Completed Work"].Value = $completedwork + $hours
    $item.Fields["Remaining Work"].Value = $remainingWork - $hours
    $item.Save() | out-nulll
}
}
 
end {}
}
