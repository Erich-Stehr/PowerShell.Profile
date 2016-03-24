### IMAPIFormat
param ([int] $driveNum=0, [switch] $full=$false)

# connect IMAPI to drive

$g_DiscMaster = new-object -com IMAPI2.MsftDiscMaster2
$recorder = new-object -com IMAPI2.MsftDiscRecorder2
$uniqueID = $g_DiscMaster.Item($driveNum)
$recorder.InitializeDiscRecorder($uniqueId)

# set up to format

$eraser = new-object -com IMAPI2.MsftDiscFormat2Erase
$eraser.Recorder = $recorder
$eraser.ClientName = "IMAPIFormat.ps1"
$eraser.FullErase = $full
if ($eraser.CurrentPhysicalMediaType -ne 0x5) #DVD-RAM
{ "Current disc is not a DVD-RAM, is type $($eraser.CurrentPhysicalMediaType)" } else {
$eraser.EraseMedia() # can't handle events, so can't tell where in the process
}

#