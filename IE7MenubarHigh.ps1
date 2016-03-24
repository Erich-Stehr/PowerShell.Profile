# From http://www.windowsitpro.com/article/articleid/97608/put-ie-70s-toolbar-back-where-it-belongs.html

#New-ItemProperty -path 'HKCU:\Software\Microsoft\Internet Explorer\Toolbar\WebBrowser' -name ITBAR7Position -propertyType int -value 1
New-ItemProperty -path 'HKCU:\Software\Microsoft\Internet Explorer\Toolbar\WebBrowser' -name ITBAR7Position -propertyType dword -value 1