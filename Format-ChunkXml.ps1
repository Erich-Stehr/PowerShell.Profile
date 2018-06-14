param (
	[Parameter(Mandatory=$false,ValueFromPipeline=$true)]
	[string]
	# XML file to work with
	$source,
	[string]
	# destination XML file set (will use `'{0:D3}' -f ` at end of BaseName)
	$DestinationTemplate,
	[int]
	# minimum size of file chunks
	$ChunkMinimum = 2047MB,
	[switch]
	# do tests instead of reading $source, throw results on test failure
	$test = $false
	)

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.LINQ")

function WriteAttribute($writer, $a)
{
	if ($a.Prefix -ne [string]::Empty) {
		if ($a.Prefix -eq "xmlns") {
			$nsuri = $null
		} else {
			$nsuri = $a.NamespaceUri
		}
		$writer.WriteAttributeString($a.Prefix, $a.LocalName, $nsuri, $a.Value) 
	} else {
		$writer.WriteAttributeString($a.Name, $a.Value)
	}
}

function Operate($reader=[System.Xml.XmlReader]::Create($source), $writer=[System.Xml.XmlWriter]::Create($DestinationTemplate)) {
	try {
		$item = $null # state held from Reader switch code
		$doc = [xml]"<root/>" # empty-ish document to create XmlElement's from
		$outPath = $DestinationTemplate
		$fileCount = 0
		[void]$reader.Read()
		while (!$reader.EOF)
		{
			switch ($reader.NodeType)
			{
				([System.Xml.XmlNodeType]::Element) {
					if ($reader.Depth -eq 0) {
						$doc = [xml]"<$($reader.Name)></$($reader.Name)>"
						$item = $doc.DocumentElement
						while($reader.MoveToNextAttribute()) {
							if (($reader.Prefix -ne [string]::Empty) -and (!$reader.Prefix.StartsWith("xmlns"))) {
								$item.SetAttribute($reader.Name, $reader.NamespaceUri, $reader.Value)
							} else {
								$item.SetAttribute($reader.Name, $reader.Value)
							}
						}
						[void]$reader.MoveToElement();
						if (![string]::IsNullOrWhitespace($reader.NamespaceUri)) {
							$writer.WriteStartElement($item.Name, $reader.NamespaceURI)
						} else {
							$writer.WriteStartElement($item.Name)
						}
						$item.Attributes | % { WriteAttribute $writer $_ }
						[void]$reader.Read()
					} else {
						$xelem = [System.Xml.Linq.XElement]::ReadFrom($reader)
						$xelem.WriteTo($writer)
						$writer.Flush()
						if ((dir $outPath).Length -gt $ChunkMinimum) {
							$writer.WriteFullEndElement()
							$writer.WriteEndDocument()
							$writer.Close()
							$outPath = ("{0}{1:D3}{2}" -f [IO.Path]::Combine((split-path $DestinationTemplate -Parent), 
								[IO.Path]::GetFileNameWithoutExtension($DestinationTemplate)),
								++$fileCount,
								[IO.Path]::GetExtension($DestinationTemplate)
							)
							$writer = [System.Xml.XmlWriter]::Create($OutPath)
							$writer.WriteStartElement($item.Name)
							$item.Attributes | % { WriteAttribute $writer $_ }
						}
					}
				}
				default {
					$writer.WriteNode($reader, $false)
				}
			}
		}
	} finally {
		$writer.Close()
	}
}

if ($test) {
	$testDoc = @'
<?xml version="1.0" standalone="no"?>
<!--This file represents another fragment of a book store inventory database-->
<bookstore xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<book
	genre="autobiography"
	publicationdate="1979"
	ISBN="0-7356-0562-9">
	<title>The Autobiography of Mark Twain</title>
	<Author>
		<first-name>Mark</first-name>
		<last-name>Twain</last-name>
	</Author>
	<price>7.99</price>
	</book>
	<book genre="autobiography" publicationdate="1981" ISBN="1-861003-11-0">
	<title>The Autobiography of Benjamin Franklin</title>
	<author>
		<first-name>Benjamin</first-name>
		<last-name>Franklin</last-name>
	</author>
	<price>8.99</price>
	</book>
</bookstore>
'@
	$DestinationTemplate = "$PWD\Demo.Books.Test.xml"
	$ChunkMinimum = 10
	Operate ([System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $testDoc)))
	$result = (dir "$PWD\Demo.Books.Test*.xml" | 
		? {$_.LastWriteTime -gt [datetime]::Now.AddSeconds(-30)})
	if (3 -ne $result.Count) {
		throw $result
	}
} else {
	Operate
}

<#
.SYNOPSIS
	Splits XML file into minimum sized chunks based on root's .Children
.DESCRIPTION
	Given an XML file too large to be processed by, say SQL Server (with a
	2GB limit), create a set of files that hold a copy of the root node with
	enough direct children of the root in sequence to either exceed the 
	$ChunkMinimumSize or be the last file in the sequence.

	Assumption: the XML schema should be of the form /_root_/_child_ and will
	probably misrepresent output of deeper trees.

	BUG: will create extra file with empty root if no children to fill last
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	System.Xml.XmlReader
.EXAMPLE
#>
