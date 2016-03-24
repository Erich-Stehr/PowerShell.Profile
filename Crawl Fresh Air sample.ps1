[System.Reflection.Assembly]::LoadFrom("$profilepath\HtmlAgilityPack.dll")
#& 'H:\users\erichs\Career\RHT\Loud\HtmlAgilityPack 1.4.6 Documentation.chm'
$htmlweb = new-object HtmlAgilityPack.HtmlWeb
$htmlweb -eq $null
$page = $htmlweb.Load("http://www.npr.org/templates/rundowns/rundown.php?prgId=13&prgDate=10-01-2012")
if ($htmlweb.StatusCode -eq 'OK') {
#gtn $page.DocumentNode
$page.DocumentNode.SelectNodes("//div[@class='storywrap ']")
$page.DocumentNode.SelectNodes("//div[@class='storywrap ']/div[@class='storycontent']")
$page.DocumentNode.SelectNodes("//div[@class='storywrap ']/div[@class='storycontent']/h4/a/text()")
$page.DocumentNode.SelectNodes("//div[contains(@class,'storywrap')]/div[contains(@class,'storycontent')]/h4/a/text()")
$page.DocumentNode.SelectNodes("//div[contains(@class,'storywrap')]/div[contains(@class,'storycontent')]/h4/a")
$page.DocumentNode.SelectNodes("//div[contains(@class,'storywrap')]/ul[contains(@class,'storyoptions')]/li/a[contains(@class,'more')]")
# identical: $page.DocumentNode.SelectNodes("//div[contains(@class,'storywrap')]/ul[contains(@class,'storyoptions')]/li/a[contains(@class,'more')]/@href")
}
