param   
(   
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]   
    [ValidateNotNull()]   
    [Type] $Type,   
   
    [Parameter(ValueFromPipelineByPropertyName = $true)]   
    [ValidateNotNullOrEmpty()]   
    [string] $Name = $Type.Name   
)   
   
BEGIN {   
    $ErrorActionPreference = 'Stop'   
    $PSTypeAccelerators = [Type]::GetType("System.Management.Automation.TypeAccelerators, $([PSObject].Assembly.FullName)")   
}   
   
PROCESS {   
    if ($PSTypeAccelerators::Add) {   
        $PSTypeAccelerators::Add($Name, $Type)   
    } elseif ($PSTypeAccelerators::AddReplace) {   
        $PSTypeAccelerators::AddReplace($Name, $Type)   
    }   
}   

<#
.SYNOPSIS
	Create custom type accelerators like [ADSI], [PSObject], etc.
.DESCRIPTION
	http://www.iheartpowershell.com/2012/07/add-pstypeaccelerator.html
.INPUTS
	[Type]
.EXAMPLE
You can add a single alias: 

PS> Add-PSTypeAccelerator System.Management.Automation.PSCredential   
.EXAMPLE 
Or an entire namespace or assembly (by removing the namespace filter): 

PS> [System.Reflection.Assembly]::LoadWithPartialName('System.Messaging').GetTypes() |? { $_.Namespace -eq 'System.Messaging' } | Add-PSTypeAccelerator   
.EXAMPLE
Or you can create named aliases: 

PS> Add-PSTypeAccelerator -Type System.Management.Automation.ErrorRecord -Name Error   
#>