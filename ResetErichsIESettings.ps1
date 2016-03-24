### ResetErichsIESettings.ps1
$key = 'HKCU:\Software\Microsoft\Internet Explorer\Main'
$mydocs = [Environment]::GetFolderPath("MyDocuments")
Set-ItemProperty $key 'Start Page' "${mydocs}\estehrHome.html"
Set-ItemProperty $key 'Default_Page_URL' "${mydocs}\estehrHome.html"

Set-ItemProperty $key 'Disable Script Debugger' 'no'
#Set-ItemProperty $key 'Cache_Update_Frequency' ''
#Set-ItemProperty $key 'Search Page' ''
Set-ItemProperty $key 'Play_Background_Sounds' 'no'

#IE9: disable Pinned Sites and allow regular drag of shortcut from address bar icon
# from http://www.sevenforums.com/tutorials/151853-internet-explorer-9-enable-disable-ability-pin-sites.html
if (!(test-path 'HKCU:\Software\Policies\Microsoft\Internet Explorer\Main')) {
	if (!(test-path 'HKCU:\Software\Policies\Microsoft\Internet Explorer')) {
		[void](new-item 'HKCU:\Software\Policies\Microsoft\Internet Explorer')
	}
	[void](new-item 'HKCU:\Software\Policies\Microsoft\Internet Explorer\Main')
}
[void](new-itemproperty -path 'HKCU:\Software\Policies\Microsoft\Internet Explorer\Main' -Name DisableAddSiteMode -PropertyType DWORD -Value 1 -force)


# reset default window size to fullscreen 1024x768 (IE8) on 1920x1080 monitor
# manually: bring up 1st IE window; from arbitrary link, Open in New Window; _manually_ resize/move second; close first; Ctrl-Close second
$winplace = (gp $key Window_Placement).Window_Placement
$winplace[28]=[Byte]231; $winplace[29]=[Byte]2 # Window left, little endian
$winplace[32]=[Byte]189; $winplace[33]=[Byte]0 # window top
$winplace[36]=[Byte]241; $winplace[37]=[Byte]6 # Window right
$winplace[40]=[Byte]203; $winplace[41]=[Byte]3 # Window bottom
sp $key Window_Placement -value $winplace