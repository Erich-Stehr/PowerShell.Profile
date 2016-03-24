$xnt = new-object System.Xml.NameTable
$xnm = new-object System.Xml.XmlNamespaceManager $xnt
$xnm.AddNamespace("soap","http://schemas.xmlsoap.org/soap/envelope/")
$xnm.AddNamespace("xsi","http://www.w3.org/2001/XMLSchema-instance")
$xnm.AddNamespace("xsd","http://www.w3.org/2001/XMLSchema")
$xnm.AddNamespace("wss","http://schemas.microsoft.com/sharepoint/soap/")
$doc = new-object System.Xml.XmlDocument $xnt
write-output '$doc.Load("$pwd\....") ; $doc.SelectNodes("/",$xnm)'