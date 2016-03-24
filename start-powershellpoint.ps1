#requires -version 2

### http://www.wintellect.com/CS/blogs/jrobbins/archive/2010/03/10/start-powershellpoint.aspx

# (c) 2010 by John Robbins\Wintellect – Do whatever you want to do with it
# as long as you give credit.

<#.SYNOPSIS
PowerShellPoint is the *only* way to do a presentation on PowerShell. All
PowerShell all the time!
.DESCRIPTION
If you're doing a presentation on using PowerShell, there's Jeffrey Snover's
excellent Start-Demo, (updated by Joel Bennett (http://poshcode.org/705)) for
running the actual commands. However, to show discussion and bullet points,
everyone switches to PowerPoint. That's crazy! EVERYTHING should be done in
PowerShell when presenting PowerShell. Hence, PowerShellPoint!

To create your "slides" the format is as follows:
Slide titles start with an exclamation point.
Comment (#) are ignored.
The slide points respect any white space and blank lines you have.
All titles and slide points are indented one character.

Here's an example slide file:
------
# A comment line that's ignored.
!First Title
Point 1
    Sub Point A
Point 2
    Sub Point B
!Second Title
Point 3
    Sub Point C
Point 4
    Sub Point D
!Third Title
Point 5
    Sub Point E
------

The script will validate that no slides contain more points than can be
displayed or individual points will wrap.


The default is to switch the window to 80 x 25 but you can specify the window size
as parameters to the script.

The script properly saves and restores the original screen size and buffer on
exit.

When presenting with PowerShellPoint, use the 'h' command to get help.


.PARAMETER File
The file that contains your slides. Defaults to .\Slides.txt.
.PARAMETER Width
The width in characters to make the screen and buffer. Defaults to 80.
.PARAMETER Height
The height in characters to make the screen and bugger. Defaults to 25.
#>

param( [string]$File = ".\Slides.txt",
       [int]$Width = 80,
       [int]$Height = 25)

Set-StrictMode –version Latest

$scriptVersion = "1.0"

# Constants you may want to change.
# The foreground and background colors for the title and footer text.
$titleForeground = "Yellow"
$titleBackground = "Black"
# Slide points foreground and background.
$textBackGround = $Host.UI.RawUI.BackgroundColor
$textForeGround = $Host.UI.RawUI.ForegroundColor

# A function for reading in a character swiped from Jaykul's
# excellect Start-Demo 3.3.3.
function Read-Char()
{
    $inChar=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    # loop until they press a character, so Shift or Ctrl, etc don't terminate us
    while($inChar.Character -eq 0)
    {
        $inChar=$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
    }
    return $inChar.Character
}

function ProcessSlides($inputFile)
{
    $rawLines = Get-Content $inputFile

    # Contains the actual slides. The key is the slide number and the value are the
    # text lines.
    $slides = @{}

    # The slide number I'm processing.
    $slideNumber = 0
    [string[]]$lines = $null

    # Process the raw text by reading it into the hash table.
    for ($i = 0 ; $i -lt $rawLines.Count ; $i++ )
    {
        # Skip any comment lines.
        if ($rawLines[$i].Trim(" ").StartsWith("#"))
        {
            continue
        }
 
        # Lines starting with "!" are a title.
        if ($rawLines[$i].StartsWith("!"))
        {
            if ($lines -ne $null)
            {
                $slides.Add($slideNumber,$lines)
                $lines = $null        
            }
            $slideNumber++
            if ($rawLines[$i].Substring(1).Length -eq 0)
            {
                throw "You have an empty title slide"
            }
            $lines += $rawLines[$i].Substring(1)
        }
        else
        {
            if ($slideNumber -eq 0)
            {
                throw "The first line must be a title slide starting with !"
            }

            # Make sure the line won't wrap.
            if ($rawLines[$i].Length -gt ($Width - 1))
            {
                Write-Warning "Slide line: $rawLines[$i] is too wide for the screen" -WarningAction Inquire
            }

            $lines += $rawLines[$i]

            # Check to see if this slide is bigger than the height
            if ($lines.Length -gt ($Height - 4))
            {
                $title = $lines[0]
                Write-Warning "Slide $title is too long for the screen" -WarningAction Inquire
            }
        }
    }

    # Add the last slide.
    $slides.Add($slideNumber,$lines)

    # Do some basic sanity checks on the slides.
    if ($slides.Keys.Count -eq 0)
    {
        throw "Input file '$File' does not look properly formatted."
    }
    return $slides
}

function Draw-Title($title)
{
    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.x = 0
    $cursorPos.y = 0
    $Host.UI.RawUI.CursorPosition = $cursorPos
 
    Write-Host -NoNewline -back $titleBackground -fore $titleForeground $(" " * $Width)
    Write-Host -NoNewline -back $titleBackground -fore $titleForeground " " $title $(" " * ($Width - $title.Length - 3))
    Write-Host -NoNewline -back $titleBackground -fore $titleForeground $(" " * $Width)
    Write-Host
}

function Draw-SlideText($lines)
{
    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.x = 0
    $cursorPos.y = 4
    $Host.UI.RawUI.CursorPosition = $cursorPos

    for ($i = 1 ; $i -lt $lines.Count ; $i++ )
    {
        Write-Host " " $lines[$i]
    }
}


function Draw-Footer($slideNumber,$slideCount)
{
    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.y = $Height - 1
    $cursorPos.x = 0
    $Host.UI.RawUI.CursorPosition = $cursorPos

    $footer = "$slideNumber of $slideCount"
    Write-Host -NoNewline -back $titleBackground -fore $titleForeground "$(" " * ($Width - $footer.Length - 2)) $footer"
}

function Draw-BackScreen($message)
{
    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.x = 0
    $cursorPos.y = 0
    $Host.UI.RawUI.CursorPosition = $cursorPos

    $spaces = $(" " * $Width)
    for ($i = 0 ; $i -lt $Height ; $i++)
    {
        Write-Host -NoNewline -BackgroundColor black -ForegroundColor yellow $spaces
    }

    $cursorPos.x = ($Width / 2) - ($message.Length / 2)
    $cursorPos.y = 0
    $Host.UI.RawUI.CursorPosition = $cursorPos

    Write-Host -NoNewline -BackgroundColor black -ForegroundColor White $message
}

function Show-UsageHelp
{
    $help = @"
PowerShellPoint Help $scriptVersion - John Robbins - john@wintellect.com

Key             Action
---             ------
'n', '<space>'  Next slide
'p'             Previous slide
's'             Shell out to PowerShell
'h', '?'        This help
'q'             Quit

Press any key now to return to the current slide.
"@
    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.x = 0
    $cursorPos.y = 0
    $Host.UI.RawUI.CursorPosition = $cursorPos

    $spaces = $(" " * $Width)
    for ($i = 0 ; $i -lt $Height ; $i++)
    {
        Write-Host -NoNewline -BackgroundColor black -ForegroundColor yellow $spaces
    }

    $cursorPos.x = 0
    $cursorPos.y = 0
    $Host.UI.RawUI.CursorPosition = $cursorPos

    Write-Host -NoNewline -BackgroundColor black -ForegroundColor White $help
}

function main
{
    # Save off the original window data.
    $originalWindowSize = $Host.UI.RawUI.WindowSize
    $originalBufferSize = $Host.UI.RawUI.BufferSize
    $originalTitle     = $Host.UI.RawUI.WindowTitle
    $originalBackground = $Host.UI.RawUI.BackgroundColor
    $originalForeground = $Host.UI.RawUI.ForegroundColor

    # Make sure the file exists. If not, give the user a chance to
    # enter it.
    $File = Resolve-Path $File
    while(-not(Test-Path $File))
    {
        $File = Read-Host "Please enter the path of your slides file (Crtl+C to cancel)"
        $File = Resolve-Path $File
    }

    try
    {
        # Set the new window and buffer sizes to be the same so
        # there are no scroll bars.
        $scriptWindowSize = $originalWindowSize
        $scriptWindowSize.Width = $Width
        $scriptWindowSize.Height = $Height
        $scriptBufferSize = $scriptWindowSize

        $Host.UI.RawUI.BackgroundColor = $textBackGround
        $Host.UI.RawUI.ForegroundColor = $textForeGround


 
        # Set the title.
        $Host.UI.RawUI.WindowTitle = "PowerShellPoint"

        # Read in the file and build the slides hash.
        $slides = ProcessSlides($File)

        # The slides are good to go so now resize the window.
        $Host.UI.RawUI.WindowSize = $scriptWindowSize
        $Host.UI.RawUI.BufferSize = $scriptBufferSize

        # Keeps track of the slide we are on.
        [int]$currentSlideNumber = 1
        # The flag to break out of displaying slides.
        [boolean]$keepShowing = $true
        # Flag to avoid redrawing the screen for unknown keypresses.
        [boolean]$redrawScreen = $true

        do
        {
            if ($redrawScreen -eq $true)
            {
                Clear-Host

                # Grab the current slide.
                $slideData = $slides.$currentSlideNumber

                Draw-Title $slideData[0]
                Draw-SlideText $slideData
                Draw-Footer $currentSlideNumber $slides.Keys.Count
            }

            $char = Read-Char

            switch -regex ($char)
            {
                # Next slide processing.
                "[ ]|n"
                {
                    $redrawScreen = $true
                    $currentSlideNumber++

                    if ($currentSlideNumber -eq ($slides.Keys.Count + 1))
                    {
                        # Pretend you're PowerPoint and show the black screen
                        Draw-BackScreen "End of slide show"
                        $ch = Read-Char
                        if ($ch -eq "p")
                        {
                            $currentSlideNumber--    
                        }
                        else
                        {
                            $keepShowing = $false
                        }
                    }
                }
                # Previous slide processing.
                "p"
                {
                    $redrawScreen = $true
                    $currentSlideNumber--

                    if($currentSlideNumber -eq 0)
                    {
                        $currentSlideNumber = 1
                    }
                }
                # Quit processing.
                "q"
                {
                    $keepShowing = $false
                }

                "s"
                {
                    Clear-Host
                    Write-Host -ForegroundColor $titleForeground -BackgroundColor $titleBackground "Suspending PowerShellPoint - type 'Exit' to resume"


                   $Host.EnterNestedPrompt()
                }
                # Help processing.
                "h|\?"
                {
                    Show-UsageHelp
                    $redrawScreen = $true
                    Read-Char
                }
                # All other keys fall here.
                default
                {
                    $redrawScreen = $false
                }
            }
        } while ($keepShowing)

        # The script has finished cleanly so clear the screen.
        $Host.UI.RawUI.BackgroundColor = $originalBackground
        $Host.UI.RawUI.ForegroundColor = $originalForeground
        Clear-Host
    }    
    finally
    {
        # I learned something here. You have to set the buffer size before
        # you set the window size or the window won't resize.
        $Host.UI.RawUI.BufferSize = $originalBufferSize
        $Host.UI.RawUI.WindowSize = $originalWindowSize
        $Host.UI.RawUI.WindowTitle = $originalTitle
        $Host.UI.RawUI.BackgroundColor = $originalBackground
        $Host.UI.RawUI.ForegroundColor = $originalForeground
    }
}

. main

