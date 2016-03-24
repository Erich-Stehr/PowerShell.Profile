#demonstrate XmlWriter
try {
	# settings code originally from http://msdn.microsoft.com/en-us/library/system.xml.xmlwritersettings.aspx
	$settings = New-Object system.Xml.XmlWriterSettings
	$settings.Indent = $true
	$settings.OmitXmlDeclaration = $false
	$settings.NewLineOnAttributes = $true

	# Create a new Writer
	$writer = [system.xml.XmlWriter]::Create("$PWD\demo.xml", $settings)
	$settings.OmitXmlDeclaration = $true  # don't want them in the web parts, they'll choke

	# A familiar demo, here found from <http://www.xtremedotnettalk.com/showthread.php?t=81419> and translated
    $writer.WriteStartDocument($false);
    #$writer.WriteDocType("bookstore", $null, "books.dtd", $null); # Needs XmlReaderSettings.ProhibitDTD = $false
    $writer.WriteComment("This file represents another fragment of a book store inventory database");
    $writer.WriteStartElement("bookstore");
    $writer.WriteStartElement("book", $null);
    $writer.WriteAttributeString("genre","autobiography");
    $writer.WriteAttributeString("publicationdate","1979");
    $writer.WriteAttributeString("ISBN","0-7356-0562-9");
    $writer.WriteElementString("title", $null, "The Autobiography of Mark Twain");
    $writer.WriteStartElement("Author", $null);
    $writer.WriteElementString("first-name", "Mark");
    $writer.WriteElementString("last-name", "Twain");
    $writer.WriteEndElement();
    $writer.WriteElementString("price", "7.99");
    $writer.WriteEndElement();
    $writer.WriteEndElement();
	
	$writer.WriteEndDocument(); # covers any open stack items
	# Flush the writer (and close the file) 
	$writer.Flush()
}
finally {
	if ($writer -ne $null) { $writer.Close() }
}

function Demo-XmlReader([System.Xml.XmlReader]$reader=[system.xml.XmlReader]::Create("$PWD\\demo.xml"))
{
	function Format($reader, $nodeTypeName) {
		$reader | select Depth,AttributeCount,NodeType,@{n='NodeTypeName';e={$nodeTypeName}},Prefix,Name,Value
	}
	
    while ($reader.Read())
    {
        switch ($reader.NodeType)
        {
        ([System.Xml.XmlNodeType]::ProcessingInstruction) {
            Format $reader "ProcessingInstruction"
            $piCount++;
            break;
		}
        DocumentType {
            Format $reader "DocumentType"
            $docCount++;
            break;
		}
        Comment {
            Format $reader "Comment"
            $commentCount++;
            break;
		}
        Element {
            Format $reader "Element"
            while($reader.MoveToNextAttribute())
            {
                Format $reader, "Attribute"
            }
            $elementCount++;
            
            if ($reader.HasAttributes) {
                $attributeCount += $reader.AttributeCount;
			}
            break;
		}
        Text {
            Format $reader "Text"
            $textCount++;
            break;
		}
        Whitespace {
            $whitespaceCount++;
            break;
        	}
	}
    }
}
Demo-XmlReader

function Demo-XDocument($uriPath="$PWD\demo.xml")
{
	[void]([Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq"))
	$xdoc = [System.Xml.Linq.XDocument]::Load($uriPath)
	$xdoc.Descendants("book") | % { $_.Element("title").Value }
}
Demo-XDocument