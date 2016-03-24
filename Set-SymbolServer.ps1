###############################################################################
# Set-SymbolServer - Sets up the current user account to use a symbol server.
#
# Copyright (c) 2008 - John Robbins (john@wintellect.com) 
#
# Version 1.0 - Jan 22, 2008 
###############################################################################
param ( [switch] $Internal ,
        [switch] $Public ,
        [switch] $Vs2005 ,
        [string] $CacheDirectory ,
        [string[]] $SymbolServers ,
        [switch] $Verbose , 
        [switch] $Confirm , 
        [switch] $Whatif )

# Always make sure all variables are defined.
Set-PSDebug -Strict 

# The reference variable used to determine if the user pressed Y/A.
$script:AllAnswer = $null

function Usage 
{
    ""
    "Usage: Set-SymbolServer [-Internal] [-Public] [-Vs2005]"
    " [[-CacheDirectory] <string>]" 
    " [[-SymbolServers] <string array>]" 
    " [-Verbose] [-Confirm] [-WhatIf]"
    ""
    "Parameters:"
    " -Internal       : Set up for using an internal symbol server"
    "             (file://symbols/symbols)"
    " -Public         : Use the public Microsoft symbol servers."
    " -Vs2005         : Set the symbol server settings for Visual Studio 2005"
    "                   instead of the default Visual Studio 2008."
    " -CacheDirectory : Use the specified download cache directory instead of the"
    "                   default (internal: c:\symbols\internalsymbols,"
    "                   public: c:\symbols\ossymbols)."
    " -SymbolServers  : Additional symbol servers to add to the defaults."
    " -?              : Display this usage information"
    ""
    " Note that either -Public or -Internal must be specified"
    ""
    exit
}

# A modified version of Jeffrey Snover's Should-Process script.
# http://blogs.msdn.com/powershell/archive/2007/02/25/supporting-whatif-confirm-verbose-in-scripts.aspx
function Should-Process ( $Operation , 
                          $Target ,
                          [REF]$AllAnswer ,
                          $Warning = "" )
{
    if ($AllAnswer.Value -eq $FALSE)
    { 
        return $FALSE
    }
    elseif ($AllAnswer.Value -eq $TRUE)
    { 
        return $TRUE
    }
    if ($Whatif)
    { 
        Write-Host "What if: Performing operation `"$Operation`" on Target `"$Target`""
        return $FALSE
    }
    if ($Confirm)
    {
        $ConfirmText = @"
Confirm Are you sure you want to perform this action?
Performing operation "$Operation" on Target "$Target". $Warning
"@
        Write-Host $ConfirmText
        while ($TRUE)
        {
            $answer = Read-Host @"
[Y] Yes [A] Yes to All [N] No [L] No to all [S] Suspend [?] Help (default is "Y")
"@
            switch ($Answer)
            {
                "Y" { return $TRUE}
                "" { return $TRUE}
                "A" { $AllAnswer.Value = $TRUE; return $TRUE }
                "N" { return $FALSE }
                "L" { $AllAnswer.Value = $FALSE; return $FALSE }
                "S" { $Host.EnterNestedPrompt(); 
                      Write-Host                 $ConfirmText }
                "?" { Write-Host @"
Y - Continue with only the next step of the operation.
A - Continue with all the steps of the operation.
N - Skip this operation and proceed with the next operation.
L - Skip this operation and all subsequent operations.
S - Pause the current pipeline and return to the command prompt. Type "exit" to resume the pipeline.
"@
                    }
                }
            }
    }
    if ($verbose)
    {
        Write-Verbose "Performing `"$Operation`" on Target `"$Target`"."
    }
    return $TRUE
}

function Set-ItemPropertyScript ( $path , $name , $value )
{
    $propString = "Item: " + $path.ToString() + "Property: " + $name
    if ( Should-Process "Set Property" $propString ([REF]$AllAnswer) )
    {
        Set-ItemProperty -Path $path -Name $name -Value $value
    }
}

function Set-ItemPropertyTypeScript ( $path , $name , $value , $type )
{
    $propString = "Item: " + $path.ToString() + "Property: " + $name
    if ( Should-Process "Set Property" $propString ([REF]$AllAnswer) )
    {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
    }
}

# Creates the cache directory if it does not exist.
function CreateCacheDirectory ( [string] $cacheDirectory )
{
    if ( ! $(Test-path $cacheDirectory -type "Container" ))
    {
        if ( Should-Process "New-Item" $cacheDirectory ([REF]$AllAnswer) )
        {
            New-Item -type directory -Path $cacheDirectory > $null
        }
    }
}

function WriteSymbolEnvironment ( [string] $envValue )
{
    Set-ItemPropertyScript hkcu:\Environment _NT_SYMBOL_PATH $envValue
}

