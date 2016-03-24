﻿# <http://chrisjwarwick.wordpress.com/2011/11/04/the-get-exifdatetaken-powershell-script-cmdlet/>, <http://chrisjwarwick.wordpress.com/2011/11/08/modify-date-taken-values-on-photos-with-powershell-the-update-exifdatetaken-script-cmdlet/>
<#

Chris Warwick, @cjwarwickps, October 2011
chrisjwarwick.wordpress.com

This version published on SkyDrive here:
https://skydrive.live.com/redir.aspx?cid=7cb58be453f7e567&resid=7CB58BE453F7E567!124


The script file contains two functions:



    Get-ExifDateTaken -Path [filepaths]

        Takes a file (fileinfo or string) or an array of these
        Gets the ExifDT value (EXIF Property 36867)



    Update-ExifDateTaken -Path [filepaths] -Offset [TimeSpan]

        Takes a file (fileinfo or string) or an array of these
        Modifies the ExifDT value (EXIF Property 36867) as specified



# Further samples:

# Just Update

gci *.jpg|Update-ExifDateTaken -Offset '-0:07:10' -PassThru|ft Path, ExifDateTaken

# Update & Rename

gci *.jpg|
 Update-ExifDateTaken -Offset '-0:07:10' -PassThru|
 Rename-Item -NewName {"LeJog 2011 {0:MM-dd HH.mm.ss dddd} ({1}).jpg" -f $_.ExifDateTaken, (Split-Path (Split-Path $_) -Leaf)}

# Just Rename

gci *.jpg|
 Get-ExifDateTaken |
 Rename-Item -NewName {"LeJog 2011 {0:MM-dd HH.mm.ss dddd} ({1}).jpg" -f $_.ExifDateTaken, (Split-Path (Split-Path $_) -Leaf)}


Syntax/parameters with ref James O'Neill (http://jamesone111.wordpress.com/2011/10/24/maximize-the-reuse-of-your-powershell)

#>





Function Get-ExifDateTaken {
<#
.Synopsis
   Gets the DateTaken EXIF property in an image file.
.DESCRIPTION
   This script cmdlet reads the EXIF DateTaken property in an image and passes is down the pipeline
   attached to the PathInfo item of the image file.
.PARAMETER Path
   The image file or files to process.
.EXAMPLE
   Get-ExifDateTaken img3.jpg
   (Reads the img3.jpg file and returns the im3.jpg PathInfo item with the EXIF DateTaken attached)
.EXAMPLE
   Get-ExifDateTaken *3.jpg |ft path, exifdatetaken
   (Output the EXIF DateTaken values for all matching files in the current folder)
.EXAMPLE
   gci *.jpeg,*.jpg|Get-ExifDateTaken 
   (Read multiple files from the pipeline)
.EXAMPLE
   gci *.jpg|Get-ExifDateTaken|Rename-Item -NewName {"LeJog 2011 {0:MM-dd HH.mm.ss}.jpg" -f $_.ExifDateTaken}
   (Gets the EXIF DateTaken on multiple files and renames the files based on the time)
.OUTPUTS
   The scripcmdlet outputs PathInfo objects with an additional ExifDateTaken
   property that can be used for later processing.
.FUNCTIONALITY
   Gets the EXIF DateTaken image property on a specified image file.
#>

[CmdletBinding()]

Param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [Alias('FullName', 'FileName')]
    $Path
)



    Begin 
    {
        Set-StrictMode -Version Latest
    }



    Process 
    {
        # Cater for arrays of filenames and wild-cards by using Resolve-Path
        Write-Verbose "Processing input item '$Path'"
        
        
        $PathItems=Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ResolveError
        If ($ResolveError) {
            Write-Warning "Bad path '$Path' ($($ResolveError[0].CategoryInfo.Category))"
        }


        Foreach ($PathItem in $PathItems) {
            # Read the current file and extract the Exif DateTaken property

            $ImageFile=$PathItem.Path

            Try {
                $FileStream=New-Object System.IO.FileStream($ImageFile,
                                                            [System.IO.FileMode]::Open,
                                                            [System.IO.FileAccess]::Read,
                                                            [System.IO.FileShare]::Read,
                                                            1024,     # Buffer size
                                                            [System.IO.FileOptions]::SequentialScan
                                                           )
                $Img=[System.Drawing.Imaging.Metafile]::FromStream($FileStream)
                $ExifDT=$Img.GetPropertyItem('36867')
            }
            Catch{
                Write-Warning "Check $ImageFile is a valid image file ($_)"
                Break
            }
    

            # Convert the raw Exif data

            Try {
                $ExifDtString=[System.Text.Encoding]::ASCII.GetString($ExifDT.Value)

                # Convert the result to a [DateTime]
                # Note: This looks like a string, but it has a trailing zero (0x00) character that 
                # confuses ParseExact unless we include the zero in the ParseExact pattern....

                $OldTime=[datetime]::ParseExact($ExifDtString,"yyyy:MM:dd HH:mm:ss`0",$Null)      
            }
            Catch {
                Write-Warning "Problem reading Exif DateTaken string in $ImageFile ($_)"
                Break
            }

            $FileStream.Close(); $Img.Dispose()

            Write-Verbose "Extracted EXIF infomation from $ImageFile"
            Write-Verbose "Original Time is $($OldTime.ToString('F'))"   

            # Decorate the path object with the EXIF dates and pass it on...

            $PathItem | Add-Member -MemberType NoteProperty -Name ExifDateTaken -Value $OldTime
            Write-Output $PathItem

        } # End Foreach Path

    } # End Process Block



    End
    {
        # There is no end processing...
    }


} # End Function




