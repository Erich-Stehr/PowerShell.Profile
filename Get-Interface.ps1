### get-interface <http://www.nivot.org/post/2009/03/26/PowerShell20CTP3ModulesInPracticeClosures>
function Get-Interface {

#.Synopsis
#   Allows PowerShell to call specific interface implementations on any .NET object. 
#.Description
#   Allows PowerShell to call specific interface implementations on any .NET object. 
#
#   As of v2.0, PowerShell cannot cast .NET instances to a particular interface. This makes it
#   impossible (shy of reflection) to call methods on explicitly implemented interfaces.   
#.Parameter Object
#   An instance of a .NET class from which you want to get a reference to a particular interface it defines.
#.Parameter InterfaceType
#   An interface type, e.g. [idisposable], implemented by the target object.
#.Example
#   // a class with explicitly implemented interface   
#   public class MyObj : IDisposable {
#      void IDisposable.Dispose()
#   }
#   
#   ps> $o = new-object MyObj
#   ps> $i = get-interface $o ([idisposable])
#   ps> $i.Dispose()      
#.ReturnValue
#   A PSCustomObject with ScriptMethods and ScriptProperties representing methods and properties on the target interface.
#.Notes
# AUTHOR:    Oisin Grehan http://www.nivot.org/
# LASTEDIT:  2009-03-28 18:37:23
# REVISION:  0.2
#.Example
#   $if = Get-Interface (new-object test) ([ifaceex]) -verbose
#   $if.Hello("Oisin") # returns Hello Oisin from IFaceEx
#   
#   $if.Prop1 = "Test" # property setter
#   $if.Prop1 # propery getter

    [CmdletBinding()]
    param(
        [ValidateNotNull()]
        $Object,
        
        [ValidateScript( { $_.IsInterface } )]
        [type]$InterfaceType
    )

    $script:t  = $Object.GetType()
    
    try {
        
        $script:m  = $t.GetInterfaceMap($InterfaceType)

    } catch [argumentexception] {
        
        throw "Interface $($InterfaceType.Name) not found on ${t}!"
    }

    $script:im = $m.InterfaceMethods
    $script:tm = $m.TargetMethods
    
    # TODO: use param blocks in functions instead of $args
    #       so method signatures are visible via get-member
    
    $body = {
         param($o, $i) 
         
         $script:t  = $o.GetType()
         $script:m  = $t.GetInterfaceMap($i)
         $script:im = $m.InterfaceMethods
         $script:tm = $m.TargetMethods
                  
         for ($ix = 0; $ix -lt $im.Count; $ix++) {
            
            $mb = $im[$ix]

            # for the function body, we close over $ix to capture the index
            # so even on the next iteration of this loop, the $ix value will
            # be frozen within the function's scriptblock body
            set-item -path function:script:$($mb.Name) -value {

                # call corresponding target method
                $tm[$ix].Invoke($o, $args)

            }.GetNewClosure() -verbose -force

            if (!$mb.IsSpecialName) {
                # only export the function if it is not a getter or setter.
                Export-ModuleMember $mb.Name -verbose
            }
         }
    }

    write-verbose $body.tostring()    
    
    # create dynamic module
    $module = new-module -ScriptBlock $body -Args $Object, $InterfaceType -Verbose
    
    # generate method proxies - all exported members become scriptmethods
    # however, we are careful not to export getters and setters.
    $custom = $module.AsCustomObject()
    
    # add property proxies - need to use scriptproperties here.
    # modules cannot expose true properties, only variables and 
    # we cannot intercept variables get/set.
    
    $InterfaceType.GetProperties() | % {

        $propName = $_.Name
        $getter   = $null
        $setter   = $null
       
        if ($_.CanRead) {
            
            # where is the getter methodinfo on the interface map?
            $ix = [array]::indexof($im, $_.GetGetMethod())
            
            # bind the getter scriptblock to our module's scope
            # and generate script to call target method
            #
            # NOTE: we cannot use a closure here because sessionstate
            #       is rebound to the module's, and $ix would be lost
            $getter = $module.NewBoundScriptBlock(
                [scriptblock]::create("`$tm[{0}].Invoke(`$o, @())" -f $ix))
        }
        
        if ($_.CanWrite) {
            
            # where is the setter methodinfo on the interface map?
            $ix = [array]::indexof($im, $_.GetSetMethod())
            
            # bind the setter scriptblock to our module's scope
            # and generate script to call target method
            #
            # NOTE: we cannot use a closure here because sessionstate
            #       is rebound to the module's, and $ix would be lost
            $setter = $module.NewBoundScriptBlock(
                [scriptblock]::create(
                    "param(`$value); `$tm[{0}].Invoke(`$o, `$value)" -f $ix))
        }
        
        # add our property to the pscustomobject
        $prop = new-object management.automation.psscriptproperty $propName, $getter, $setter
        $custom.psobject.properties.add($prop)
    }
    
    # insert the interface name at the head of the typename chain (for get-member info)
    $custom.psobject.TypeNames.Insert(0, $InterfaceType.FullName)
    
    # dump our pscustomobject to pipeline
    $custom
}
