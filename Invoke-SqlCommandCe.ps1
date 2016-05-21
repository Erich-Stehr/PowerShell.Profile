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
##
## 20110122: added handling for SSCE
##   "${env:ProgramFiles}\Microsoft SQL Server Compact Edition\v3.5\Samples\Northwind.sdf"
##   SELECT Table_Name FROM INFORMATION_SCHEMA.TABLES
##   SELECT COLUMN_NAME AS Name, ORDINAL_POSITION AS Pos, IS_NULLABLE AS Nulls, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH AS Len FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Employees'
## 20110614: extend for Oracle, correct for updated/x64 Jet driver, 
##		include tableNamesOnly to dump table/sheet names from OLEDB schema
##		Note: no schema if xls* file not found
##	 "C:\Users\erich Stehr\Documents\Supportmetadata-Cleaned.xlsx" -sql 'select * from [Trimmed2$]' -tableNames
##	 LOUT "" -provider 'OraOLEDB.Oracle' -credential $oraCred -sql 'SELECT * FROM MAC_ITEM_CATEGORIES_V WHERE CATEGORY_SET_ID = 10 AND CATEGORY_SEGMENT2 != ''UNASSIGNED'' AND ORGANIZATION_ID = 9' #xxxlousp@//db90.coresys.com:45001/LOUT 
## 20160520: note re: LocalDb use
##	Invoke-SqlCommandCe.ps1 -provider SQLNCLI11 -dataSource '(localdb)\mssqllocaldb' -database master

param(
    [string] $dataSource = ".\SQLEXPRESS",
    [string] $database = "Northwind",      
    [string] $sqlCommand = $null, #$(throw "Please specify a query."),
    [string] $provider = "sqloledb",
    [string] $sdfProviderVersion = "3.5",
    [switch] $tableNamesOnly = $false,
    [System.Management.Automation.PsCredential] $credential
  )
  
if ([string]::IsNullOrEmpty($sqlCommand) -and !$tableNamesOnly) { throw "Please specify a query." }

## Prepare the authentication information. By default, we pick
## Windows authentication
$authentication = "Integrated Security=SSPI"

## If the user supplies a credential, then they want SQL
## authentication
if($credential)
{
    $plainCred = $credential.GetNetworkCredential()
    $authentication = 
        ("User Id={0}; Password={1}" -f $plainCred.Username,$plainCred.Password)
}

## Prepare the connection string out of the information they
## provide
$connectionString = "Provider=$provider; " +
                    $(if (![String]::IsNullOrEmpty($dataSource)) { "Data Source=$dataSource; " } else {""}) +
                    $(if (![String]::IsNullOrEmpty($database)) { "Initial Catalog=$database; " } else {""}) +
                    "$authentication; "

## If they specify an Access database or Excel file as the connection
## source, modify the connection string to connect to that data source
if($dataSource -match '\.xlsx?$|\.mdb$')
{
	if (Test-Path 'HKLM:\SOFTWARE\Classes\Microsoft.ACE.OLEDB.12.0') { 
		# 64-bit capable, Office 2007/12/xlsx capable
    	$connectionString = "Provider=Microsoft.ACE.OLEDB.12.0; Data Source=$dataSource; "
		$script:providerVersion = "12.0"
	} elseif (Test-Path 'HKLM:\SOFTWARE\Classes\Microsoft.Jet.OLEDB.4.0') { 
		# 32-bit only, Office 97/8/xls capable
    	$connectionString = "Provider=Microsoft.Jet.OLEDB.4.0; Data Source=$dataSource; "
		$script:providerVersion = "8.0"
	} else {
		throw "Can't find OLEDB driver for Excell sheets!"
	}

    if($dataSource -match '\.xlsx?$')
    {
		$connectionString += "Extended Properties=`"Excel ${providerVersion};HDR=Yes;IMEX=0;`"; "
		#;HDR=Yes;IMEX=1 

        ## Generate an error if they didn't specify the sheet name properly
        if (($sqlCommand -notmatch '\[.+\$\]') -and !$tableNamesOnly)
        {
            $error = 'Sheet names should be surrounded by square brackets, and ' +
                       'have a dollar sign at the end: [Sheet1$]'
            Write-Error $error
            return
        }
    }
}
elseif ($dataSource -match '\.sdf$')
{
    # assistance from http://www.connectionstrings.com/sql-server-2005-ce
    $connectionString = "Provider=Microsoft.SQLSERVER.CE.OLEDB.${sdfProviderVersion}; " +
                    "Data Source=$dataSource; " +
                    "Persist Security Info=False; "
}

## Connect to the data source and open it
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
$connection.Open()
if ($tableNamesOnly)
{
	$connection.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables, $null)
	$connection.Close()
	return;
}
$command = New-Object System.Data.OleDb.OleDbCommand $sqlCommand,$connection


## Fetch the results, and close the connection
$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
$dataset = New-Object System.Data.DataSet
[void] $adapter.Fill($dataSet)
$connection.Close()

## Return all of the rows from their query
$dataSet.Tables | Select-Object -Expand Rows