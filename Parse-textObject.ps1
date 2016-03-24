param([string] $parseExpression, [string[]] $propertyName, [type[]] $propertyType, [string] $delimiter, [switch] $unitTest) 

################################################################################################ 
## http://www.leeholmes.com/blog/parsetextObjectAWKWithAVengeance.aspx Edit 3
##    Parse-TextObject.ps1 -- Parse a simple string into a custom MshObject. 
## 
##    Parameters: 
##        [switch] unitTest 
##        Runs the unit tests.  Defaults to "false" 
## 
##        [string] delimiter 
##        If specified, gives the .NET Regular Expression with which to split the string. 
##        The script generates properties for the resulting object out of the elements resulting 
##        from this split. 
##        If not specified, defaults to splitting on the maximum amount of whitespace: "\s+", 
##        as long as ParseExpression is not specified either. 
## 
##        [string] parseExpression 
##        If specified, gives the .NET Regular Expression with which to parse the string. 
##        The script generates properties for the resulting object out of the groups captured by 
##        this regular expression. 
##         
##        ** NOTE ** Delimiter and ParseExpression are mutually exclusive. 
## 
##        [string[]] propertyName 
##        If specified, the script will pair the names from this object definition with the  
##        elements from the parsed string.  If not specified (or the generated object contains 
##        more properties than you specify,) the script adds notes in the pattern of 
##        Property1,Property2,...,PropertyN 
## 
##        [type[]] propertyType 
##        If specified, the script will pair the types from this list with the properties 
##        from the parsed string.  If not specified (or the generated object contains 
##        more properties than you specify,) the script sets the properties to be of type [string] 
## 
## 
##    Example usage: 
##        "Hello World" | parse-textobject 
##        Generates an Object with "Property1=Hello" and "Property2=World" 
## 
##        "Hello World" | parse-textobject -delimiter "ll" 
##        Generates an Object with "Property1=He" and "Property2=o World" 
## 
##        "Hello World" | parse-textobject -parseExpression "He(ll.*o)r(ld)" 
##        Generates an Object with "Property1=llo Wo" and "Property2=ld" 
## 
##        "Hello World" | parse-textobject -propertyName FirstWord,SecondWord 
##        Generates an Object with "FirstWord=Hello" and "SecondWord=World 
## 
##        "123 456" | parse-textobject -propertyType $([string],[int]) 
##        Generates an Object with "Property1=123" and "Property2=456" 
##              These properties are integers, as opposed to strings 
## 
## 
################################################################################################ 

function Main($inputObjects, $parseExpression, $propertyType, $propertyName, $delimiter, $unitTest) 
{ 
    if($unitTest -eq $true) 
    { 
        UnitTest 
        "" 
    }  
    else  
    { 
        $delimiterSpecified = [bool] $delimiter 
        $parseExpressionSpecified = [bool] $parseExpression 

        ## If they've specified both ParseExpression and Delimiter, show usage 
        if($delimiterSpecified -and $parseExpressionSpecified) 
        { 
            Usage 
            return 
        } 
         
        ## If they enter no parameters, assume a default delimiter of spaces 
        if(-not $($delimiterSpecified -or $parseExpressionSpecified)) 
        { 
            $delimiter = "\s+" 
            $delimiterSpecified = $true 
        } 
         
        ## Cycle through the $inputObjects, and parse it into objects 
        foreach($inputObject in $inputObjects) 
        { 
                        if(-not $inputObject) { $inputObject = "" } 
            foreach($inputLine in $inputObject.ToString()) 
            { 
                ParseTextObject $inputLine $delimiter $parseExpression $propertyType $propertyName 
            } 
        } 
    } 
} 

function Usage 
{ 
    "Usage: " 
    " parse-textobject" 
    " parse-textobject -unitTest" 
    " parse-textobject -objectDefinition objectDefinition" 
    " parse-textobject -parseExpression parseExpression -propertyName objectDefinition" 
    " parse-textobject -delimiter delimiter -propertyName objectDefinition" 
    return 
} 

