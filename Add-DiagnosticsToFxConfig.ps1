param([string] $path=("$PWD\app.config"),
 [switch]$Switch=$false,
 [switch]$TraceSource=$false,
 [switch]$SharedListener=$false
 )
if (!(Test-Path $path)) {
	Write-Error "$path doesn't exist!" -ErrorAction Stop
}
$doc = New-Object xml
$doc.PreserveWhitespace = $true # keep what we can of the formatting, XML doesn't consider between-attribute whitespace to possibly be significant
$doc.Load($path)
if ($null -eq $doc.configuration) {
	Write-Error "$path isn't a framework config file!" -ErrorAction Stop
}

function VerifyElementExists($node, $name) {
	if ($null -eq $node."$name") {
		$node.AppendChild($node.OwnerDocument.CreateElement($name))
	} else {
		$node."$name"
	}
}

function VerifyAttributeExists($elem, $name, $defaultValue) {
	if (!$elem.HasAttribute($name)) {
		$elem.SetAttribute($name, $defaultValue)
	}
}

$cfgElem = $doc.configuration

Write-Verbose "system.diagnostics"
$diagElem = VerifyElementExists $cfgElem  "system.diagnostics"

Write-Verbose "trace"
$traceElem = VerifyElementExists $diagElem  "trace"
VerifyAttributeExists $traceElem "autoflush" "true"
VerifyAttributeExists $traceElem "indentSize" "2"

Write-Verbose "switches"
$switchElem = VerifyElementExists $diagElem "switches"
#if ($switch) {
$addSwitchElem = VerifyElementExists $switchElem "add"
VerifyElementExists $addSwitchElem "name" "Switch$($addSwitchElem.ChildNodes.Count.ToString('D4'))"
VerifyElementExists $addSwitchElem "value" "0" # switched off, but you'll need to adjust anyway
#}

