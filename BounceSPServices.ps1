$activeServices = get-service |
	? { $_.DisplayName.StartsWith('SharePoint') } |
	? { $_.Status -eq 'Running' }
$activeServices | 
	% { net stop $_.Name }
IISreset
$activeServices | 
	% { net start $_.Name }
