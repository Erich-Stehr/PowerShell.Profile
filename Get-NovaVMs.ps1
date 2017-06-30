param (
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]
        #  credential for database
        $dbCred=$null,
        [switch]
        #  use PPE instead of production database
        $ppe=$false,
        [switch]
        #  filter out Enabled vs all
        $onlyEnabled
        )
$sqlSelectStatementAbove = @"
SELECT DISTINCT machine.Name, machine.DeploymentID, machine.TopologyID, machine.InternalIP, topology.[Password]
FROM dbo.AzureMachines as machine JOIN
	dbo.Topologies as topology ON (machine.TopologyID = topology.ID) JOIN
	dbo.Reservations as res ON (topology.ID = res.TopologyID)
WHERE topology.Enabled <> AND machine.Enabled <> 0 AND topology.TopologyStateID >= 5
ORDER BY machine.topologyID
"@

if ($null -eq $dbCred) {
	if ($ppe) {
		$dbCred = Get-Credential 'novatopo'
	} else {
		$dbCred = Get-Credential 'orion'
	}
}

if ($ppe) {
	$dbDataSource = "novatoposql-westus2.database.windows.net"
	$dbName = "OrionV2_ppe"
} else {
	$dbDataSource = "novatoposqlprod-westus2.database.windows.net"
	$dbName = "OrionV2prod"
}
if ($env:COMPUTERNAME -match 'novatasks?2.*') {
	$iprange = '^10\.0\.0\.'
} elseif ($env:COMPUTERNAME -match 'novatasks?3.*') {
	$iprange = '^10\.3\.0\.'
} else {
	trap {break;}
	throw "Not running on expected novatask task servers"
}

if (!$onlyEnabled) {
	$sqlSelectStatementAbove = $sqlSelectStatementAbove -replace "topology.Enabled <> 0 AND machine.Enabled <> 0 AND ",""
}

	.\Invoke-SQLCommand.ps1 -datasource $dbDataSource -database $dbName -Credential $dbCred -sql $sqlSelectStatementAbove | ? {$_.InternalIp -match $iprange }
<#
.SYNOPSIS
	Get VMs associated with all active Nova topologies
.DESCRIPTION
	Uses the script .\Invoke-SQLCommand.ps1
	from <http://www.leeholmes.com/blog/2007/10/19/interacting-with-sql-databases-in-powershell-invoke-sqlcommand/>
	to return each of the active Nova VMs.

	This needs to be run from a novatask* server for each of the Azure subscriptions
	in order to get to the internal IP address for the topologies for deployment, but
	each subscription has its own isolated subnet.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	PSObjects with machine Name, TopologyId, InternalIP, and Password (for administrator account)
.EXAMPLE
	.\Get-NovaVMs.ps1 $productionDbCred |
		select Name,@{n='Pingable';e={(Test-Connection -computername ($_.InternalIP) -quiet)}}
#>
