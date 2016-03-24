############################################################################## 
## 
## Compare-File 
## 
############################################################################## 
## From http://www.leeholmes.com/blog/2013/11/29/using-powershell-to-compare-diff-files/
<# 
  
.SYNOPSIS 
  
Compares two files, displaying differences in a manner similar to traditional 
console-based diff utilities. 
  
#> 

param( 
    ## The first file to compare 
    $file1, 
    
    ## The second file to compare 
    $file2, 

    ## The pattern (if any) to use as a filter for file 
    ## differences 
    $pattern = ".*" 
) 

## Get the content from each file 
$content1 = Get-Content $file1 
$content2 = Get-Content $file2 

## Compare the two files. Get-Content annotates output objects with 
## a ‘ReadCount’ property that represents the line number in the file 
## that the text came from. 
$comparedLines = Compare-Object $content1 $content2 -IncludeEqual | 
    Sort-Object { $_.InputObject.ReadCount } 
    
$lineNumber = 0 
$comparedLines | foreach { 

    ## Keep track of the current line number, using the line 
    ## numbers in the "after" file for reference. 
    if($_.SideIndicator -eq "==" -or $_.SideIndicator -eq "=>") 
    { 
        $lineNumber = $_.InputObject.ReadCount 
    } 
    
    ## If the text matches the pattern, output a custom object 
    ## that displays text like this: 
    ## 
    ## Line Operation Text 
    ## —- ——— —- 
    ## 59 added New text added 
    ## 
    if($_.InputObject -match $pattern) 
    { 
        if($_.SideIndicator -ne "==") 
        { 
            if($_.SideIndicator -eq "=>") 
            { 
                $lineOperation = "added" 
            } 
            elseif($_.SideIndicator -eq "<=") 
            { 
                $lineOperation = "deleted" 
            } 
                
            [PSCustomObject] @{ 
                Line = $lineNumber 
                Operation = $lineOperation 
                Text = $_.InputObject  
            } 
        } 
    } 
} 
