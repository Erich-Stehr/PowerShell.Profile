Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\7.1\Text Editor' -name Guides -type string -value 'RGB(128,0,0) 72, 80, 132'
Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\8.0\Text Editor' -name Guides -type string -value 'RGB(128,0,0) 72, 80, 132'
Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\9.0\Text Editor' -name Guides -type string -value 'RGB(128,0,0) 72, 80, 132'


# from http://blogs.msdn.com/saraford/archive/2008/10/09/did-you-know-you-can-keep-recently-used-files-from-falling-off-the-file-tab-channel-331.aspx
Set-itemproperty -path HKCU:\Software\Microsoft\VisualStudio\9.0 -name UseMRUDocOrdering -type DWORD -value 1
Set-itemproperty -path HKCU:\Software\Microsoft\VisualStudio\8.0 -name UseMRUDocOrdering -type DWORD -value 1

# from http://blogs.msdn.com/saraford/archive/2008/11/24/did-you-know-you-can-customize-how-search-results-are-displayed-in-the-find-results-window-363.aspx
Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\8.0\Find' -name 'Find result format' -type string -value '$f$e($l,$c):$t\r\n'
Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\9.0\Find' -name 'Find result format' -type string -value '$f$e($l,$c):$t\r\n'

# from http://blogs.msdn.com/xmlteam/archive/2009/05/19/stylesheet-import-tree-in-the-xslt-debugger.aspx
Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\9.0\XmlEditor' -name 'XsltImportTree' -type string -value 'True'

# from http://www.tkachenko.com/blog/archives/000740.html  (20080503)
Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\9.0\XmlEditor' -name 'XsltIntellisense' -type string -value 'True'

#