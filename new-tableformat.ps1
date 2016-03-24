# from <http://jtruher3.wordpress.com/2011/04/19/a-tool-for-table-formatting/>
param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$object,
    [Parameter(Mandatory=$true,Position=0)][object[]]$property,
    [Parameter()][switch]$Complete,
    [Parameter()][switch]$auto,
    [Parameter()][string]$name,
    [Parameter()][switch]$force
    )
End
{
if ( $object )
{
    if ( $object -is "PSObject")
    {
        $TN = $object.psobject.typenames[0]
    }
    else
    {
        $TN = $object.gettype().fullname
    }
}
elseif ( $name )
{
    $TN = $name
}
$NAME = $TN.split(".")[-1]
$sb = new-object System.Text.StringBuilder
if ( $complete )
{
    [void]$sb.Append("<Configuration>`n")
    [void]$sb.Append(" <ViewDefinitions>`n")
}
[void]$sb.Append(" <View>`n")
[void]$sb.Append(" <Name>${Name}Table</Name>`n")
[void]$sb.Append(" <ViewSelectedBy>`n")
[void]$sb.Append(" <TypeName>${TN}</TypeName>`n")
[void]$sb.Append(" </ViewSelectedBy>`n")
[void]$sb.Append(" <TableControl>`n")
if ( $auto )
{
    [void]$sb.Append(" <AutoSize />`n")
}
[void]$sb.Append(" <TableHeaders>`n")
# 
# Now loop through the properties, creating a header for each 
# provided property
#
foreach($p in $property)
{
    if ( $p -is "string" )
    {
        [void]$sb.Append(" <TableColumnHeader><Label>${p}</Label></TableColumnHeader>`n")
    }
    elseif ( $p -is "hashtable" )
    {
        $Label = $p.keys | ?{$_ -match "^L|^N" }
        if ( ! $Label )
        {
            throw "need Name or Label Key"
        }
        [void]$sb.Append(" <TableColumnHeader>`n")
        [void]$sb.Append(" <Label>" + $p.$label + "</Label>`n")
        $Width = $p.Keys |?{$_ -match "^W"}|select -first 1
        if ( $Width )
        {
            [void]$sb.Append(" <Width>" + $p.$Width + "</Width>`n")
        }
        $Align = $p.Keys |?{$_ -match "^A"}|select -first 1
        if ( $Align )
        {
            [void]$sb.Append(" <Alignment>" + $p.$align + "</Alignment>`n")
        }
        [void]$sb.Append(" </TableColumnHeader>`n")
        # write-host -for red ("skipping " + $p.Name + " for now")
    }
}
[void]$sb.Append(" </TableHeaders>`n")
[void]$sb.Append(" <TableRowEntries>`n")
[void]$sb.Append(" <TableRowEntry>`n")
[void]$sb.Append(" <TableColumnItems>`n")
foreach($p in $property)
{
    if ( $p -is "string" )
    {
        [void]$sb.Append(" <TableColumnItem><PropertyName>${p}</PropertyName></TableColumnItem>`n")
    }
    elseif ( $p -is "hashtable" )
    {
        [void]$sb.Append(" <TableColumnItem>")
        $Name = $p.Keys | ?{ $_ -match "^N" }|select -first 1
        if ( $Name )
        {
            $v = $p.$Name
            [void]$sb.Append("<PropertyName>$v</PropertyName>")
        }
        $Expression = $p.Keys | ?{ $_ -match "^E" }|select -first 1
        if ( $Expression )
        {
            $v = $p.$Expression
            [void]$sb.Append("<ScriptBlock>$v</ScriptBlock>")
        }
        $Format = $p.Keys | ?{$_ -match "^F" }|select -first 1
        if ( $Format )
        {
            $v = $p.$Format
            [void]$sb.Append("<FormatString>$v</FormatString>")
        }
        [void]$Sb.Append("</TableColumnItem>`n")
    }
}
[void]$sb.Append(" </TableColumnItems>`n")
[void]$sb.Append(" </TableRowEntry>`n")
[void]$sb.Append(" </TableRowEntries>`n")
[void]$sb.Append(" </TableControl>`n")
[void]$sb.Append(" </View>`n")
if ( $complete )
{
    [void]$sb.Append(" </ViewDefinitions>`n")
    [void]$sb.Append("</Configuration>`n")
}
$sb.ToString()
}

<#
.SYNOPSIS
        "... use Format-Table to get the output exactly how I wanted and then just substitute my tool for Format-Table."
.DESCRIPTION
       	from <http://jtruher3.wordpress.com/2011/04/19/a-tool-for-table-formatting/>
.INPUTS
        example data for view
.OUTPUTS
        .ps1xml for table view
.COMPONENT
        Microsoft.SharePoint.PowerShell
.EXAMPLE
	PS> get-process lsass|format-table id,handles,name,@{L="HandlesKB";E={$_.Handles/1KB};A="Right";F="{0:N2}"} -au
	PS> get-process lsass|new-tableformat id,handles,name,@L="HandlesKB";E={$_.Handles/1KB};A="Right";F="{0:N2}"} -au comp > handleKB.format.ps1xml
	PS> update-formatdata handleKB.format.ps1xml
	PS> get-process lsass | format-table -view ProcessTable

	id  handles name  HandlesKB
	--  ------- ----  ---------
	552 1263    lsass      1.23

	PS> [timespan]"1.0:0" | format-table @{n='TimeSpan';e={$_.ToString()}}
#>
