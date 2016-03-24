#Get-SpecialPaths.ps1
#http://www.vistax64.com/powershell/19524-need-quick-way-get-my-documents-folder.html #2006/09/28
Param([switch]$AsDrive)
# Utility program for working with the
# Returns a hash containing the CSIDL values found in shlobj.h
# Based on 2005-04-14 version from Platform SDK.
# Names modified as follows:
# Initial CSIDL_ removed for compactness;
# Embedded underscores removed as well.
# Names were slightly recased for readability.
# The concept is that if you "know" the name as a programmer,
# you will probably be able to guess the name used here.
# If you're an end-user, the name will look a lot like the expected
# English display name, but with no spaces.

# NOTE - although this is roughly similar to using
# [System.Environment]::GetSpecialFolder($value),
# it works for all implemented CSIDL values, not just the ones
# defined in the System.Environment+SpecialFolder enumeration.

# STEP 1: Define a hash for the paths.
# This can be extended as appropriate for items added to shell32.

$csidl = @{
"Programs" = 0x0002; # Start Menu\Programs
"Personal" = 0x0005; # My Documents
"Favorites" = 0x0006; # <user>\Favorites
"Startup" = 0x0007; # Start Menu\Programs\Startup
"Recent" = 0x0008; # <user>\Recent
"Sendto" = 0x0009; # <user>\SendTo

# Technically, "DesktopDirectory" - <user>\Desktop
"Desktop" = 0x0010;
"StartMenu" = 0x000b; # <user>\Start Menu
"MyMusic" = 0x000d; # "My Music" folder
"MyVideo" = 0x000e; # "My Videos" folder
"Nethood" = 0x0013; # <user>\nethood
"Fonts" = 0x0014; # windows\fonts
"Templates" = 0x0015;
"CommonStartMenu" = 0x0016; # All Users\Start Menu
"CommonPrograms" = 0X0017; # All Users\Start Menu\Programs
"CommonStartup" = 0x0018; # All Users\Startup
"CommonDesktop" = 0x0019; # All Users\Desktop
"Appdata" = 0x001a; # <user>\Application Data
"Printhood" = 0x001b; # <user>\PrintHood

# <user>\Local Settings\Application Data (non roaming)
"LocalAppdata" = 0x001c;
"AltStartup" = 0x001d; # non localized startup
"CommonAltStartup" = 0x001e; # non localized common startup
"CommonFavorites" = 0x001f;
"InternetCache" = 0x0020;
"Cookies" = 0x0021;
"History" = 0x0022;
"CommonAppdata" = 0x0023; # All Users\Application Data
"Windows" = 0x0024; # GetWindowsDirectory()
"System" = 0x0025; # GetSystemDirectory()
"ProgramFiles" = 0x0026; # C:\Program Files
"MyPictures" = 0x0027; # C:\Program Files\My Pictures
"Profile" = 0x0028; # USERPROFILE
"SystemX86" = 0x0029; # x86 system directory on RISC
"ProgramFilesX86" = 0x002a; # x86 C:\Program Files on RISC
"ProgramFilesCommon" = 0x002b; # C:\Program Files\Common
"ProgramFilesCommonx86" = 0x002c; # x86 Program Files\Common on RISC
"CommonTemplates" = 0x002d; # All Users\Templates
"CommonDocuments" = 0x002e; # All Users\Documents

# All Users\Start Menu\Programs\Administrative Tools
"CommonAdminTools" = 0x002f;
"AdminTools" = 0x0030; # <user>\Start Menu\Programs\Administrative Tools
"CommonMusic" = 0x0035; # All Users\My Music
"CommonPictures" = 0x0036; # All Users\My Pictures
"CommonVideo" = 0x0037; # All Users\My Video
"Resources" = 0x0038; # Resource Directory
"ResourcesLocalized" = 0x0039; # Localized Resource Directory
"CommonOemLinks" = 0x003a; # Links to All Users OEM specific apps

# default is $LocalAppdata\Microsoft\CD Burning
"CdburnArea" = 0x003b;
}

### The following were NOT used since they are not real paths.
# "Desktop" = 0x0000; # <desktop> - this is not technicall
# # the physical folder, although it does have a path.
#"Internet" = 0x0001; # Internet Explorer (icon on desktop)
#"Controls" = 0x0003; # My Computer\Control Panel
#"Printers" = 0x0004; # My Computer\Printers
#"Bitbucket" = 0x000a; # <desktop>\Recycle Bin
#"MyDocuments" = 0x000c; # logical "My Documents" desktop icon
#"Drives" = 0x0011; # My Computer
#"Network" = 0x0012; # Network Neighborhood (My Network Places)
#"Connections" = 0x0031; # Network and Dial-up Connections
# Computers Near Me (from Workgroup membership)
#"ComputersNearMe" = 0x003d;





#Step 2: Set up Shell.Application COM object.
$sa = New-Object -ComObject Shell.Application



#Step 3: Set up hash for paths, collect with "names"
$sp = @{} # Special Paths
foreach($key in $csidl.keys)
{
$sp[$key] = $sa.NameSpace($csidl[$key]).Self.Path;
}


# Map global drives using names from the hash
if($AsDrive)
{
$keys = $sp.Keys;
$keys | %{
$p = $sp[$_];
if($p.Length -gt 0)
{
$n = $csidl[$_] # numeric to help ID the drive...
New-PSDrive -Name:$_ -PSProvider:FileSystem -Root:$p `
-Scope Global -Description:"SpecialFolder$n"
}
}
}else{
return $sp;
}

