$x = [xml]'<Module Name="FormPages" xmlns="http://schemas.microsoft.com/sharepoint/"><File Path="FormPages\jquery-1.7.1.min.js" Url="jquery-1.7.1.min.js" /><File Path="FormPages\jquery.SPServices-0.7.1a.min.js" Url="jquery.SPServices-0.7.1a.min.js" /><File Path="FormPages\form.aspx" Url="FFCDatabase-FormPages/form.aspx" /></Module>'
$x
$x.Module
$x.SelectNodes("Module")
$x.SelectNodes("File")
$x.SelectNodes(".") # works
$x.SelectNodes("./File")
$x.SelectNodes('node()[name()="File"]')
$x.SelectNodes('descendant::node()[name()="File"]') # but recurses down
$x.SelectNodes('child::node()[name()="File"]')
$x.SelectNodes('./node()[name()="File"]')
$x.SelectNodes('./node()') # not what I wanted, but returns something
$x.SelectNodes('./node()[localname()="File"]') # exception
$x.SelectNodes('./node()[name()="File"]')
$x.SelectNodes('./*[name()="File"]')
$x.SelectNodes('*[name()="File"]')
$x.SelectNodes('./*') # something
$x.SelectNodes('./*/*') # more than wanted
$x.SelectNodes('./*/*[name()="File"]') # works
$x.SelectNodes('*/*[name()="File"]') # works
$x.SelectNodes('./*[name()="File"]')
$x.SelectNodes('./*/*[name()="File"]') | % { $_.get_OuterXml() }
$x.SelectNodes('*/*[name()="File"]') | % { $_.get_OuterXml() }
$nsmgr = new-object Xml.XmlNamespaceManager # exception
$nsmgr = new-object System.Xml.XmlNamespaceManager # exception
$nsmgr = new-object System.Xml.XmlNamespaceManager $x.NameTable
$nsmgr.DefaultNamespace # returns ""
$nsmgr.AddNamespace("", "http://schemas.microsoft.com/sharepoint/")
$x.SelectNodes("./File", $nsmgr)
$x.SelectNodes("File", $nsmgr)
$x.SelectNodes("/File", $nsmgr)
$x.SelectNodes("/Module", $nsmgr)
$x.SelectNodes("Module", $nsmgr)
$nsmgr.DefaultNamespace
$x.SelectNodes("/:File", $nsmgr) # exception
$nsmgr.AddNamespace("s", "http://schemas.microsoft.com/sharepoint/") 
$x.SelectNodes("/s:File", $nsmgr)
$x.SelectNodes("s:Module", $nsmgr) # works
$x.SelectNodes("s:Module/s:File", $nsmgr) # will use
$x.SelectNodes("/s:Module/s:File", $nsmgr) # also, here

$nsmgr = new-object System.Xml.XmlNamespaceManager $x.NameTable
$nsmgr.AddNamespace("", "http://schemas.microsoft.com/sharepoint/")
$nsmgr.AddNamespace("s", "http://schemas.microsoft.com/sharepoint/") 
$x.SelectNodes("s:File", $nsmgr) # with the xml document/current node from feature

$x.SelectSingleNode("/s:Module/s:File[@Url='FFCDatabase-FormPages/form.aspx']", $nsmgr)

# ListInstance format, merge ProjectResources from backup
$origDoc = new-object Xml.XmlDocument
$origDoc.Load('\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-10-10T005006Z\ListInstanceElements.xml')
$OrigNsm = new-object Xml.XmlNamespaceManager $origDoc.NameTable
$origNsm.AddNamespace('', 'http://schemas.microsoft.com/sharepoint/')
$origNsm.AddNamespace('spf', 'http://schemas.microsoft.com/sharepoint/')
$origDoc.SelectNodes("/spf:Elements/spf:ListInstance[@Title='IT Projects']/spf:Data/spf:Rows/spf:Row", $origNsm) | 
	% { $dict.Add("$($_.SelectSingleNode("spf:Field[@Name='ID']", $origNsm).InnerText):$($_.VersionId)", 
		$_.SelectSingleNode("spf:Field[@Name='ProjectResources']", $origNsm).InnerText ) 
	}
$doc = new-object Xml.XmlDocument
$doc.Load('\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-11-02T204151Z\ListInstanceElements.xml')
$nsm = new-object Xml.XmlNamespaceManager $doc.NameTable
$nsm.AddNamespace('', 'http://schemas.microsoft.com/sharepoint/')
$nsm.AddNamespace('spf', 'http://schemas.microsoft.com/sharepoint/')
$doc.SelectNodes("/spf:Elements/spf:ListInstance[@Title='IT Projects']/spf:Data/spf:Rows/spf:Row", $nsm) | 
	% { 
		$node = $_.SelectSingleNode("spf:Field[@Name='ProjectResources']", $origNsm)
		$key = "$($_.SelectSingleNode("spf:Field[@Name='ID']", $origNsm).InnerText):$($_.VersionId)"
		if ($dict.ContainsKey($key)) { $node.InnerText = $dict[$key] }
	} 
$doc.Save('\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-11-02T204151Z\ListInstanceElements2.xml')
windiff '\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-11-02T204151Z\ListInstanceElements.xml' '\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-11-02T204151Z\ListInstanceElements2.xml'
windiff '\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-10-10T005006Z\ListInstanceElements.xml' '\\wdn-portal01\c$\Users\erich stehr\Documents\ITPortal2012-11-02T204151Z\ListInstanceElements2.xml'
