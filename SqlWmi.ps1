gwmi SqlService -namespace root\Microsoft\SqlServer\ComputerManagement

# gwmi -query "select * from SqlService where SQLServiceType=1"  -namespace root\Microsoft\SqlServer\ComputerManagement
# SQLServiceType = 1	# SQL Server instances
# SQLServiceType = 2	# SQL Agent
# SQLServiceType = 3	# SQL Server FullText Search
# SQLServiceType = 4	# SQL Server SSIS Server  (DTS)
# SQLServiceType = 5	# SQL Server Analysis Services
# SQLServiceType = 6	# SQL Server Reporting Services
# SQLServiceType = 7	# SQL Server Browser
# SQLServiceType = 8	# SQL Server Notification Services

gwmi -namespace root\Microsoft\SqlServer\ReportServer\v9 MSReportServer_Instance


[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
$sqlsvr = new-object Microsoft.SqlServer.Management.Smo.Server "a-erichs-02"
$svrinfo = $sqlsvr.Information
"$($sqlsvr.Urn) has collation $($svrinfo.Collation)" # Server[@Name='A-ERICHS-02'] has collation SQL_Latin1_General_CP1_CI_AS


