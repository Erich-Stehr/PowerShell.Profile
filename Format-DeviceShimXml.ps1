param (
	[Parameter(Mandatory=$false,ValueFromPipeline=$true)]
	[string] 
	# XML file to work with
	$source,
	[switch]
	# do a test instead of reading $source, output result on test failure
	$test = $false,
	[switch]
	# send out XmlElements instead of strings
	$xml = $false
	)

function Send($item) {
	if ($xml) {
		$item
	} else {
		$item.get_OuterXml()
	}
}

function SetAttributeIfNotNull($node, $name, $value) {
	if ($value -ne $null) {
		$node.SetAttribute($name, $value)
	}
}

function SetAttributeEmptyIfNull($node, $name, $value) {
	if ($value -eq $null) {
		$value = [String]::Empty
	}
	$node.SetAttribute($name, $value)
}

function Operate($reader=[System.Xml.XmlReader]::Create($source)) {
	$item = $null # state held from Reader switch code
	$doc = [xml]"<root/>" # empty-ish document to create XmlElement's from
	[void]$reader.MoveToContent() # combined with following read, skips root
	while ($reader.Read())
	{
		switch ($reader.NodeType)
		{
			([System.Xml.XmlNodeType]::Element) {
				if ($reader.Name -match "gateway|browser") {
					if ($item -ne $null) {
						Send $item
					}
					$item = $doc.CreateElement($reader.Name)
					SetAttributeEmptyIfNull $item "id" $reader["id"]
					SetAttributeIfNotNull $item "parentID" $reader["parentID"]
				} elseif ($reader.Name -eq "capability" -and ($reader["name"] -match "UniqueID")) {
					$item.SetAttribute($reader["name"], $reader["value"])
				}
			}
			default {
				# just eat it
			}
		}
	}
	Send $item
}

if ($test) {
	$xml = $true
	$testDoc = @'
<browsers>
<!-- throw off the scent -->
	<gateway id="deviceShim">
		<capabilities>
			<capability name="IgnoreMe" value="IgnoreMe"/>
			<capability name="DeviceUniqueID" value="Unknown"/>
		</capabilities>
	</gateway>
	<gateway id="deviceShim_android_ROOT_platformversion_override" parentID="deviceShim">
		<identification>
			<capability name="_support_deviceIdentity" match="\bAndroid" />
		</identification>
		<capture>
			<capability name="_support_deviceIdentity" match="\bAndroid" />
		</capture>
		<capabilities>
			<capability name="DefaultDisplayOrientation" value="portrait" />
			<capability name="DeviceClass" value="smartphone" />
			<capability name="DeviceUniqueID" value="Android_Generic" />
		</capabilities>
	</gateway>
	<gateway id="deviceShim_browserid_1" parentID="deviceShim">
		<capture />
	</gateway>
	<browser id="deviceShim_browserid_2" parentID="deviceShim_browserid_1">
	<identification>
		<capability name="_support_browserIdentity" match="(?i)(^Mozilla)" />
	</identification>
	<capture />
	</browser>
	<browser id="deviceShim_browserid_3593_2" parentID="deviceShim_browserid_2">
	<identification>
		<capability name="_support_browserIdentity" match="^Mozilla/.*Windows Phone (?'wpversion'[0-9.]+?); Android\s?(?'andver'[0-9.]+?); Xbox; Xbox One\).*Edge/(?'Edgever'[0-9.]+?)$" />
	</identification>
	<capture>
		<capability name="_support_browserIdentity" match="^Mozilla/.*Windows Phone (?'wpversion'[0-9.]+?); Android\s?(?'andver'[0-9.]+?); Xbox; Xbox One\).*Edge/(?'Edgever'[0-9.]+?)$" />
	</capture>
	<capabilities>
		<capability name="browser" value="Internet Explorer Mobile" />
		<capability name="BrowserPackageVersion" value="${xmajver}.${xminver}" />
		<capability name="BrowserType" value="mobile_web_browser" />
		<capability name="BrowserUniqueID" value="ICM-5171" />
	</capabilities>
	</browser>
</browsers>
'@
$expected = [string]::Join('', @(
	'<gateway id="deviceShim" DeviceUniqueID="Unknown" />',
	'<gateway id="deviceShim_android_ROOT_platformversion_override" parentID="deviceShim" DeviceUniqueID="Android_Generic" />',
	'<gateway id="deviceShim_browserid_1" parentID="deviceShim" />',
	'<browser id="deviceShim_browserid_2" parentID="deviceShim_browserid_1" />',
	'<browser id="deviceShim_browserid_3593_2" parentID="deviceShim_browserid_2" BrowserUniqueID="ICM-5171" />'
))
	$result = [string]::Join('', @(Operate ([System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $testDoc))) |
		% { $_.get_OuterXml() }))
	if ($expected -ne $result) {
		$result
	}
} else {
	Operate
}

<#
.SYNOPSIS
	Take deviceShim XML file, return extracted data
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	System.Xml.XmlReader
.EXAMPLE
#>
