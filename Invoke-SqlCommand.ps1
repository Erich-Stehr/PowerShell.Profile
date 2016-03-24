##############################################################################
##
## Invoke-SqlCommand.ps1
##
## From Windows PowerShell Cookbook (O'Reilly)
## by Lee Holmes (http://www.leeholmes.com/guide)
## <http://www.leeholmes.com/blog/InteractingWithSQLDatabasesInPowerShellInvokeSqlCommand.aspx> 2007/10/18
##
## Return the results of a SQL query or operation
##
## ie:
##
##    ## Use Windows authentication
##    Invoke-SqlCommand.ps1 -Sql "SELECT TOP 10 * FROM Orders"
##
##    ## Use SQL Authentication
##    $cred = Get-Credential
##    Invoke-SqlCommand.ps1 -Sql "SELECT TOP 10 * FROM Orders" -Cred $cred
##
##    ## Perform an update
##    $server = "MYSERVER"
##    $database = "Master"
##    $sql = "UPDATE Orders SET EmployeeID = 6 WHERE OrderID = 10248"
##    Invoke-SqlCommand $server $database $sql
##
##    $sql = "EXEC SalesByCategory 'Beverages'"
##    Invoke-SqlCommand -Sql $sql
##
##    ## Access an access database
##    Invoke-SqlCommand (Resolve-Path access_test.mdb) -Sql "SELECT * FROM Users"
##    
##    ## Access an excel file
##    Invoke-SqlCommand (Resolve-Path xls_test.xls) -Sql 'SELECT * FROM [Sheet1$]'
##
##############################################################################

param(
    [string] $dataSource = ".\SQLEXPRESS",
    [string] $database = "Northwind",      
    [string] $sqlCommand = $(throw "Please specify a query."),
    [System.Management.Automation.PsCredential] $credential
  )


## Prepare the authentication information. By default, we pick
## Windows authentication
$authentication = "Integrated Security=SSPI;"

## If the user supplies a credential, then they want SQL
## authentication
if($credential)
{
    $plainCred = $credential.GetNetworkCredential()
    $authentication = 
        ("uid={0};pwd={1};" -f $plainCred.Username,$plainCred.Password)
}

## Prepare the connection string out of the information they
## provide
$connectionString = "Provider=sqloledb; " +
                    "Data Source=$dataSource; " +
                    "Initial Catalog=$database; " +
                    "$authentication; "

## If they specify an Access database or Excel file as the connection
## source, modify the connection string to connect to that data source
if($dataSource -match '\.xls$|\.mdb$')
{
    $connectionString = "Provider=Microsoft.Jet.OLEDB.4.0; Data Source=$dataSource; "

    if($dataSource -match '\.xls$')
    {
        $connectionString += 'Extended Properties="Excel 8.0;"; '

        ## Generate an error if they didn't specify the sheet name properly
        if($sqlCommand -notmatch '\[.+\$\]')
        {
            $error = 'Sheet names should be surrounded by square brackets, and ' +
                       'have a dollar sign at the end: [Sheet1$]'
            Write-Error $error
            return
        }
    }
}

## Connect to the data source and open it
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
$command = New-Object System.Data.OleDb.OleDbCommand $sqlCommand,$connection
$connection.Open()

## Fetch the results, and close the connection
$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
$dataset = New-Object System.Data.DataSet
[void] $adapter.Fill($dataSet)
$connection.Close()

## Return all of the rows from their query
$dataSet.Tables | Select-Object -Expand Rows