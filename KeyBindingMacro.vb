Imports System
Imports EnvDTE
Imports EnvDTE80
Imports EnvDTE90
Imports System.Diagnostics

Public Module Module1
    Function GetOutputWindowPane(ByVal Name As String, Optional ByVal show As Boolean = True) As OutputWindowPane
        Dim window As Window
        Dim outputWindow As OutputWindow
        Dim outputWindowPane As OutputWindowPane

        window = DTE.Windows.Item(EnvDTE.Constants.vsWindowKindOutput)
        If show Then window.Visible = True
        outputWindow = window.Object
        Try
            outputWindowPane = outputWindow.OutputWindowPanes.Item(Name)
        Catch e As System.Exception
            outputWindowPane = outputWindow.OutputWindowPanes.Add(Name)
        End Try
        outputWindowPane.Activate()
        Return outputWindowPane
    End Function

    Sub ListCommands()
        Dim outwin As OutputWindowPane = GetOutputWindowPane("List Commands", True)
        outwin.Clear()

        For Each cmd As Command In DTE.Commands
            Dim bindings() As Object
            bindings = cmd.Bindings
            For Each binding As String In bindings
                outwin.OutputString(cmd.Name.ToString() + vbTab + binding + vbCrLf)
            Next
        Next
    End Sub
End Module