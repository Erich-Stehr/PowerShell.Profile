# from SharePoint2010PowerShell.pdf cheat sheet <http://powergui.org/entry.jspa?externalID=2812>
function New-SPFile($WebUrl, $ListName, $DocumentName, $Content)  
{  
	$stream = new-object System.IO.MemoryStream  
	$writer = new-object System.IO.StreamWriter($stream)  
	$writer.Write($content)
	$writer.Flush()  
	Get-SPWeb $WebUrl | 
		ForEach { $_.Lists[$ListName] } | 
		ForEach { $_.RootFolder.Files.Add($DocumentName, $stream, $true) ; $_.Update() }    
}  
# New-SPFile -WebUrl "http://mycompany/sites/mysite" -ListName "Shared Documents" -DocumentName "MyFirstDocument.txt" -Content "Power Blues"