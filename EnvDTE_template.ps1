# http://gallery.technet.microsoft.com/scriptcenter/9db8e065-bed4-4944-991f-058639b6de48
[void][System.Reflection.Assembly]::LoadWithPartialName("EnvDTE")

# If executed from the command line 
# PowerShell should be started with the -sta switch

# The function adds a C# class named MessageFilter
# to the PowerShell session
# See here for the source code and reason
# http://msdn.microsoft.com/en-us/library/ms228772(VS.80).aspx

function AddMessageFilterClass
{
$source = @"

namespace EnvDteUtils{

using System;
using System.Runtime.InteropServices;
    public class MessageFilter : IOleMessageFilter
    {
        //
        // Class containing the IOleMessageFilter
        // thread error-handling functions.

        // Start the filter.
        public static void Register()
        {
            IOleMessageFilter newFilter = new MessageFilter(); 
            IOleMessageFilter oldFilter = null; 
            CoRegisterMessageFilter(newFilter, out oldFilter);
        }

        // Done with the filter, close it.
        public static void Revoke()
        {
            IOleMessageFilter oldFilter = null; 
            CoRegisterMessageFilter(null, out oldFilter);
        }

        //
        // IOleMessageFilter functions.
        // Handle incoming thread requests.
        int IOleMessageFilter.HandleInComingCall(int dwCallType, 
          System.IntPtr hTaskCaller, int dwTickCount, System.IntPtr 
          lpInterfaceInfo) 
        {
            //Return the flag SERVERCALL_ISHANDLED.
            return 0;
        }

        // Thread call was rejected, so try again.
        int IOleMessageFilter.RetryRejectedCall(System.IntPtr 
          hTaskCallee, int dwTickCount, int dwRejectType)
        {
            if (dwRejectType == 2)
            // flag = SERVERCALL_RETRYLATER.
            {
                // Retry the thread call immediately if return >=0 & 
                // <100.
                return 99;
            }
            // Too busy; cancel call.
            return -1;
        }

        int IOleMessageFilter.MessagePending(System.IntPtr hTaskCallee, 
          int dwTickCount, int dwPendingType)
        {
            //Return the flag PENDINGMSG_WAITDEFPROCESS.
            return 2; 
        }

        // Implement the IOleMessageFilter interface.
        [DllImport("Ole32.dll")]
        private static extern int 
          CoRegisterMessageFilter(IOleMessageFilter newFilter, out 
          IOleMessageFilter oldFilter);
    }

    [ComImport(), Guid("00000016-0000-0000-C000-000000000046"), 
    InterfaceTypeAttribute(ComInterfaceType.InterfaceIsIUnknown)]
    interface IOleMessageFilter 
    {
        [PreserveSig]
        int HandleInComingCall( 
            int dwCallType, 
            IntPtr hTaskCaller, 
            int dwTickCount, 
            IntPtr lpInterfaceInfo);

        [PreserveSig]
        int RetryRejectedCall( 
            IntPtr hTaskCallee, 
            int dwTickCount,
            int dwRejectType);

        [PreserveSig]
        int MessagePending( 
            IntPtr hTaskCallee, 
            int dwTickCount,
            int dwPendingType);
    }
}
"@

Add-Type -TypeDefinition $source

}

# Add the MessageFilter class

AddMessageFilterClass

# Create the Visual Studio automation object

$IDE = New-Object -ComObject VisualStudio.DTE

# Call MessageFilter.Register before automation code

[EnvDTEUtils.MessageFilter]::Register()

# Automation code here
# Open a Visual Studio solution
# List the solution properties
# and each project properties

$IDE.Solution.Open("C:\Scripts\Test\Test.sln")
$IDE.MainWindow.Visible = $true
$IDe.UserControl = $true

"Visual Studio solution properties"

foreach($property in $IDE.Solution.Properties)
{
    "`t" + $property.Name + ' - ' + $property.Value
}

"`n`n"

foreach($project in $IDE.Solution.Projects)
{
    "Project " + $project.Name
    foreach($property in $project.Properties)
    {
       "`t" + $property.Name + ' - ' + $property.Value     
    }
}

$IDE.Quit()

# End automation code, revoke MessageFilter

[EnvDTEUtils.MessageFilter]::Revoke()