# ------------------------------------------------------------------------------------------------------



Function Update-ExifDateTaken {
<#
.Synopsis
   Changes the DateTaken EXIF property in an image file.
.DESCRIPTION
   This script cmdlet updates the EXIF DateTaken property in an image by adding an offset to the 
   existing DateTime value.  The offset (which must be able to be interpreted as a [TimeSpan] type)
   can be positive or negative - moving the DateTaken value to a later or earlier time, respectively.
   This can be useful (for example) to correct times where the camera clock was wrong for some reason - 
   perhaps because of timezones; or to synchronise photo times from different cameras.
.PARAMETER Path
   The image file or files to process.
.PARAMETER Offset
   The time offset by which the EXIF DateTaken value should be adjusted.
   Offset can be positive or negative and must be convertible to a [TimeSpan] type.
.PARAMETER PassThru
   Switch parameter, if specified the paths of the image files processed are written to the pipeline.
   The PathInfo objects are additionally decorated with the Old and New EXIF DateTaken values.
.EXAMPLE
   Update-ExifDateTaken img3.jpg -Offset 0:10:0  -WhatIf
   (Update the img3.jpg file, adding 10 minutes to the DateTaken property)
.EXAMPLE
   Update-ExifDateTaken *3.jpg -Offset -0:01:30 -Passthru|ft path, exifdatetaken
   (Subtract 1 Minute 30 Seconds from the DateTaken value on all matching files in the current folder)
.EXAMPLE
   gci *.jpeg,*.jpg|Update-ExifDateTaken -Offset 0:05:00
   (Update multiple files from the pipeline)
.EXAMPLE
   gci *.jpg|Update-ExifDateTaken -Offset 0:5:0 -PassThru|Rename-Item -NewName {"LeJog 2011 {0:MM-dd HH.mm.ss}.jpg" -f $_.ExifDateTaken}
   (Updates the EXIF DateTaken on multiple files and renames the files based on the new time)
.OUTPUTS
   If -PassThru is specified, the scripcmdlet outputs PathInfo objects with additional ExifDateTaken
   and ExifOriginalDateTaken properties that can be used for later processing.
.NOTES
   This scriptcmdlet will overwrite files without warning - take backups first...
.FUNCTIONALITY
   Modifies the EXIF DateTaken image property on a specified image file.
#>

[CmdletBinding(SupportsShouldProcess=$True)]

Param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [Alias('FullName', 'FileName')]
    $Path, 

    [Parameter(Mandatory=$True)]
    [TimeSpan]$Offset, 

    [Switch]$PassThru
)



    Begin 
    {
        Set-StrictMode -Version Latest
    }



    Process 
    {
        # Cater for arrays of filenames and wild-cards by using Resolve-Path
        Write-Verbose "Processing input item '$Path'"
        
        
        $PathItems=Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ResolveError
        If ($ResolveError) {
            Write-Warning "Bad path '$Path' ($($ResolveError[0].CategoryInfo.Category))"
        }


        Foreach ($PathItem in $PathItems) {
            # Read the current file and extract the Exif DateTaken property

            $ImageFile=$PathItem.Path

            Try {
                $FileStream=New-Object System.IO.FileStream($ImageFile,
                                                            [System.IO.FileMode]::Open,
                                                            [System.IO.FileAccess]::Read,
                                                            [System.IO.FileShare]::Read,
                                                            1024,     # Buffer size
                                                            [System.IO.FileOptions]::SequentialScan
                                                           )
                $Img=[System.Drawing.Imaging.Metafile]::FromStream($FileStream)
                $ExifDT=$Img.GetPropertyItem('36867')
            }
            Catch{
                Write-Warning "Check $ImageFile is a valid image file ($_)"
                Break
            }
    

            #region Convert the raw Exif data and modify the time

            Try {
                $ExifDtString=[System.Text.Encoding]::ASCII.GetString($ExifDT.Value)

                # Convert the result to a [DateTime]
                # Note: This looks like a string, but it has a trailing zero (0x00) character that 
                # confuses ParseExact unless we include the zero in the ParseExact pattern....

                $OldTime=[datetime]::ParseExact($ExifDtString,"yyyy:MM:dd HH:mm:ss`0",$Null)      
            }
            Catch {
                Write-Warning "Problem reading Exif DateTaken string in $ImageFile ($_)"
                # Only continue if an absolute time was specified...
                #Todo: Add an absolute parameter and a parameter-set
                # If ($Absolute) {Continue} Else {Break}
                Break
            }

            Write-Verbose "Extracted EXIF infomation from $ImageFile"
            Write-Verbose "Original Time is $($OldTime.ToString('F'))"   

            Try {
                # Convert the time by adding the offset
                $NewTime=$OldTime.Add($Offset)
            }
            Catch {
                Write-Warning "Problem with time offset $Offset ($_)"
                Break
            }

            # Convert to a string, changing slashes back to colons in the date.  Include trailing 0x00...
            $ExifTime=$NewTime.ToString("yyyy:MM:dd HH:mm:ss`0")

            Write-Verbose "New Time is $($NewTime.ToString('F')) (Exif: $ExifTime)" 

            #endregion


            # Overwrite the EXIF DateTime property in the image and set
            $ExifDT.Value=[Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)
            $Img.SetPropertyItem($ExifDT)

            # Create a memory stream to save the modified image...
            $MemoryStream=New-Object System.IO.MemoryStream

            Try {
                # Save to the memory stream then close the original objects
                # Save as type $Img.RawFormat  (Usually [System.Drawing.Imaging.ImageFormat]::JPEG)
                $Img.Save($MemoryStream, $Img.RawFormat)
            }
            Catch {
                Write-Warning "Problem modifying image $ImageFile ($_)"
                $MemoryStream.Close(); $MemoryStream.Dispose()
                Break
            }
            Finally {
                $FileStream.Close()
                $Img.Dispose()
            }


            # Update the file (Open with Create mode will truncate the file)

            If ($PSCmdlet.ShouldProcess($ImageFile,'Update EXIF DateTaken')) {
                Try {
                    $Writer = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Create)
                    $MemoryStream.WriteTo($Writer)
                }
                Catch {
                    Write-Warning "Problem saving to $OutFile ($_)"
                    Break
                }
                Finally {
                    $Writer.Flush(); $Writer.Close()
                }
            }

            $MemoryStream.Close(); $MemoryStream.Dispose()

            
            # Finally, if requested, decorate the path object with the EXIF dates and pass it on...

            If ($PassThru) {
                $PathItem | Add-Member -MemberType NoteProperty -Name ExifDateTaken -Value $NewTime
                $PathItem | Add-Member -MemberType NoteProperty -Name ExifOriginalDateTaken -Value $OldTime
                Write-Output $PathItem
            }


        } # End Foreach Path

    } # End Process Block



    End
    {
        # There is no end processing...
    }


} # End Function
