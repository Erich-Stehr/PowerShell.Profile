﻿## format-hex.msh
## Convert a byte array into a hexidecimal dump
##
## Example usage:
## get-content 'c:\windows\Coffee Bean.bmp' -encoding byte | format-hex | more
###  http://www.leeholmes.com/blog/HexDumperInMonad.aspx

## Convert the input to an array of bytes.  This is a strongly-typed variable,
## so that we're not trying to iterate over strings, directory entries, etc.
[byte[]] $bytes = $(foreach($byte in $input) { $byte })

## Store our header, and formatting information
$counter = 0
$header = "            0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F"
$nextLine = "{0}   " -f 
    [Convert]::ToString($counter, 16).ToUpper().PadLeft(8, '0')
$asciiEnd = ""

## Output the header
"`r`n$header`r`n"

foreach($byte in $bytes)
{
   ## Display each byte, in 2-digit hexidecimal, and add that to the left-hand
   ## side.  Notice the use of the '-f' operator here.  This provides access
   ## to the facilities offered by [String]::Format.
   $nextLine += "{0:X2} " -f $byte

   ## If the character is printable, add its ascii representation to
   ## the right-hand side.  Otherwise, add a dot to the right hand side.
   if(($byte -ge 0x20) -and ($byte -le 0xFE))
   {
      $asciiEnd += [char] $byte
   }
   else
   {
      $asciiEnd += "."
   }

   $counter++;

   ## If we've hit the end of a line, combine the right half with the left half,
   ## and start a new line.
   if(($counter % 16) -eq 0)
   {
      "$nextLine $asciiEnd"
      $nextLine = "{0}   " -f 
        [Convert]::ToString($counter, 16).ToUpper().PadLeft(8, '0')
      $asciiEnd = "";
   }
}

## At the end of the file, we might not have had the chance to output the end
## of the line yet.  Only do this if we didn't exit on the 16-byte boundary,
## though.
if(($counter % 16) -ne 0)
{
   while(($counter % 16) -ne 0)
   {
      $nextLine += "   "
      $asciiEnd += " "
      $counter++;
   }
   "$nextLine $asciiEnd"
}

""


