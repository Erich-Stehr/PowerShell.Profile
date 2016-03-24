[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::None,SupportsShouldProcess=$false)]
param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string[]] 
	# Path to working file(s)
	$path=$(throw "Requires file to work with"),
	[Parameter(Mandatory=$true)]
	[string]
	$elementName,
	[Parameter(Mandatory=$true)]
	[RegEx]
	$regex
	)
Begin {
	$PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("path"))
	function CheckPath([string]$path) {
		try {
			$rdr = [Xml.XmlReader]::Create($path)
			[void]$rdr.MoveToContent()
			if (!$rdr.ReadToFollowing($elementName)) { return $false } # doesn't have our target element
			return ($rdr.ReadElementContentAsString() -match $regex)
		} finally {
			if ($rdr) { $rdr.Close() }
		}		
	}
}
Process {
        if ($PIPELINEINPUT) {
                CheckPath $_
        }
        else {
                $path | % {
                        CheckPath $_
                }
        }
}
End {
}

<#
.SYNOPSIS
	Locate first instance of $elementName, match against $regex
.DESCRIPTION
	x
.INPUTS
	files/pathnames
.OUTPUTS
	[bool]
.EXAMPLE
	dir *-scr-req.xml | ? { Test-XmlElement.ps1 Owner geneva$ }
#>
