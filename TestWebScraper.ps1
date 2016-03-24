param ($scrapeRequestPath)
D:\app\Scraperservice\WebScraper.exe scrape "$scrapeRequestPath" d:\app\scraperservice\ScraperService.exe d:\data\ScraperService\RequestsOut *>&1 |
	tee.exe "d:\data\ScraperService\Temp\$([IO.Path]::GetFileNameWithoutExtension($scrapeRequestPath)).out"
switch ($LASTEXITCODE) {
	1 { gc "D:\Data\ScraperService\RequestsOut\$([IO.Path]::GetFileName($scrapeRequestPath) -replace '-req.xml','-sta.xml').scp" }
	0 { write-verbose "Completed $(Get-Date -f o)" }
	-1 { write-warning "Fatal Error $(Get-Date -f o)" }
}
