# from comment on <http://rkeithhill.wordpress.com/2010/09/19/determining-scriptdir-safely/>
function ScriptRoot { Split-Path $MyInvocation.ScriptName }
write-host "'$(ScriptRoot)' is current directory"
write-output (ScriptRoot)