## Function definition -- ParseTextObject. 
## Perform the heavy-lifting -- parse a string into its components. 
## for each component, add it as a note to the mshObject that we return 
function ParseTextObject 
{ 
    $textInput = $args[0] 
    $delimiter = $args[1] 
    $parseExpression = $args[2] 
        $propertyTypes = $args[3] 
    $propertyNames = $args[4] 
     
    $parseExpressionSpecified = -not $delimiter 
     
    $returnObject = new-mshobject 
     
    $matches = $null 
    $matchCount = 0; 
    if($parseExpressionSpecified) 
    { 
        ## Populates the matches variable by default 
        [void] ($textInput -match $parseExpression) 
        $matchCount = $matches.Count 
    } 
    else 
    { 
        $matches = [Regex]::Split($textInput, $delimiter) 
        $matchCount = $matches.Length 
    } 
     
    $counter = 0 
    if($parseExpressionSpecified) { $counter++ } 
    for(; $counter -lt $matchCount; $counter++) 
    { 
        $propertyName = "None" 
                $propertyType = [string] 

         
        ## Parse by Expression 
        if($parseExpressionSpecified) 
        { 
            $propertyName = "Property$counter" 
             
                        ## Get the property name 
            if($counter -le $propertyNames.Length) 
            { 
                if($propertyName[$counter - 1]) 
                { 
                    $propertyName = $propertyNames[$counter - 1]  
                } 
            } 

                        ## Get the property value 
            if($counter -le $propertyTypes.Length) 
            { 
                if($types[$counter - 1]) 
                { 
                    $propertyType = $propertyTypes[$counter - 1]  
                } 
            } 

        } 
        ## Parse by delimiter 
        else 
        { 
            $propertyName = "Property$($counter + 1)" 
             
                        ## Get the property name 
            if($counter -lt $propertyNames.Length)  
            { 
                if($propertyNames[$counter]) 
                { 
                    $propertyName = $propertyNames[$counter]  
                } 
            } 

                        ## Get the property value 
            if($counter -lt $propertyTypes.Length) 
            { 
                if($propertyTypes[$counter]) 
                { 
                    $propertyType = $propertyTypes[$counter]  
                } 
            } 
        } 

                add-note $returnObject $propertyName ($matches[$counter] -as $propertyType) 
    } 
     
    $returnObject 
} 


## Create a new mshObject 
function new-mshobject  
{ 
    new-object management.automation.PsObject 
} 

## Add a note to a mshObject 
function add-note ($object, $name, $value)  
{ 
    $object | add-member NoteProperty $name $value 
} 

## Unit testing helper 
function Assert 
{ 
    $message = $args[0] 
    $test = $args[1] 

    if($test -eq $false) 
    { 
        write-host "`n$message" 
    } 
    else 
    { 
        write-host -NoNewLine "." 
    } 
} 

