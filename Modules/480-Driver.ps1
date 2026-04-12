## Milestone 5 ##

# Call upon the function 
Import-Module '480-Utils' -Force

# Grabbing the path that holds the .json file
$conf = Get-480Config -config_path "./480.json"

# Calling 480Connect Function
480Connect -server $conf.vcenter_server

# Write-Host "Selecting your VM..."

# Calling Createclone Function
#CreateClone -conf $conf 

# Removed Select-VM -folder "PROD", 
# since CreateClone function calls Select-VM, 
# don't need it twice in here! 

## Milestone 6 ##

# Calling New Network Function
#NewNetwork -conf $conf 

# Calling GetIP function 
#GetIP -conf $conf

# Start VM function
#StartVM -conf $conf 

# Stop VM function
#StopVM -conf $conf

# Calling SetNetwork Function
#SetNetwork -conf $conf 


