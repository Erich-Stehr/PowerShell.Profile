function Import-PSModuleConditionally ($name, [Switch]$quiet)
{
	if ((gcm get-module -ea silentlycontinue) -and (Get-Module -ListAvailable $name)) { 
		import-module $name
		if (!$quiet) { "$name module imported" }
	}
}
#Import-PSModuleConditionally PSCX
Import-PSModuleConditionally StudioShell

function global:ScrubBlankLines
{
	$selection = $DTE.ActiveDocument.Selection
	$s = $selection.TopPoint.CreateEditPoint()
	$f = $selection.BottomPoint.CreateEditPoint()

	if ($s.EqualTo($f)) {
		$s.StartOfDocument()
		$f.EndOfDocument()
	}
	$selection.MoveToPoint($s)

	$DTE.Find.FindWhat = '^\s*$'
	$DTE.Find.Target = [EnvDTE.vsFindTarget]::vsFindTargetCurrentDocument
	#$DTE.Find.MatchCase = $False
	#$DTE.Find.MatchWholeWord = $true
	$DTE.Find.Backwards = $false
	$DTE.Find.MatchInHiddenText = $true
	$DTE.Find.PatternSyntax = [EnvDTE.vsFindPatternSyntax]::vsFindPatternSyntaxRegExpr
	$DTE.Find.Action = [EnvDTE.vsFindAction]::vsFindActionFind
	do {
		$fd = $DTE.Find.Execute()
		if (($fd -eq [EnvDTE.vsFindResult]::vsFindResultError) -or ($fd -eq [EnvDTE.vsFindResult]::vsFindResultNotFound)) {
			break;
		}
		#$DTE.ExecuteCommand('Edit.FindNext')
		if ($selection.BottomPoint.LessThan($s)) { break; }
		if (!$selection.TopPoint.LessThan($f)) { break; }
		$selection.Delete()
	} while ($true)
	$selection.MoveToPoint($s, $false)
	$selection.MoveToPoint($f, $true)	
}