## Unit tests 
function UnitTest 
{ 
    ## Mutually Exclusive 
    $return = parse-textobject -Delimiter:"aoe" -ParseExpression:"oeu" 
    Assert "Should have received a usage message" $($return[0].IndexOf("Usage:") -eq 0) 
     
    ## Custom Split 
    $return = "Hello World" | parse-textobject -ParseExpression:"(.*) (.*)" -PropertyName:First,Second 
    Assert "return-First should be 'Hello'" $($return.First -eq "Hello") 
    Assert "return-Second should be 'World'" $($return.Second -eq "World") 

    ## Custom Split, PropertyName overflow 
    $return = "Hello World" | parse-textobject -ParseExpression:"(.*) (.*)" -PropertyName:First,Second,Third 
    Assert "return-First should be 'Hello'" $($return.First -eq "Hello") 
    Assert "return-Second should be 'World'" $($return.Second -eq "World") 

    ## Custom Split Single 
    $return = "Hello" | parse-textobject -ParseExpression:"(.*)" -PropertyName:All 
    Assert "return-All should be 'Hello'" $($return.All -eq "Hello") 
     
    ## No Object Definition, parseExpression 
    $return = "Hello World" | parse-textobject -ParseExpression:"(.*) (.*)" 
    Assert "return-Property1 should be 'Hello'" $($return.Property1 -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 

    ## Insufficient Object Definition, parseExpression 
    $return = "Hello World" | parse-textobject -ParseExpression:"(.*) (.*)" -PropertyName:Hello 
    Assert "return-Hello should be 'Hello'" $($return.Hello -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 

    ## Insufficient Object Definition, parseExpression, with comma 
    $return = "Hello World" | parse-textobject -ParseExpression:"(.*) (.*)" -PropertyName:Hello 
    Assert "return-Hello should be 'Hello'" $($return."Hello" -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 
     
    ## Delimited split 
    $return = "Hello World" | parse-textobject -Delimiter:"[ \t]+" -PropertyName:First,Second 
    Assert "return-First should be 'Hello'" $($return.First -eq "Hello") 
    Assert "return-Second should be 'World'" $($return.Second -eq "World") 

    ## Delimited split, object definition overflow 
    $return = "Hello World" | parse-textobject -Delimiter:"[ \t]+" -PropertyName:First,Second,Third 
    Assert "return-First should be 'Hello'" $($return.First -eq "Hello") 
    Assert "return-Second should be 'World'" $($return.Second -eq "World") 
     
    ## No Object Definition, delimited 
    $return = "Hello World" | parse-textobject -Delimiter:"[ \t]+" 
    Assert "return-Property1 should be 'Hello'" $($return.Property1 -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 
     
    ## Insufficient Object Definition, delimited 
    $return = "Hello World" | parse-textobject -Delimiter:"[ \t]+" -PropertyName:Hello 
    Assert "return-Hello should be 'Hello'" $($return.Hello -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 

    ## Insufficient Object Definition, delimited, with comma 
    $return = "Hello World" | parse-textobject -Delimiter:"[ \t]+" -PropertyName:Hello 
    Assert "return-Hello should be 'Hello'" $($return.Hello -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 
     
    ## Header Examples 
    $return = "Hello World" | parse-textobject 
    Assert "return-Property1 should be 'Hello'" $($return.Property1 -eq "Hello") 
    Assert "return-Property2 should be 'World'" $($return.Property2 -eq "World") 
     
    $return = "Hello World" | parse-textobject -Delimiter "ll" 
    Assert "return-Property1 should be 'He'" $($return.Property1 -eq "He") 
    Assert "return-Property2 should be 'o World'" $($return.Property2 -eq "o World") 

    $return = "Hello World" | parse-textobject -ParseExpression "He(ll.*o)r(ld)" 
    Assert "return-Property1 should be 'llo Wo'" $($return.Property1 -eq "llo Wo") 
    Assert "return-Property2 should be 'ld'" $($return.Property2 -eq "ld") 

    $return = "Hello World" | parse-textobject -PropertyName FirstWord,SecondWord 
    Assert "return-FirstWord should be 'Hello'" $($return.FirstWord -eq "Hello") 
    Assert "return-SecondWord should be 'World'" $($return.SecondWord -eq "World") 

        $return = "123 456" | parse-textobject -PropertyType $([string],[int]) 
    Assert "return-Property1 should be '123'" $($return.Property1 -eq "123") 
    Assert "return-Property2 should be '456'" $($return.Property2 -eq 456) 
        Assert "return-Property2 should be [int]" $($return.Property2 -is [int]) 


        ## Bug fix 
    $return = $null | parse-textobject 
    Assert "return-Property1 should be ''" $($return.Property1 -eq "") 

        ## Parses with types 
    $return = "Hello 1234" | parse-textobject -PropertyType $([string],[int]) 
    Assert "return-Property1 should be 'Hello'" $($return.Property1 -eq "Hello") 
    Assert "return-Property2 should be '1234'" $($return.Property2 -eq 1234) 
        Assert "return-Property2 * 2 should be '2468'" $(($return.Property2 * 2) -eq 2468) 

        ## Type overflow, extras default to string 
    $return = "1234 5678" | parse-textobject -PropertyType $([int]) 
    Assert "return-Property1 should be '1234'" $($return.Property1 -eq 1234) 
    Assert "return-Property2 should be '5678'" $($return.Property2 -eq "5678") 
        Assert "return-Property1 * 2 should be '2468'" $(($return.Property1 * 2) -eq 2468) 
        Assert "return-Property2 * 2 should be '56785678'" $(($return.Property2 * 2) -eq "56785678") 
} 

Main $input $parseExpression $propertyType $propertyName $delimiter $unitTest
