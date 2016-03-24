# <http://keithhill.spaces.live.com/blog/cns!5A8D2641E0963A97!186.entry>, updated to PS RC1 in comments
begin {
    $props = @{ 
        Name = 0; 
        Size = 1; 
        Type = 2; 
        DateModified = 3; 
        DateCreated = 4;
        DateAccessed = 5; 
        Attributes = 6; 
        Status = 7; 
        Owner = 8; 
        Author = 9;
        Title = 10; 
        Subject = 11; 
        Category = 12; 
        Pages = 13; 
        Comments = 14;
        Copyright = 15; 
        Artist = 16; 
        AlbumTitle = 17; 
        Year = 18; 
        TrackNumber = 19;
        Genre = 20; 
        Duration = 21; 
        BitRate = 22; 
        Protected = 23; 
        CameraModel = 24;
        DatePictureTaken = 25; 
        Dimensions = 26;
        Company = 30; 
        Description = 31; 
        FileVersion = 32;
        ProductName = 33; 
        ProductVersion = 34
    }
    
    function add-member {
        param($type, $name, $value, $input)
        $note = "system.management.automation.psnoteproperty"
        $member = new-object $note $name,$value
        $metaInfoObj.psobject.members.add($member)
        return $metaInfoObj
    }
    
    function emitMetaInfoObject($path) {
        [string]$path = (resolve-path $path).path
        [string]$dir  = split-path $path
        [string]$file = split-path $path -leaf
        $shellApp = new-object -com shell.application
        $myFolder = $shellApp.Namespace($dir)
        $fileobj = $myFolder.Items().Item($file)
        
        $metaInfoObj = new-object system.management.automation.psobject
        $metaInfoObj.psobject.typenames[0] = "Custom.IO.File.Metadata"
        $metaInfoObj = add-member noteproperty Path $path -input $metaInfoObj
        foreach ($key in $props.keys) {
            $v = $myFolder.GetDetailsOf($fileobj,$props.$key)
            if ($v) { 
                $metaInfoObj = add-member noteproperty $key $v -input $metaInfoObj 
            }
        }
        write-output $metaInfoObj
    }
}
process {
    if ($_) {
        emitMetaInfoObject $_
    }
}
end {
    if ($args) {
        $paths
        foreach ($path in $args) {
            if (!(test-path $path)) {
                write-error "$path is not a valid path"
            }
            $paths += resolve-path $path
        }
    
        foreach ($path in $paths) {
            emitMetaInfoObject $path
        }
    }
}

