$env:VSINSTALLDIR='C:\Program Files\Microsoft Visual Studio 8'
$env:VCINSTALLDIR='C:\Program Files\Microsoft Visual Studio 8\VC'
$env:FrameworkDir='C:\WINDOWS\Microsoft.NET\Framework'
$env:FrameworkVersion='v2.0.50727'
$env:FrameworkSDKDir='C:\Program Files\Microsoft Visual Studio 8\SDK\v2.0'
if ($env:VSINSTALLDIR -eq "") { echo "ERROR: VSINSTALLDIR variable is not set." ; exit }
if ($env:VCINSTALLDIR -eq "") { echo "ERROR: VCINSTALLDIR variable is not set." ; exit }

echo "Setting environment for using Microsoft Visual Studio 2005 x86 tools."

#
# Root of Visual Studio IDE installed files.
#
$env:DevEnvDir='C:\Program Files\Microsoft Visual Studio 8\Common7\IDE'

$env:PATH="C:\Program Files\Microsoft Visual Studio 8\Common7\IDE;C:\Program Files\Microsoft Visual Studio 8\VC\BIN;C:\Program Files\Microsoft Visual Studio 8\Common7\Tools;C:\Program Files\Microsoft Visual Studio 8\Common7\Tools\bin;C:\Program Files\Microsoft Visual Studio 8\VC\PlatformSDK\bin;C:\Program Files\Microsoft Visual Studio 8\SDK\v2.0\bin;C:\WINDOWS\Microsoft.NET\Framework\v2.0.50727;C:\Program Files\Microsoft Visual Studio 8\VC\VCPackages;"+$env:PATH
$env:INCLUDE="C:\Program Files\Microsoft Visual Studio 8\VC\ATLMFC\INCLUDE;C:\Program Files\Microsoft Visual Studio 8\VC\INCLUDE;C:\Program Files\Microsoft Visual Studio 8\VC\PlatformSDK\include;C:\Program Files\Microsoft Visual Studio 8\SDK\v2.0\include;"+$env:INCLUDE
$env:LIB="C:\Program Files\Microsoft Visual Studio 8\VC\ATLMFC\LIB;C:\Program Files\Microsoft Visual Studio 8\VC\LIB;C:\Program Files\Microsoft Visual Studio 8\VC\PlatformSDK\lib;C:\Program Files\Microsoft Visual Studio 8\SDK\v2.0\lib;"+$env:LIB
$env:LIBPATH="C:\WINDOWS\Microsoft.NET\Framework\v2.0.50727;C:\Program Files\Microsoft Visual Studio 8\VC\ATLMFC\LIB"
