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

function CreateElementAtNode($node, $tag) {
    trap {break;}
	$node.AppendChild($node.OwnerDocument.CreateElement($tag))
}

function VerifyElementExists($node, $tag) {
	if ($null -eq $node."$tag") {
		CreateElementAtNode $node $tag
	} else {
		$node."$tag"
	}
}

function VerifyAttributeExists($elem, $name, $defaultValue) {
	if (!$elem.HasAttribute($name)) {
		$elem.SetAttribute($name, $defaultValue)
	}
}

# $cfgElem = $doc.configuration
$cfgElem = $doc.ChildNodes | ? { $_.NodeType -eq [System.Xml.XmlNodeType]::Element } # we want the root element, not the XML declaration or String.Empty; if the root is empty, .configuration is String.Empty

Write-Verbose "system.diagnostics"
$diagElem = VerifyElementExists $cfgElem  "system.diagnostics"

Write-Verbose "trace"
$traceElem = VerifyElementExists $diagElem  "trace"
VerifyAttributeExists $traceElem "autoflush" "true"
VerifyAttributeExists $traceElem "indentsize" "2"
VerifyElementExists $traceElem "listeners"

Write-Verbose "switches"
if ($Switch) {
	$switchElem = VerifyElementExists $diagElem "switches"
	$switchCount = $switchElem.ChildNodes.Count
	$addSwitchElem = CreateElementAtNode $switchElem "add"
	VerifyAttributeExists $addSwitchElem "name" "ExampleSwitch${switchCount}"
	VerifyAttributeExists $addSwitchElem "value" "0" # switched off, but you'll need to adjust anyway
}

Write-Verbose "TraceSource/sources"
if ($TraceSource ) {
	$sourcesElem = VerifyElementExists $diagElem "sources"
	$sourcesCount = $sourcesElem.ChildNodes.Count
	$sourceElem = CreateElementAtNode $sourcesElem "source"
	VerifyAttributeExists $sourceElem "name" "ExampleSource${sourcesCount}"
    if ($Switch) {
	    VerifyAttributeExists $sourceElem "switchName" "ExampleSwitch${switchCount}"
    } else {
	    VerifyAttributeExists $sourceElem "switchValue" "ActivityTracing,Verbose"
    }
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
	function VerifySharedListener($name, $type, $additionalAttributes, $IsFiltered=$false) {
		$sharedlistenersElem = VerifyElementExists $diagElem "sharedListeners"
		if (!($sharedlistenersElem.add | ? { $_.name -eq $name })) {
			$sharedlistenersaddElem = CreateElementAtNode $sharedlistenersElem "add"
			VerifyAttributeExists $sharedlistenersaddElem "name" $name
			VerifyAttributeExists $sharedlistenersaddElem "type" $type
			if ($additionalAttributes.Count) {
				$additionalAttributes.GetEnumerator() | % { VerifyAttributeExists $sharedlistenersaddElem $_.Key $_.Value }
			}
			if ($IsFiltered) {
				$sharedlistenersaddfilterElem = VerifyElementExists $sharedlistenersaddElem "filter"
				VerifyAttributeExists $sharedlistenersaddfilterElem "type" "System.Diagnostics.EventTypeFilter"
				VerifyAttributeExists $sharedlistenersaddfilterElem "initializeData" "ActivityTracing,Verbose"
			}
		}
	}
	VerifySharedListener "console" "System.Diagnostics.ConsoleTraceListener" @{} $true
	VerifySharedListener "textwriter" "System.Diagnostics.TextWriterTraceListener" @{initializeData=".\TextWriter.log";traceOutputOptions="ProcessId, DateTime"} $false
	VerifySharedListener "eventlog" "System.Diagnostics.EventLogTraceListener" @{initializeData="ExistingEventSourceName"} $false
	VerifySharedListener "xmlwriter" "System.Diagnostics.XmlWriterTraceListener" @{initializeData=".\XmlWriter.log";traceOutputOptions="ProcessId, DateTime"} $false
	VerifySharedListener "csvwriter" "System.Diagnostics.DelimitedListTraceListener" @{initializeData=".\DelimitedListWriter.log";delimiter=",";traceOutputOptions="ProcessId, DateTime"} $false
	VerifySharedListener "filelog" "Microsoft.VisualBasic.Logging.FileLogTraceListener, Microsoft.VisualBasic, Version=8.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a, processorArchitecture=MSIL" @{initializeData="FileLogWriter";traceOutputOptions="ProcessId, DateTime";logFileCreationSchedule="Daily"} $false # defaults to $env:APPDATA\$CompanyName\$ProductName\$ProductVersion\$BaseFile.log (vars from version resource or additional attributes)
}

Write-Verbose $doc.get_OuterXml()
move $path "$path.bak" -ea SilentlyContinue
$doc.Save($path)