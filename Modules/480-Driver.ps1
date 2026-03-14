## Milestone 5 ##

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

## Milestone 6 ##

# Utility function to start a VM or VMs by name 
# Call the function something different than the PowerCli command 


# Utility function that sets a VM network adapter
# To the network of choice

### 

