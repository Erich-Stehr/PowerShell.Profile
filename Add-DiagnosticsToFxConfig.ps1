[CmdletBinding()]
param([string] $path=("$PWD\app.config"),
 [switch]$Switch=$false,
 [switch]$TraceSource=$false,
 [switch]$UnsharedSourceListener=$false,
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

if ($UnsharedSourceListener) {
	$TraceSource = $true
}
if ($TraceSource) {
	$Switch = true
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
if ($Switch) {
	$switchElem = VerifyElementExists $diagElem "switches"
	$addSwitchElem = VerifyElementExists $switchElem "add"
	VerifyAttributeExists $addSwitchElem "name" "ExampleSwitch"
	VerifyAttributeExists $addSwitchElem "value" "0" # switched off, but you'll need to adjust anyway
}

Write-Verbose "TraceSource/sources"
if ($TraceSource ) {
	$sourcesElem = VerifyElementExists $diagElem "sources"
	$sourceElem = VerifyElementExists $sourcesElem "source"
	VerifyAttributeExists $sourceElem "name" "ExampleSource"
	VerifyAttributeExists $sourceElem "switchName" "ExampleSwitch"
	VerifyAttributeExists $sourceElem "switchType" "System.Diagnostics.SourceSwitch"
	if ($UnsharedSourceListener) {
		$sourcelistenersElem = VerifyElementExists $sourceElem "listeners"
		$sourcelistenersaddElem = VerifyElementExists $sourcelistenersElem "add"
		VerifyAttributeExists $sourcelistenersaddElem "name" "console"
		VerifyAttributeExists $sourcelistenersaddElem "type" "System.Diagnostics.ConsoleTraceListener"
		$sourcelistenersaddfilterElem = VerifyElementExists $sourcelistenersaddElem "filter"
		VerifyAttributeExists $sourcelistenersaddfilterElem "type" "System.Diagnostics.EventTypeFilter"
		VerifyAttributeExists $sourcelistenersaddfilterElem "initializeData" "Error"
	} else {
		$sourcelistenersElem = VerifyElementExists $sourceElem "listeners"
		$sourcelistenersaddElem = VerifyElementExists $sourcelistenersElem "add"
		VerifyAttributeExists $sourcelistenersaddElem "name" "console"
	}
}

Write-Verbose "sharedListeners"
if ($SharedListener) {
	$sharedlistenersElem = VerifyElementExists $diagElem "sharedListeners"
	$sharedlistenersaddElem = VerifyElementExists $sharedlistenersElem "add"
	VerifyAttributeExists $sharedlistenersaddElem "name" "console"
	VerifyAttributeExists $sharedlistenersaddElem "type" "System.Diagnostics.ConsoleTraceListener"
	$sharedlistenersaddfilterElem = VerifyElementExists $sharedlistenersaddElem "filter"
	VerifyAttributeExists $sharedlistenersaddfilterElem "type" "System.Diagnostics.EventTypeFilter"
	VerifyAttributeExists $sharedlistenersaddfilterElem "initializeData" "Warning"
}

Write-Verbose $doc.get_OuterXml()
move $path "$path.bak" -ea SilentlyContinue
$doc.Save($path)