$MyInvocation
"`$MyInvocation.MyCommand=$($MyInvocation.MyCommand) $(get-typename -full $MyInvocation.MyCommand)"
"`$MyInvocation.ScriptName=$($MyInvocation.ScriptName)"
$MyInvocation.MyCommand
"`$MyInvocation.MyCommand.Path=$($MyInvocation.MyCommand.Path)  $(get-typename -full $MyInvocation.MyCommand.Path)"
"`$MyInvocation.MyCommand.Definition=$($MyInvocation.MyCommand.Definition)  $(get-typename -full $MyInvocation.MyCommand.Definition)"

[IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)