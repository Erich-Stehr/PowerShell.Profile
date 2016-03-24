##############################################################################
##
## Get-TSqlImageColumn.ps1
##
## cut down and altered From Windows PowerShell Cookbook (O'Reilly)
## by Lee Holmes (http://www.leeholmes.com/guide)
## <http://www.leeholmes.com/blog/InteractingWithSQLDatabasesInPowerShellInvokeSqlCommand.aspx> 2007/10/18
##
## Return the results of a SQL query or operation
##
## ie:
##
##    ## Use Windows authentication
##    .\Get-TSqlImageColumn.ps1 "." "WSS_Content" "table" "column" "ID = '{}'" foo.bin
##
##
##############################################################################

param(
    [string] $dataSource = ".\SQLEXPRESS",
    [string] $database = "Northwind",      
    [string] $tableName = $(throw 'Please specify a tableName'),      
    [string] $columnName = $(throw 'Please specify a columnName'),      
    [string] $whereClause = $(throw "Please specify a where clause."),
    [string] $fileName = $(throw "Please specify a filename.")
  )

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Data")

## Prepare the authentication information. By default, we pick
## Windows authentication
$authentication = "Integrated Security=SSPI;"

## Prepare the connection string out of the information they
## provide
$connectionString = "Data Source=$dataSource; " +
                    "Initial Catalog=$database; " +
                    $authentication


## Connect to the data source and open it
$sqlCommand = "SELECT $columnName FROM $tableName WHERE $whereClause"
$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$command = New-Object System.Data.SqlClient.SqlCommand $sqlCommand,$connection
$connection.Open()

## Fetch the results, and close the connection
$reader = $command.ExecuteReader()
$i = 0;
while ($reader.Read()) {
	$sqlBytes = $reader.GetSqlBytes(0)
	"$pwd\$filename.$i $($sqlBytes.length)" 
	$sqlBytes.Buffer | set-content -encoding byte -path "$pwd\$filename.$i"
	$i ++
}


$reader.Close()
$command.Dispose()
$connection.Close()

# .\get-TSqlImageColumn.ps1 revere WSS_Content "dbo.WebParts" tp_PerUserProperties "tp_PerUserProperties IS NOT NULL" tpUserProps