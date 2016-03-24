# From http://sympmarc.com/2013/04/16/sharepoint-designer-2013-crashing-on-open-site-the-fix/
Remove-ItemProperty 'HKCU:\Software\Microsoft\Office\14.0\Common\Open Find\Microsoft SharePoint Designer\Settings\Open Site' ClientGUID
Remove-ItemProperty 'HKCU:\Software\Microsoft\Office\15.0\Common\Open Find\Microsoft SharePoint Designer\Settings\Open Site' ClientGUID