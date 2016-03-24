function PullW3cRec ([uri] $uri)
{
	$wc = new-object System.Net.WebClient
	$file = ($uri.Segments[-1] -replace "/","")+".html"
	#$rec = $wc.DownloadString($uri)
	$str = $wc.OpenRead($uri); $sr = new-object System.IO.StreamReader $str,[Text.Encoding]::UTF8; $rec = $sr.ReadToEnd(); $sr.Close(); $str.Close()
	$rec -replace """$($uri.AbsoluteUri)","""" -replace """http://www.w3.org/StyleSheets/TR/",""""  -replace """http://www.w3.org/Icons/","""" | 
		out-file $file -encoding UTF8 -width ([int]::MaxValue)
}

$xqueryrecs = [uri]"http://www.w3.org/TR/2007/REC-xquery-20070123/", 
	[uri]"http://www.w3.org/TR/2007/REC-xslt20-20070123/", 
	[uri]"http://www.w3.org/TR/2007/REC-xpath20-20070123/", 
	[uri]"http://www.w3.org/TR/2007/REC-xpath-functions-20070123/", 
	[uri]"http://www.w3.org/TR/2007/REC-xpath-datamodel-20070123/", 
	[uri]"http://www.w3.org/TR/2007/REC-xslt-xquery-serialization-20070123/", 
	[uri]"http://www.w3.org/TR/2007/REC-xqueryx-20070123", 
	[uri]"http://www.w3.org/TR/2007/REC-xquery-semantics-20070123/"
