Import-Module '480-Utils' -Force
# Call upon the function 

# 480Connect (no longer needed)

$conf = Get-480Config -config_path "./480.json"

480Connect -server $conf.vcenter_server

Write-Host "Selecting your VM..."
CreateClone -conf $conf 

# Removed Select-VM -folder "PROD", 
# since CreateClone function calls Select-VM, 
# don't need it twice in here! 