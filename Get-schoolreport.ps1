#$wc = new-object System.Net.WebClient; $html = "trying"; do { write-host $html; $html = $wc.DownloadString('http://www.schoolreport.org/') } until (-1 -ne $html.IndexOf("html")); $html # $ie = New-Object -ComObject InternetExplorer.Application; $ie.Visible = $true; $ie.Document.Body.InnerHTML = $html
$wc = new-object System.Net.WebClient; $html = "trying"; do { write-host $html; $html = $wc.DownloadFile('http://www.schoolreport.org/', "$pwd\$pid.htm"); $html = [string]::Join("`n", (get-content "$pwd\$pid.htm" -readCount 0)) } until (-1 -ne $html.IndexOf("html", [StringComparison]::InvariantCultureIgnoreCase)); $html ; $ie = New-Object -ComObject InternetExplorer.Application; $ie.Visible = $true; $ie.Navigate("file://$pwd/$pid.htm")
