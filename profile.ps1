function Add-PSSnapinConditionally ($name, [Switch]$quiet)
{
if (get-pssnapin -registered | ? {$_.Name -eq $name})
	{ add-pssnapin $name }
else
	{ if (!$quiet) { "$name snapin is not installed" } }
}
Add-PSSnapinConditionally 'PSCX'
Add-PSSnapinConditionally 'Microsoft.TeamFoundation.PowerShell' -quiet
Add-PSSnapinConditionally 'TfsBPAPowerShellSnapIn' -quiet
function Import-PSModuleConditionally ($name, [Switch]$quiet)
{
	if ((gcm get-module -ea silentlycontinue) -and (Get-Module -ListAvailable $name)) { 
		import-module $name
		if (!$quiet) { "$name module imported" }
	}
}
Import-PSModuleConditionally PSCX
#Import-PSModuleConditionally StudioShell

# 2010/09/19 http://keithhill.spaces.live.com/Blog/cns!5A8D2641E0963A97!7226.entry <http://rkeithhill.wordpress.com/2010/09/19/determining-scriptdir-safely/>
# #requires -Version 2.0
# Set-StrictMode -Version 2.0
$ScriptDirBlock = { Split-Path $MyInvocation.ScriptName -Parent }
#"PARENT:  Before dot-sourcing libary ScriptDir is $(&$ScriptDirBlock)"
# or from later comment 
function ScriptRoot { if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.ScriptName } }
# PSSCriptRoot in modules for PoSH 2.0, all for 3.0+


function prompt
{
	#Write-Host ("PS " + $(get-location) + ">") -nonewline -foregroundcolor gray -backgroundcolor black
	$private:color = $Host.UI.RawUI.ForegroundColor
	$private:bgcolor = $Host.UI.RawUI.BackgroundColor
	if (![ConsoleColor]::IsDefined([ConsoleColor], $bgcolor)) { $color = [ConsoleColor]::Black; $bgcolor=[ConsoleColor]::Gray } #ISE
	$private:nesting = new-object String ('>', $NestedPromptLevel)
	Write-Host ("PS " + $(get-location) + ">$nesting") -nonewline -foregroundcolor $bgcolor -backgroundcolor $color
	return " "
}

#[System.Reflection.Assembly]::Load("System.Web, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")
#[System.Reflection.Assembly]::LoadWithPartialName("System.Web")