function SetSymbolServer ( )
{
    # Set the defaults. Assuming VS2008 and public symbol servers.
    $realCacheDir = "c:\Symbols\OSSymbols"
    # This function assumes $symServers is an array.
    $symServers = "http://referencesource.microsoft.com/symbols","http://msdl.microsoft.com/download/symbols"

    # Am I doing this for VS 2005?
    if ( $Vs2005 )
    {
        $symServers = , "http://msdl.microsoft.com/download/symbols"
    }
    # Am I supposed to do an internal company symbol server?
    if ( $Internal )
    {
        $realCacheDir = "c:\Symbols\InternalSymbols"
        $symServers = , "\\symbols\symbols"
    }
    # If the user specified a cache directory, that takes precedence over all.

    if ( $CacheDirectory.Length -gt 0 )
    {
        $realCacheDir = $CacheDirectory
    }
    # Add on any additional symbol servers the user set.
    if ( $SymbolServers.Length -gt 0 )
    {
        $symServers += $SymbolServers 
    }

    Write-Debug "SSSfn: realCacheDir = $realCacheDir"
    Write-Debug "SSSfn: symServers = $symServers"

    CreateCacheDirectory ( $realCacheDir )

    # Prepare and set the user's _NT_SYMBOL_PATH environment variable.
    $envValue = "SRV*" + $realCacheDir + "*" + [string]::Join('*' , $symServers)
    Write-Debug "SSSfn: envValue = $envValue"
    WriteSymbolEnvironment ( $envValue )

    # The debugger's registry key
    $verNumber = $( if ( $Vs2005 ) { "8" } else { "9" } )
    $dbgRegKey = "HKCU:\Software\Microsoft\VisualStudio\{0}.0\Debugger" -f $verNumber
    Write-Debug "SSSfn: RegKey = $dbgRegKey"

    $symsrvString = $( if ( $Public ) { "the public Microsoft" } else { "an internal" } )

    # Look to see if the registry key exists. If it does not, VS is not installed.
    if ( $( Test-Path $dbgRegKey ) )
    {

        # Write the registry keys common between VS 2005 and VS 2008.
        # First, do the SymbolPath values.
        $symPathValue = [string]::Join(";" , $symServers)
        Write-Debug "SSSfn: SymbolPath = $symPathValue"
        Set-ItemPropertyScript $dbgRegKey SymbolPath $symPathValue
        # Second, enable those symbol paths. This will show them as checked
        # in the Options dialog, Debugger, Symbols page.
        # Gotta deal with the typelessness of PowerShell.
        $pathStateValue = ""
        for ( $i = 0 ; $i -lt $symServers.Length ; $i++ )
        {
            $pathStateValue += "1" 
        }
        Write-Debug "SSSfn: SymbolPathState = $pathStateValue" 
        Set-ItemPropertyScript $dbgRegKey SymbolPathState $pathStateValue
        # Finally, set the cache directory.
        Write-Debug "SSSfn: SymbolCacheDir = $realCacheDir"
        Set-ItemPropertyScript $dbgRegKey SymbolCacheDir $realCacheDir

        # If we're doing the public symbol server and VS 2008, enable
        # source server support and turn off Just My Code.
        if ( ( ! $Vs2005 ) -and ( ! $Internal ) )
        {
            Write-Debug "SSSfn: VS08 JustMyCode = 0"
            Set-ItemPropertyTypeScript $dbgRegKey JustMyCode 0 DWORD
            Write-Debug "SSSfn: VS08 UseSourceServer = 1"
            Set-ItemPropertyTypeScript $dbgRegKey UseSourceServer 1 DWORD
        }

        ""
        "Updated Visual Studio 200{0} to use {1} symbol server(s)." -f 
                $( if ( $Vs2005 ) { "5" } else { "8" } ) , 
                $symsrvString
    }
    "Added the current user _NT_SYMBOL_PATH environment variable to use"
    "{0} symbol server(s)." -f $symsrvString
    ""
    "Please log out to activate the new symbol server settings."
    ""
}

# Check for the help request.
if ( ( $Args -eq '-?') -or ( ( ! $Internal ) -and ( ! $Public ) ) )
{
    Usage
}
if ( $Internal -and $Public )
{
    Throw "Only one of -Public or -Internal can be specified" 
}

Write-Debug "Param Internal = $Internal"
Write-Debug "Param Public = $Public"
Write-Debug "Param Vs2005 = $Vs2005"
Write-Debug "Param CacheDirectory = $CacheDirectory"
Write-Debug "Param SymbolServers = $SymbolServers"
Write-Debug "Param Verbose = $Verbose"
Write-Debug "Param Confirm = $Confirm"
Write-Debug "Param Whatif = $Whatif"

SetSymbolServer 


