param ($path="C:\Users\v-erichs\queues_snapshot.tsv")
function ReadAllText($path) {
    [System.IO.File]::ReadAllText($path)
}
ReadAllText -path $path | % { $_.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries) } | % { 
    $s = $_
    $x = $s.Split("`t")
    $c = $x.Count - 1
    if ($x[$c] -eq "") { $s } else { $x[$c] = (dir "$($x[$c])*").FullName ; [String]::Join("`t", $x) }
} 