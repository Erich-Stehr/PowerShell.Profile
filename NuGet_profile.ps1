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

function global:CollapseToDefinitions
{
    function DefinitionCollapsar([EnvDTE.CodeElement]$ceRoot)
    {
        if ($ceRoot -eq $null) {
            Write-Debug "DefinitionCollapsar: null"
            return;
        }
        Write-Debug ("DefinitionCollapsar: Kind={0}" -f $ceRoot.Kind)
        if ($ceRoot.Kind -eq [EnvDTE.vscmElement]::vsCMElementNamespace) {
            (Get-Interface $ceRoot ([EnvDTE.CodeNamespace])).Members | % {
                DefinitionCollapsar($_)
            }
        } ElseIf ($ceRoot.Kind -eq [EnvDTE.vscmElement]::vsCMElementClass) {
            (Get-Interface $ceRoot ([EnvDTE.CodeClass])).Members | % {
                DefinitionCollapsar($_)
            }
        } ElseIf ($ceRoot.Kind -eq [EnvDTE.vscmElement]::vsCMElementStruct) {
            (Get-Interface $ceRoot ([EnvDTE.CodeStruct])).Members | % {
                DefinitionCollapsar($_)
            }
        } ElseIf ($ceRoot.Kind -eq [EnvDTE.vscmElement]::vsCMElementFunction) {
            Write-Debug ("DefinitionCollapsar: Kind=vsCMElementFunction: {0}" -f $ceRoot.Name)
            try {
                $sp = $ceRoot.GetStartPoint([EnvDTE.vsCMPart]::vsCMPartNavigate)
                $DTE.ActiveDocument.Selection.MoveToPoint($sp)
                $DTE.ExecuteCommand("Edit.ToggleOutliningExpansion")
            } catch {
                # skip, as implicit property accessors don't have a start point to navigate to, e.g. `bool Success { get; set; }`
            }
        } ElseIf ($ceRoot.Kind -eq [EnvDTE.vscmElement]::vsCMElementProperty) {
            $cp = $null
            Try {
                $cp = (get-interface $ceRoot ([EnvDTE.CodeProperty]))
            } Catch [System.Exception] {
                # eat the exceptions and skip
            }
            If ($cp.Getter -ne $null) {
                DefinitionCollapsar($cp.Getter)
            }
            If ($cp.Setter -ne $null) {
                DefinitionCollapsar($cp.Setter)
            }
            $DTE.ActiveDocument.Selection.MoveToPoint($ceRoot.GetStartPoint([EnvDTE.vsCMPart]::vsCMPartWholeWithAttributes))
            $DTE.ExecuteCommand("Edit.ToggleOutliningExpansion")
        }
    }

    $DTE.ActiveDocument.Activate()
    $cp = $DTE.ActiveDocument.Selection.ActivePoint.CreateEditPoint()

    $DTE.ExecuteCommand("Edit.StopOutlining")
    $DTE.ExecuteCommand("Edit.StartAutomaticOutlining")
    (Get-Interface $DTE.ActiveDocument.ProjectItem.FileCodeModel ([EnvDTE.FileCodeModel])).CodeElements | % {
        DefinitionCollapsar($_)
    }

    $DTE.ActiveDocument.Selection.MoveToPoint($cp)
    $cp.TryToShow([EnvDTE.vsPaneShowHow]::vsPaneShowCentered)
}

function global:ResetOutlining()
{
    $DTE.ActiveDocument.Activate()
    $DTE.ExecuteCommand("Edit.StopOutlining")
    $DTE.ExecuteCommand("Edit.StartAutomaticOutlining")
}
