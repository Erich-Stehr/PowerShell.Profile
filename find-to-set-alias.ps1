# http://bradwilson.typepad.com/blog/2008/12/find-to-set-aliasps1.html
param(
    $foldersearch = $(throw "foldersearch required"),
    $filename = $(throw "filename required"),
    $alias = $(throw "alias required"),
    [switch]$quiet
)

if ((test-path $foldersearch) -eq $false) {
    if ($quiet -eq $false) { write-warning ("Could not find any paths to match " + $foldersearch) }
    exit
}

# If the user specified a wildcard, turn the foldersearch into an array of matching items
# We don't always want to do this, because specifying a non-wildcard directory gives false positives

if ($foldersearch.contains('*') -or $foldersearch.contains('?')) {
    $foldersearch = Get-ChildItem $foldersearch -ErrorAction SilentlyContinue
}

$files = $foldersearch | %{ Get-ChildItem $_ -Recurse -Filter $filename -ErrorAction SilentlyContinue }

if ($files -eq $null) {
    if ($quiet -eq $false) {
        write-warning ("Could not find " + $filename + " in searched paths:")
        $foldersearch | %{ write-warning ("  " + $_) }
    }
    exit
}

set-alias $alias $files[0].FullName -scope Global

if ($quiet -eq $false) {
    write-host ("Added alias " + $alias + " for " + $files[0].FullName)
    if ($files.count -gt 1) {
        write-warning ("There were " + $files.count + " matches:")
        $files | %{ write-warning ("  " + $_.FullName) }
    }
}