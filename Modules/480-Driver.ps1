Import-Module '480-Utils' -Force
#Call the function
480Connect
$conf = Get-480Config -config_path "/home/admin/Senior-Spring-SEC-480-01-Advanced-Topics-in-Cyber-Security.480.json"
480Connect -server $conf.vcenter_server
Write-Host "Selecting your VM..."
Select-VM -folder "PROD"