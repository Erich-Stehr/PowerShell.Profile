# partially from <https://michlstechblog.info/blog/powershell-show-a-messagebox/>
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

function global:Show-MessageBox([String]$Message,
	[string]$Caption = $null,
	[System.Windows.Forms.MessageBoxButtons]$MessageBoxButtons = $([System.Windows.Forms.MessageBoxButtons]::OK), 
	[System.Windows.Forms.MessageBoxIcon]$MessageBoxIcon = $([System.Windows.Forms.MessageBoxIcon]::None),
	[System.Windows.Forms.MessageBoxDefaultButton]$MessageBoxDefaultButton = $([System.Windows.Forms.MessageBoxDefaultButton]::Button1),
	[System.Windows.Forms.MessageBoxOptions]$MessageBoxOptions = 0) #helpFilePath, navigator/keyword, 
{
    [System.Windows.Forms.MessageBox]::Show($Message, $Caption, $MessageBoxButtons, $MessageBoxIcon, $MessageBoxDefaultButton, $MessageBoxOptions)
}
