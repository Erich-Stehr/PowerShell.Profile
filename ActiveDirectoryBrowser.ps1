# ActiveDirectoryBrowser.Ps1 
# 
# This script does show a GUI to browse ActiveDirectory in a Treeview 
# and Returns the DirectoryEntry Selected for use in PowerShell 
# or if LoadOnly Parameter is given it just loads the Browse-ActiveDirectory function, 
# and does set the alias bad, for loading the function for interactive use by dotsourcing the script 
# 
# /\/\o\/\/ 2006 
# 
# http://mow001.blogspot.com 
# http://mow001.blogspot.com/2006/09/powershell-active-directory-part-10-ad.html

# the Main function that can be loaded or gets started at the end of the script 

Function Browse-ActiveDirectory { 
$root=[ADSI]''

# Try to connect to the Domain root 

&{trap {throw "$($_)"};[void]$Root.psbase.get_Name()} 

# Make the form 
# add a reference to the forms assembly
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$form = new-object Windows.Forms.form 
$form.Size = new-object System.Drawing.Size @(800,600) 
$form.text = "/\/\o\/\/'s PowerShell ActiveDirectory Browser" 

# Make TreeView to hold the Domain Tree 

$TV = new-object windows.forms.TreeView 
$TV.Location = new-object System.Drawing.Size(10,30) 
$TV.size = new-object System.Drawing.Size(770,470) 
$TV.Anchor = "top, left, right" 

# Add the Button to close the form and return the selected DirectoryEntry 

$btnSelect = new-object System.Windows.Forms.Button 
$btnSelect.text = "Select" 
$btnSelect.Location = new-object System.Drawing.Size(710,510) 
$btnSelect.size = new-object System.Drawing.Size(70,30) 
$btnSelect.Anchor = "Bottom, right" 

# If Select button pressed set return value to Selected DirectoryEntry and close form 

$btnSelect.add_Click({ 
$script:Return = new-object system.directoryservices.directoryEntry("LDAP://$($TV.SelectedNode.text)") 
$form.close() 
}) 

# Add Cancel button 

$btnCancel = new-object System.Windows.Forms.Button 
$btnCancel.text = "Cancel" 
$btnCancel.Location = new-object System.Drawing.Size(630,510) 
$btnCancel.size = new-object System.Drawing.Size(70,30) 
$btnCancel.Anchor = "Bottom, right" 

# If cancel button is clicked set returnvalue to $False and close form 

$btnCancel.add_Click({$script:Return = $false ; $form.close()}) 

# Create a TreeNode for the domain root found 

$TNRoot = new-object System.Windows.Forms.TreeNode("Root") 
$TNRoot.Name = $root.name 
$TNRoot.Text = $root.distinguishedName 
$TNRoot.tag = "NotEnumerated" 

# First time a Node is Selected, enumerate the Children of the selected DirectoryEntry 

$TV.add_AfterSelect({ 
if ($this.SelectedNode.tag -eq "NotEnumerated") { 

$de = [ADSI]"LDAP://$($this.SelectedNode.text)"

# Add all Children found as Sub Nodes to the selected TreeNode 

$de.psBase.get_Children() | 
foreach { 
$TN = new-object System.Windows.Forms.TreeNode 
$TN.Name = $_.name 
$TN.Text = $_.distinguishedName 
$TN.tag = "NotEnumerated" 
$this.SelectedNode.Nodes.Add($TN) 
} 

# Set tag to show this node is already enumerated 

$this.SelectedNode.tag = "Enumerated" 
} 
}) 

# Add the RootNode to the Treeview 

[void]$TV.Nodes.Add($TNRoot) 

# Add the Controls to the Form 

$form.Controls.Add($TV) 
$form.Controls.Add($btnSelect ) 
$form.Controls.Add($btnCancel ) 

# Set the Select Button as the Default 

$form.AcceptButton = $btnSelect 

$Form.Add_Shown({$form.Activate()}) 
[void]$form.showdialog() 

# Return selected DirectoryEntry or $false as Cancel Button is Used 
Return $script:Return 
} 

# If used as a script start the function 

Set-PSDebug -Strict:$false # Otherwise Checking the Switch parmeter does fail (Bug ?) 

if ($LoadOnly.IsPresent) { 

# Only load the Function for interactive use 

if (-not $MyInvocation.line.StartsWith('. ')) { 
Write-Warning "LoadOnly Switch is given but you also need to 'dotsource' the script to load the function in the global scope" 
Write-Host "To Start a script in the global scope (dotsource) put a dot and a space in front of path to the script" 
Write-Host "If the script is in the current directory this would look like this :" 
Write-Host ". .\ActiveDirectoryBrowser.Ps1" 
Write-Host "then :" 
} 
Write-Host "The Browse-ActiveDirectory Function is loaded and can be used like this :" 
Write-Host '$de = Browse-ActiveDirectory' 
Set-alias bad Browse-ActiveDirectory 
} 
Else { 

# start Function 

. Browse-ActiveDirectory $root 

}
