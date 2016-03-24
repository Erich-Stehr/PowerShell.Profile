Get-WmiObject  -query 'select * from SqlService where ServiceName=''MSSQL$STANDARD''' -namespace root\Microsoft\SqlServer\ComputerManagement -computername a-erichs-02

Get-WmiObject  -query 'select * from MSReportServer_Instance where InstanceName=''STANDARD'' AND ReportManagerUrl<>'''' AND ReportServerUrl<>''''' -namespace root\Microsoft\SqlServer\ReportServer\v9 -computername a-erichs-02

Get-WmiObject  -query 'select * from SqlService where ServiceName=''MSSQL$STANDARD'' AND State=4' -namespace root\Microsoft\SqlServer\ComputerManagement -computername a-erichs-02