#hacked from Microsoft.public.windows.powershell newsgroup postings 20060701
function LoadStdAsm {
	[System.Reflection.Assembly]::LoadFrom([System.IO.Path]::Combine(([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()), ($args[0] + '.dll')))
}

if (!([AppDomain]::CurrentDomain.GetAssemblies() | ? { $_.FullName.StartsWith("System.Web,") })) { # 2012/09/27 <http://richardspowershellblog.wordpress.com/2007/09/30/assemblies-loaded-in-powershell/>
	LoadStdAsm("System.Web") | ft ImageRuntimeVersion,Location -auto # 2005/12/26 server.scripting newsgroups: known bug, default output wrecks formatting later in the path, so we ft here
}
# 20080825 buffer access to the (Url|Html)Decode functions
function UrlDecode([string]$Url) { [System.Web.HTTPUtility]::UrlDecode($Url) }
function HtmlDecode([string]$Html) { [System.Web.HTTPUtility]::HtmlDecode($Html) }

# reset output encoding to UTF-8, may negatively affect .exe stdin # kills 'help', so commented out
# <http://blogs.msdn.com/powershell/archive/2006/12/11/outputencoding-to-the-rescue.aspx>
#$OutputEncoding = New-Object -typename System.Text.UTF8Encoding
#[console]::OutputEncoding = New-Object -typename System.Text.UTF8Encoding
#([System.Text.Encoding]::UTF8).GetString() or GetBytes()

# Change error reporting to include exception classes and inner exceptions
$ReportErrorShowExceptionClass = $True
$ReportErrorShowInnerException = $True
Get-ChildItem variable:*Preference | Sort-Object Name | ft -prop Name,Value

# snag the path to the profile, as opposed to the host-specific profile
$ProfilePath = split-path $profile
#$ProfilePath = (split-path -parent $script:MyInvocation.MyCommand.Path)
$15hive = 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15'
$14hive = 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\14'
$12hive = 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\12'
$6hive = 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\60'

# 2010/12/13
$env:path += ";$ProfilePath"
# 2012/10/28
if (Test-Path 'h:\users\erichs\Development\android\android-sdk-windows\platform-tools\') { $env:path += ';h:\users\erichs\Development\android\android-sdk-windows\platform-tools'}

# 2007/03/08: tweaked format to use "T" instead of "t" in file time stamps
if (test-path $profilePath\filesystem.format.ps1xml) { Update-FormatData -pre $profilePath\filesystem.format.ps1xml }
# 2011/08/07: reset Timespan default/table format to ToString
if (test-path $profilePath\Timespan.ps1xml) { Update-FormatData -pre $profilePath\Timespan.ps1xml }


# breakpoints from http://blogs.msdn.com/powershell/archive/2006/04/25/583233.aspx
# vs Set-PSDebug -Step
# tweaked to add location argument and write-host colors

function start-debug
{
   $scriptName = $MyInvocation.ScriptName
   $location = $(if ([String]::IsNullOrEmpty($args[0])) { "" } else { "/$($args[0])" } )
   function prompt
   {
      write-host ("Debugging [{0}]{1}>" -f $(if ([String]::IsNullOrEmpty($scriptName)) { "globalscope" } else { $scriptName } ),"$location") -nonewline -foregroundcolor gray -backgroundcolor black
      return " "
   }
   $host.EnterNestedPrompt()
}
set-alias bp start-debug

# from <a href="http://blogs.msdn.com/powershell/archive/2006/10/21/Power-and-Pith.aspx" title="Windows PowerShell">Power and Pith</a>
${function:...} = { process { $_.($args[0]) } }

#helper function for finding files in another directory 
# dir $path | ? {!(FileExistsIn $_ $pwd)} # shows files in $path not in $pwd
# filter FileExistsIn { (($args[0] -is [IO.FileInfo]) -and (([IO.FileInfo]($args[1].ToString()+'\'+($args[0].Name))).Exists)) }
filter FileExistsIn { test-path -literalPath (join-path $args[1] $args[0].Name) -pathType leaf }

# from news:microsoft.public.windows.powershell/<47E75AF0-A7D5-4D1C-BDCC-3368799A1BFC@microsoft.com>
function Resolve-Error ($ErrorRecord=$Error[0])
{
   $ErrorRecord | Format-List * -Force
   $ErrorRecord.InvocationInfo |Format-List *
   $Exception = $ErrorRecord.Exception
   for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
   {   "$i" * 80
       $Exception |Format-List * -Force
   }
}
Set-Alias rver Resolve-Error

# http://blogs.msdn.com/powershell/archive/2006/12/29/dyi-ternary-operator.aspx
if (!(Get-Command -CommandType Alias ?:)) { # conditional to prevent error when PSCX already loaded
filter Invoke-Ternary ($Predicate, $Then, $Otherwise = $null)
{
	if($predicate -is [scriptblock]) { $predicate = &$predicate }
	if ($predicate) { 
		if($then -is [ScriptBlock]) { &$then }
		else { $then }
	} elseif($otherwise) { 
		if($otherwise -is [ScriptBlock]) { &$otherwise }
		else { $otherwise }
	}
}
filter Invoke-Coalescence($predicate, $alternative) {
	if($predicate -is [scriptblock]) { $predicate = &$predicate }
	Invoke-Ternary $predicate $predicate $alternative
}
set-alias ?: Invoke-Ternary -Option AllScope
set-alias ?? Invoke-Coalescence -Option AllScope
}

# From 2006/12/07 news://microsoft.public.windows.powershell/OgyoaxkGHHA.3780@TK2MSFTNGP02.phx.gbl
# Tweaked 2007/03/17 to add hashClassname parameter
# Tweaked 2015/04/30 to fix UNC IO.FileInfo creation
function Get-Hash
{
	param(
	     [string]$path,
	     [string]$format="X2",
	     [string]$hashClassname="System.Security.Cryptography.MD5")
	begin
	{
	     if (!$hashClassname.Contains(".")) { $hashClassname = "System.Security.Cryptography." + $hashClassname }
	     $hashAlgorithm = invoke-expression "[$hashClassname]::Create()"
	
	     function ProcessObject($object)
	     {
	         if($object -is [IO.FileInfo])
	         {
	             ProcessFile $object.FullName
	         }
	         elseif($object -is [IO.DirectoryInfo])
	         {
	             # skip directories...
	         }
	         elseif($object -and $object.Path)
	         {
	             ProcessFile $object.Path
	         }
	         elseif($object)
	         {
	            ProcessFile $object
	         }
	     }
	     function ProcessFile([string]$filesToProcess)
	     {
	         foreach($pathInfo in (resolve-path $filesToProcess))
	         {
	             $stream = $null;
	             trap
	             {
	                 ## We have to be sure that we close the file stream
	                 ## if any exceptions are thrown.
	                 if ($stream -ne $null)
	                 {
	                     $stream.Close();
	                 }
	             }
	
	             $file= (dir $pathInfo.Path) -as [IO.FileInfo]
	
	             $stream = $file.OpenRead();
	             $hashByteArray = $hashAlgorithm.ComputeHash($stream);
	             $stream.Close();
	
	             $result=1 | Select Text, Bytes, Path
	             $result.Text=[String]::Join("", ($hashByteArray | %{ "{0:$format}" -f $_ }) )
	             $result.Bytes=$hashByteArray
	             $result.Path=$file.FullName
	
	             $result
	          }
	     }
	}
	process
	{
	     ProcessObject $_
	}
	end
	{
	     ProcessObject $path
	}
}
# 2007/01/05: http://keithhill.spaces.live.com/Blog/cns!5A8D2641E0963A97!675.entry
if (!(Get-Command -CommandType Alias gtn -ea SilentlyContinue)) { # conditional to prevent error when PSCX already loaded
set-alias gtn Get-TypeName
function Get-TypeName([switch]$FullName=$false) {
    begin {
       $processedInput = $false
       function WriteTypeName($obj) {
            if ($obj -eq $null) {
                "<null>"
            }
            else {
                $typeName = $obj.PSObject.TypeNames[0]
                if ($fullName) {
                    $typeName
                }
                else {
                    $ndx = $typeName.LastIndexOf('.')
                    if (($ndx -ne -1) -and ($ndx -lt $typeName.length)) {
                        $typeName.Substring($ndx+1)
                    }
                    else {
                        $typeName
                    }
                }
            }
        }
    }

    process {
        if ($args.count -eq 0) {
            WriteTypeName $_
            $processedInput = $true
        }
    } 

    end {
        foreach ($arg in $args) {
            WriteTypeName $arg
        }
        if (!$processedInput -and ($args.Count -eq 0)) {
            Write-Warning 'Get-TypeName did not receive any input. The input may be an empty collection. You can either prepend the collection expression with the comma operator e.g. ",$collection | gtn" or you can pass the variable or expression to Get-TypeName as an argument e.g. "gtn $collection".'
        }
    }
}
}

# 2007/01/23 From http://thepowershellguy.com/blogs/posh/archive/2007/01/23/powershell-converting-accountname-to-sid-and-vice-versa.aspx
function ConvertTo-NtAccount ($sid) {(new-object system.security.principal.securityidentifier($sid)).translate([system.security.principal.ntaccount])}

function ConvertTo-Sid ($NtAccount) {(new-object system.security.principal.NtAccount($NTaccount)).translate([system.security.principal.securityidentifier])}

# 2010/11/05 - dir filter
filter TodaysWrites { if ($_.LastWriteTime -ge [DateTime]::Today) {$_} }
#filter TodaysWrites { $_ | ? {$_.LastWriteTime -ge [DateTime]::Today} } #2014/10/08
# 2011/10/15
function SortTime() { $input | sort LastWriteTime }
# 2011/01/03 - dir filter
filter WrittenDuringLastSpan([TimeSpan] $span="1.00:00:00") { if ($_.LastWriteTime -ge [DateTime]::Now.Subtract($span)) {$_} }
# 2007/09/28
filter Copy-FilesNotPresent ($dest=$(throw "Must have destination"), [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false) { if ((!$_.PSIsContainer) -and (!(FileExistsIn $_ $dest))) { copy -literalpath $_.Fullname -dest $dest -pass -verbose:$Verbose -whatif:$WhatIf -confirm:$confirm } }
filter Hardlink-FilesNotPresent ($dest) { if ((!$_.PSIsContainer) -and (!(FileExistsIn $_ $dest))) { New-Hardlink "$dest\$($_.Name)" $_.Fullname } }
# 2014/05/03
filter AfterLastDestination ($dest=$(throw "Must have destination"), [switch] $Verbose=$false) {
begin {$lastts = (dir $dest | sort LastWriteTime | select -Last 1).LastWriteTime}
process { $_ | Where-Object {$_.LastWriteTime -gt $lastts} }
}
# 2007/02/19, 2008/05/06, 2011/11/23
function Import-CFToHome ([TimeSpan] $span="1.00:00:00", [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false) { dir R:\pickup\TekSystems\MSFT201408 | WrittenDuringLastSpan -span $span | sorttime | copy -pass -dest H:\users\erichs\Career\TekSystems\MSFT201408 -verbose:$verbose -whatif:$WhatIf -confirm:$confirm }
#function Export-WorkToCF () { dir $env:userprofile\Desktop | ? {!$_.PSIsContainer} | ? {!(FileExistsIn $_ E:\pickup\Excell)} | copy -dest E:\pickup\Excell -confirm }
function Export-WorkToCF([TimeSpan] $span="1.00:00:00", [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false) { dir "$env:userprofile\Documents\OneDrive - Microsoft\Notes", "$env:userprofile\Downloads", "$env:userprofile\Documents", "$env:userprofile" | SortTime | Copy-WorkDuringLastSpan -span $span -verbose:$verbose -whatif:$WhatIf -confirm:$confirm }
# 2011/10/07
filter Copy-DuringLastSpan($dest, [TimeSpan] $span="1.00:00:00", [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false) { $_ | ? {!($_.PSIsContainer)} | WrittenDuringLastSpan -span $span | copy -pass -dest $dest -verbose:$verbose -whatif:$WhatIf -confirm:$confirm }
filter Copy-WorkDuringLastSpan([TimeSpan] $span="1.00:00:00", [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false) { $_ | Copy-DuringLastSpan -dest R:\pickup\TekSystems\MSFT201408 -span $span -verbose:$verbose -whatif:$WhatIf -confirm:$confirm }
# 2015/02/06
function last ([int]$count=10, [Object[]]$Property=@("LastWriteTime")) { $input | sort -Property $Property | select -l $count }
# 2015/03/17
function yesterday([int]$days=1) { return [DateTime]::Today.AddDays(-$days) }
# 2015/03/17 from http://stackoverflow.com/questions/6072974/modify-xml-while-preserving-whitespace
function ReadAllText($path) { [System.IO.File]::ReadAllText($path) } # since gc returns array of lines not text

# http://blogs.msdn.com/powershell/comments/1779203.aspx 2007/03/01
function ql {$args} # turn the list of arguments into a lookup array # ql Pig Rat Ox Tiger Rabbit Dragon Snake Horse Goat Monkey Rooster Dog

# 2007/03/06 suggested by <FB94C3D3-7396-4EB6-AADC-FD3A755C1B89@microsoft.com> in microsoft.public.windows.powershell on Fri, 23 Feb 2007 20:29:53 -0700
function echoargs { for ($i = 0; $i -lt $args.count; ++$i) { write-host "$($i):: $($args[$i])"}}

# 2007/03/08 from (re)pointer to iisapp.vbs for finding application pool ids
# 2011/07/18 suffix question mark is lazy quantifier for non-greedy matches
function Get-IisAppPoolIds( [string] $machineName="." )
{ 
	get-wmiobject -class "Win32_Process" -namespace "root\cimv2" -computername $machineName -filter "Name='w3wp.exe'" | 
	select Name,ProcessId,@{n='AppPool';e={if ($_.CommandLine -match '-ap "(.*?)"') {$Matches.Item(1)} else {$null}} }
}

# 2007/05/15 from http://blogs.msdn.com/richardb/archive/2007/02/21/add-types-ps1-poor-man-s-using-for-powershell.aspx
# filterized (one-at-a-time instead of $input) and renamed parameter
# usage: $tfs = new-object Management.Automation.PsObject; $tfs | add-types "Microsoft.TeamFoundation.VersionControl.Client" ; $itemSpec = new-object $tfs.itemspec("$/foo", $tfs.RecursionType::none) 
# instead of  $itemSpec = new-object Microsoft.TeamFoundation.VersionControl.Client.ItemSpec ("$/foo", [Microsoft.TeamFoundation.VersionControl.Client.RecursionType]::None)
filter add-types (
	[string] $assemblyName = $(throw 'assemblyName is required'),
	[object] $inputobject
)
{
	if ($_) {
		$inputobject = $_
	}

	if (! $inputobject) {
		throw 'must pass an -inputobject or pipe one in'
	}

	# load the required dll
	$assembly = [System.Reflection.Assembly]::LoadWithPartialName($assemblyName)

	# add each type as a member property
	$assembly.GetTypes() |
 	where {$_.ispublic -and !$_.IsSubclassOf( [Exception] ) -and $_.name -notmatch "event"} |
 	foreach {
 		# avoid error messages in case it already exists
		if (! ($inputobject  | get-member $_.name)) {
			add-member noteproperty $_.name $_ -inputobject $inputobject 
		}
	}
}

# 20070523 TrimBOM - converts file to LE Unicode without byte order mark (for Sansa .plp playlists)
function TrimBOM ([string]$filepath) { ,(gc $filepath) | % { [Text.Encoding]::Unicode.GetBytes([string]::join("`r`n", $_)+"`r`n") } | set-content $filepath -encoding byte }

function Set-ContentTrimBOM ($path=(throw "Must have -path!"), $value) {
	if ($null -eq $value) { $value = @($input) }
	[Text.Encoding]::Unicode.GetBytes([string]::join("`r`n", $value)+"`r`n") | 
	set-content $path -encoding byte
}

# http://blogs.msdn.com/powershell/archive/2007/05/29/using-powershell-to-generate-xml-documents.aspx
# Example: gps a* | New-XML -RootTag PROCESSES -ItemTag PROCESS -Attribute=id,ProcessName -ChildItems WS,Handles
function New-Xml
{
param($RootTag="ROOT",$ItemTag="ITEM", $ChildItems="*", $Attributes=$Null)

Begin {
	$xml = "<$RootTag>`n"
}

Process {
	$xml += " <$ItemTag"
	if ($Attributes)
	{
		foreach ($attr in $_ | Get-Member -type *Property $attributes)
		{
			$name = $attr.Name
			$xml += " $Name=`"$($_.$Name)`""
		}
	}
	$xml += ">`n"
	foreach ($child in $_ | Get-Member -Type *Property $childItems)
	{
		$Name = $child.Name
		$xml += " <$Name>$($_.$Name)</$Name>`n"
	}
	$xml += " </$ItemTag>`n"
}

End {
	$xml += "</$RootTag>`n"
	$xml
}
} 

# http://jtruher.spaces.live.com/Blog/cns!7143DA6E51A2628D!172.entry 2007/07/15 "Tracing the script stack"
# include     trap { write-error $_; get-stacktrace }	in each function to display the trace

function get-stacktrace
{
    trap { continue }
    1..100 | %{
        $inv = &{ gv -sc $_ myinvocation } 2>$null
        if ($inv) { write-host -for blue $inv.value.positionmessage.replace("`n","") }
        }
    exit
}

# 2008/05/09: needed to properly decode from pre-utf8'ed french language string  
# function FixUTF8([string] $s) { $str = new-object IO.MemoryStream ($s.length); $s.ToCharArray() | % { $str.WriteByte([byte]$_) } ; [Text.Encoding]::UTF8.GetString($str.GetBuffer()) }
# 2008/05/13
function FixUTF8([string] $s) { $str = new-object IO.MemoryStream ($s.length); $tw = new-object IO.StreamWriter ($str, [Text.Encoding]::GetEncoding(1252)); $tw.Write($s); $tw.Close(); [Text.Encoding]::UTF8.GetString($str.GetBuffer()) }
# FixUTF8 'â€™' # closing smart single-quote U+2019 '’'

# http://blogs.msdn.com/powershell/archive/2008/09/01/get-constructor-fun.aspx
# includes s/ParameterType.Name/ParameterType.FullName/ suggested in comment
function get-Constructor ([type]$type)
{
    foreach ($c in $type.GetConstructors())
    {
        $type.Name + "("
        foreach ($p in $c.GetParameters())
        {
            "`t{0} {1}," -f $p.ParameterType.FullName, $p.Name 
        }
        ")"
    }
}
# get-Constructor System.Windows.Thickness # if loaded
# get-Constructor System.Datetime

# http://devhawk.net/2008/11/08/My+ElevateProcess+Script.aspx
# Vista UAC process elevation
function elevate-process  
{  
  $psi = new-object System.Diagnostics.ProcessStartInfo 
  $psi.Verb = "runas"; 

  #if we pass no parameters, then launch PowerShell in the current location
  if ($args.length -eq 0) 
  { 
    $psi.FileName = 'powershell'
    $psi.Arguments =  
      "-NoExit -Command &{set-location '" + (get-location).Path + "'}"
  } 

  #if we pass in a folder location, then launch powershell in that location
  elseif (($args.Length -eq 1) -and  
          (test-path $args[0] -pathType Container)) 
  { 
    $psi.FileName = 'powershell'
    $psi.Arguments =  
        "-NoExit -Command &{set-location '" + (resolve-path $args[0]) + "'}"
  } 

  #otherwise, launch the application specified in the arguments
  else
  { 
    $file, [string]$arguments = $args; 
    $psi.FileName = $file   
    $psi.Arguments = $arguments
  } 
     
  [System.Diagnostics.Process]::Start($psi) | out-null
} 

# http://blogs.msdn.com/powershell/archive/2008/11/23/convertto-hashtable-ps1-part-2.aspx
# converts "$ht = @{}; foreach ($foo in $bar){ $ht.add($foo.prop, (proc $foo)}"
#   into "$ht = $bar | ConvertTo-HashTable prop {proc $foo}"
#	or "$htFoo,$htQuux = $bar | convertTo-HashTable prop {proc $foo},quux
# 2011/07/21: $htUsedSpace,$htFreeSpace = gwmi Win32_logicalDisk -Filter "Size > 0" | ConvertTo-HashTable DeviceId {$_.size - $_.freeSpace}, FreeSpace

function ConvertTo-HashTable
{
param( [string]  $key, $value ) 
Begin 
{ 
    $hashTables  = @()
    foreach ($v in @($value))
    {
      $hashTables += @{} 
    }
} 
Process 
{ 
    $thisKey = $_.$Key
    for ($i = 0 ; $i -lt $hashTables.Count; $i++)
    {
        $hash = $hashTables[$i]
        if (@($Value)[$i] -is [ScriptBlock])
        {
            $hash.$thisKey = & @($Value)[$i]
        }
        else
        {
            $hash.$thisKey = $_.$(@($Value)[$i]) 
        }
    }
} 
End 
{ 
    foreach ($hash in $hashtables)
    {
        Write-Output $hash 
    }
}

}

# http://www.tavaresstudios.com/Blog/post/The-last-vsvars32ps1-Ill-ever-need.aspx 20080114
# reset for VS2008 default
# Get-BatchFile swiped from Windows Powershell in Action
function Get-Batchfile ($file) {
    $cmd = "`"$file`" & set"
    cmd /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}
function VsVars32($version = "9.0")
{
    $key = "HKLM:SOFTWARE\Microsoft\VisualStudio\" + $version
    $VsKey = get-ItemProperty $key
    $VsInstallPath = [System.IO.Path]::GetDirectoryName($VsKey.InstallDir)
    $VsToolsDir = [System.IO.Path]::GetDirectoryName($VsInstallPath)
    $VsToolsDir = [System.IO.Path]::Combine($VsToolsDir, "Tools")
    $BatchFile = [System.IO.Path]::Combine($VsToolsDir, "vsvars32.bat")
    Get-Batchfile $BatchFile
    [System.Console]::Title = "Visual Studio " + $version + " Windows Powershell"
}

# was from http://devhawk.net/2008/12/17/PowerShell+Findtosetalias.aspx
# better at http://bradwilson.typepad.com/blog/2008/12/find-to-set-aliasps1.html
function find-to-set-alias($foldersearch = $(throw "folder*s to search required"),
    $filename = $(throw "filename required"),
    $alias = $(throw "alias required"),
    [switch]$quiet
) 
{ 
	if ((test-path $foldersearch) -eq $false) {
	    if ($quiet -eq $false) { write-warning ("Could not find any paths to match " + $foldersearch) }
	    return #exit
	}
	
	# If the user specified a wildcard, turn the foldersearch into an array of matching items
	# We don't always want to do this, because specifying a non-wildcard directory gives false positives
	
	if ($foldersearch.contains('*') -or $foldersearch.contains('?')) {
	    $foldersearch = Get-ChildItem $foldersearch -ErrorAction SilentlyContinue
	}
	
	$files = @($foldersearch | %{ Get-ChildItem $_ -Recurse -Filter $filename -ErrorAction SilentlyContinue })
	
	if ($files.count -eq 0) {
	    if ($quiet -eq $false) {
	        write-warning ("Could not find " + $filename + " in searched paths:")
	        $foldersearch | %{ write-warning ("  " + $_) }
	    }
	    return #exit
	}

	if ($files.Count) {set-alias $alias $files[0].FullName -scope Global} else {if (-not $quiet) {write-warning "No file found for alias '$alias'"}}
	
	if ($quiet -eq $false) {
	    write-host ("Added alias " + $alias + " for " + $files[0].FullName)
	    if ($files.count -gt 1) {
	        write-warning ("There were " + $files.count + " matches:")
	        $files | %{ write-warning ("  " + $_.FullName) }
	    }
	}
} 
#find-to-set-alias 'c:\program files*\Microsoft Visual Studio 9.0\Common7' devenv.exe vs 
## 20100526 use Windows SDK registry settings to locate windiff.exe
$SdkRegPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft SDKs\Windows'
if (Test-Path $SdkRegPath) { # 2013/05/19 is it even there? don't look if not
	$SdkFilePath = ((gp $SdkRegPath CurrentInstallFolder -ErrorAction SilentlyContinue).CurrentInstallFolder) # 2012/10/28: -ea SilentlyContiue
}
if (test-path "$SdkFilePath\bin\WinDiff.Exe") {new-alias windiff "$SdkFilePath\bin\WinDiff.Exe"} else {find-to-set-alias "${env:ProgramFiles}\Microsoft Visual Studio*" windiff.exe windiff -quiet}
#find-to-set-alias "${env:ProgramFiles}\Microsoft Visual Studio 9.0\Common7" tf.exe tf -quiet # pull this back out on a TFS installation


# From http://www.wintellect.com/CS/blogs/jrobbins/archive/2008/12/31/powershell-one-year-later.aspx
function Get-FullPath ( [string] $fileName ) 
{ 
    # The easy case is if it exists. Just call Resolve-Path. 
    if ( Test-Path $fileName ) 
    { 
        return $(Resolve-Path $fileName) 
    } 
    else 
    { 
        # The file doesn't exist. 
        # Look to see if the caller has passed in a drive letter. 
        $rootPath = [System.IO.Path]::GetPathRoot($fileName) 
        if ( $rootPath -ne "" ) 
        { 
            # Return what the user passed in. 
            return ( $rootPath ) 
        } 
        # There's no drive letter so make it relative from the current location. 
        $fullName = [system.IO.Path]::Combine($(Get-Location) , $fileName) 
        return ( $fullName ) 
    } 
} 

# http://blogs.msdn.com/powershell/archive/2009/05/22/get-visibleprocess-ps1.aspx
function Get-WindowTitle()
{
	Get-Process |where {$_.mainWindowTItle} |format-table id,name,mainwindowtitle –AutoSize
}

# http://blogs.msdn.com/powershell/archive/2009/08/12/get-systemuptime-and-working-with-the-wmi-date-format.aspx
function Get-SystemUptime            
{            
    $operatingSystem = Get-WmiObject Win32_OperatingSystem                
    [Management.ManagementDateTimeConverter]::ToDateTime($operatingSystem.LastBootUpTime)            
}

# http://www.get-command.com/121/transliterating-strings/ 2011/01/01 from 2009/10/30
function new-transliteratedstring {
 param ([string] $inputstring, 
        [string] $SourceSet, 
        [string] $DestinationSet)
 
 $sb = new-object System.Text.StringBuilder
 $table = @{}
 $length = [Math]::Min($SourceSet.length,$DestinationSet.length)
 for ($i = 0; $i -lt $length; $i++) {
   $table.add($SourceSet[$i],$DestinationSet[$i])
 }
 
 $inputstring.toCharArray() | 
   %{$char = if ($table.containskey($_)) {$table[$_]} else {$_}
     $sb.append($char) | out-null
    }
 $sb.toString()
}
 
new-alias tr new-transliteratedstring 

# http://www.get-command.com/128/rot13ing-a-string/ 2011/01/01 from 2009/11/01
function Rot13 {
  param ([string] $inputstring)
  new-transliteratedstring `
    $inputstring `
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" `
    "nopqrstuvwxyzabcdefghijklmNOPQRSTUVWXYZABCDEFGHIJKLM"} 

# http://weblogs.asp.net/adweigert/archive/2008/08/27/powershell-adding-the-using-statement.aspx
function PSUsing {
    param (
        [System.IDisposable] $inputObject = $(throw "The parameter -inputObject is required."),
        [ScriptBlock] $scriptBlock = $(throw "The parameter -scriptBlock is required.")
    )
    
    Try {
        &$scriptBlock
    } Finally {
        if ($inputObject -ne $null) {
            if ($inputObject.psbase -eq $null) {
                $inputObject.Dispose()
            } else {
                $inputObject.psbase.Dispose()
            }
        }
    }
}

# http://thepowershellguy.com/blogs/posh/archive/2010/11/14/powershell-get-easter-function.aspx
# recorrected to use DateTime constructor 2013/04/05
function get-Easter ($year) {

    $a = $year % 19
    $b = [math]::floor($year/100)
    $c = $year % 100
    $d = [math]::floor($b/4)
    $e = $b%4
    $f = [math]::floor(($b+8)/25)
    $g = [math]::floor(($b-$f+1)/3)
    $h = (19*$a+$b-$d-$g+15)%30
    $i = [math]::floor($c/4)
    $k = $c%4 
    $l = (32+2*$e+2*$i-$h-$k)%7
    $m = [math]::floor(($a+11*$h+22*$l)/451)
    $Month = [math]::floor(($h+$l-7*$m+114)/31)
    $day = (($h+$l-7*$m+114)%31)+1

    #[datetime]"$Month/$Day/$Year"
    new-object DateTime ($Year, $Month, $Day)
}

# 20110614: foreach $_, create new PSObject with NoteProperty of all properties on object
filter Regenerate-Object {
	$x = $_; 
	if ($x -ne $null) {
		$n = New-Object PSObject
		$x | gm -MemberType Property | %{ 
			Add-Member -InputObject $n -MemberType NoteProperty -Name $_.Name -Value $x.($_.Name)
			}
		$n
	}
}

# 20110616: from http://bsonposh.com/archives/226 "Dealing iADSLargeInteger in Powershell" 2007/08/13
# modfied to recognize if full LDAP URL (say, from PSCX (Get-ADObject).Path) passed in
# Get-iADSLargeIntFromSearcher -date ((Get-ADObject -domain mackie.com -class User -value "*stehr*").Path) lastlogontimestamp
function Get-iADSLargeIntFromSearcher ([string]$LdapPath, 
	[string]$attribute=$(throw "Attribute Required"), 
	[string]$server,
	[switch]$date)
{
	if ($LdapPath.StartsWith("LDAP://")) {
		$de = [ADSI]$LdapPath
	} elseif ($server) {
		$de = [ADSI]"LDAP://$server/$LdapPath"
	} else {
		$de = [ADSI]"LDAP://$LdapPath"
	}
	$return = new-object system.DirectoryServices.DirectorySearcher($de)
	$value = ($return.findone()).properties[$attribute.ToLower()]
	if ($date)
	{
		[datetime]::FromFileTime([int64]::Parse($value))
	} else {
		$value
	}
}

# 2011/10/11: Dump value as named bits from enum (drop unnamed bits as well)
# note use of comma operator to pass array parameter
# note: new arrays not held by enumerator, so must be held in variable
# Example value: Restricted Read ("ViewListItems, OpenItems, ViewFormPages, Open, ViewPages, BrowseUserInfo, UseClientIntegration, UseRemoteAPIs")
function Convert-AsEnum([UInt64] $value=[uint64]0x3008031021, [Type] $type=[Microsoft.SharePoint.SPBasePermissions])
{
	$local:curr = [uint64]1
	$local:bits = new-object System.Collections.BitArray (,[BitConverter]::GetBytes($value))
	$bits | %{ if ($_) { [Enum]::Format($type, $curr, "G") } ; $curr += $curr }
}

# 2012/04/03 edited from http://get-spscripts.com/2011/02/finding-site-template-names-and-ids-in.html
# example: $ht = @{"foo"="bar", "baz"="quuz"}; New-PSObjectFromHashtable $ht
function New-PSObjectFromHashtable($templateValues, $keys=$(@($templateValues.Keys)))
{
	New-Object PSObject -Property $templateValues | Select @($keys)
}

# 2012/07/30 from http://haacked.com/archive/2012/07/23/get-all-types-in-an-assembly.aspx
# picks up loadables from ReflectionTypeLoadException.Types if not all can load
function GetLoadableTypes([System.Reflection.Assembly]$asm)
{
	try {
		$asm.GetTypes()
	} catch [System.Reflection.ReflectionTypeLoadException] {
		$_.Types | ? {$_ -ne $null}
	}
}

# 2012/07/31: returns generic List
function New-GenericList ($type="System.String")
{
	New-Object "System.Collections.Generic.List``1[$type]"
}

# 2017/09/19: returns generic
function New-GenericOf ($base="HashSet", $type="System.Int32")
{
	New-Object "System.Collections.Generic.$base``1[$type]"
}

# 2013/03/25: Pseudolocalize (from 2006 VB.NET macro for VS)
function Pseudolocalize ([string]$s)
{
	$sIn  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	$sOut = "ÂЬÇÐĘҒĞĦĪĴĶĽЩŊŐΡΘŘŠŦŲдŴҖÝŻâьçðęғğħīĵķľщŋőρθřšŧųџŵҗýż"
	$sVowel = "AEIOUYaeiouy"
	$first = $true
	$sb = new-object System.Text.StringBuilder($s.Length)

	$s.ToCharArray() |
		% {
			if (![Char]::IsLetter($_)) {
				[void]$sb.Append($_)
				$first = $true
			} else {
				$off = $sIn.IndexOf($_)
				if (-1 -eq $off) {
					[void]$sb.Append($_)
				} else {
					if ($first -and (-1 -ne $sVowel.IndexOf($_))) {
						[void]$sb.Append($sOut.Chars($off))
						$first = $false
					}
					[void]$sb.Append($sOut.Chars($off))
				}
			}
		}
	$sb.ToString()
}

# 2013/04/18: 'fix' MS IT powersaving mode : 2016/11/22 W10 Software Center settings can switch off IT power settings
if ([version]((gwmi Win32_OperatingSystem).Version) -gt [version]"5.3") {
	if (powercfg /getactivescheme | ? { !($_.Split(' ',6)[5].StartsWith('(High performance')) }) {
		$g = (powercfg /l | ? { $_.Split(' ',6)[5] -eq '(High performance)'} | % { $_.Split(' ',6)[3]}) 
		if ($null -ne $g) {
			"Resetting powercfg" | fl
			powercfg /setactive $g
		}
	}
}
#

#
# 2013/04/05 locate SharePoint version, if installed
$spVersion = dir 'HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions' -ea SilentlyContinue | 
    ? {$_.GetValue('SharePoint') -eq 'Installed'} |
    select -Last 1
if ($null -ne $spVersion) {
    if (Test-Path "$($spVersion.GetValue('Location'))CONFIG\POWERSHELL\Registration\SharePoint.ps1") {
	    if (!(get-pssnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue)) { & "$($spVersion.GetValue('Location'))CONFIG\POWERSHELL\Registration\SharePoint.ps1" }
	    $global:sphive = [Microsoft.SharePoint.Utilities.SPUtility]::GetGenericSetupPath("").Trim('\') #2012/03/27
    }
}
# only cd to userprofile if we're in system directory (as admin launch, determine from ComSpec) 2017/04/05
if ($PWD.Path -eq (split-path ${env:ComSpec} -parent)) { Set-Location $env:USERPROFILE ; (get-psprovider 'FileSystem').Home = $env:USERPROFILE }
[Environment]::CurrentDirectory = $PWD
#

#
# 2014/04/25 keep running command until it sucessfully completes
function Wait-CommandSuccessful([ScriptBlock]$exec={qwinsta.exe -server:osgsecdev01}, [int]$seconds=5)
{
	do { . $exec ; if ($LASTEXITCODE) { Start-Sleep -Seconds $seconds } } while ($LASTEXITCODE)
}

#
# 2015/02/12 cd into [Environment] special folder i.e. Startup, SendTo, CommonDocuments, (Common)Templates
function CDSpecial([Environment+SpecialFolder]$specialFolder='Startup')
{
	cd ([Environment]::GetFolderPath($specialFolder))
}

# 2017/03/27 Convert hex string '7B00220056006500' into (Unicode) string '{"Ve'
# uses RegExp substitution $0 to simulate BitConverter output, then splits and makes byte[] to pull from
function ConvertFrom-HexString([string]$s, [System.Text.Encoding]$encoding=[System.Text.Encoding]::Unicode)
{
	$encoding.GetString([Byte[]]@(($s -replace '(..)','0x$0-').Trim('-').Split('-')))
}

# 2017/05/24 AwaitRdpConnection
function AwaitRdpConnection($server, [switch]$nodrop, [switch]$noclient, [switch]$wait)
{
	if (gcm Test-NetConnection -ea SilentlyContinue) {
		$RdpCheck = {Test-NetConnection -ComputerName $server -CommonTCPPort RDP -InformationLevel Quiet}
	} else {
		$RdpCheck = {$(try {$socket = New-Object Net.Sockets.TcpClient($server, 3389);if ($socket.Connected) {$true}; $socket.Close()} catch {})}
	}
	if (!$nodrop) {
		while (&$RdpCheck) {
			"$(get-date -F o) Waiting for drop"; sleep 30
		}
	}
	while (!(&$RdpCheck)) {
		"$(get-date -f o) Waiting for restart"; sleep 30
	}
	"$(get-date -f o) Responding`n`n"
	if (!$noClient) { start-process -wait:$wait -filepath "$env:windir\system32\mstsc.exe" -argumentlist "/v:$server","/w:1400","/h:900" }
}

#