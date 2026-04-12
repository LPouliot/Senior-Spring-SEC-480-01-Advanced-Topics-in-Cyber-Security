## Milestone 5 ##
function 480Connect([string]$server)
{
    $conn = $global:DefaultVIServer
    # Checking for connection
    if ($conn){
        $msg = "Already connected to: {0}" -f $conn
        Write-Host -ForegroundColor Green $msg
    }else{
        $conn = Connect-VIServer -Server $server
        # If this fails, Connect-VIServer will handle it.
    }
}

function Get-480Config([string] $config_path)
{
    Write-Host "Reading " $config_path
    $conf = $null
    if(Test-Path $config_path){
        $conf = (Get-Content -Raw -Path $config_path | ConvertFrom-Json)
        $msg = "Using Configuration at {0}" -f $config_path 
        Write-Host -ForegroundColor Green $msg
    }else{
        Write-Host -ForegroundColor Yellow "No Configuration found at $config_path"
    }
    return $conf
}

function Select-VM([string] $folder)
{
    Write-Host "Selecting a VM:" -ForegroundColor DarkCyan
    $selected_vm = $null
    try 
    {
        $vms = Get-VM -Location (Get-Folder -Name $folder)
        $index = 1
        foreach($vm in $vms)
        {
            Write-Host [$index] $vm.Name
            $index += 1
        }
        $pick_index = Read-Host "Which index number [x] do you wish to pick?"
        if($pick_index -ge 1 -and $pick_index -le $vms.Count){
            $selected_vm = $vms[$pick_index - 1]
            Write-Host "You picked " $selected_vm.Name
            return $selected_vm
        }else{
            Write-Host "Invalid input. Try a number from 1 to $($vms.Count)." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Invalid Folder: $folder" -ForegroundColor Red
    }
}

function CreateClone([PSCustomObject]$conf)
{
    # Pick the source VM from the PROD folder 

    Write-Host "`nSelect the source VM to clone from:" -ForegroundColor Cyan
    $folderName = if ($conf -and $conf.folder) { $conf.folder } else { Read-Host "Enter the VM folder name" }
    $vm = Select-VM -folder $folderName

    if (-not $vm) {
        Write-Host "No VM selected. Aborting." -ForegroundColor Red
        return
    }

    # Ask the user what to name the new clone

    $CloneName = Read-Host "Enter the name for the new clone"

    # Ask if Full or Linked? 

    $CloneType = Read-Host "Clone type: enter 'Full' or 'Linked'"

    # Resolve any config values. if missing any, ask via read-host
    $SnapshotName = if ($conf -and $conf.SnapshotName) { 
        $conf.SnapshotName 
    }else{ 
        Read-Host "Enter the snapshot name to clone from" 
    }
    $VmHostName   = if ($conf -and $conf.VmHostName) { 
        $conf.VmHostName 
    }else{ 
        Read-Host "Enter the ESXi host (IP or hostname)" 
    }
    $DatastoreName= if ($conf -and $conf.DatastoreName) { 
        $conf.DatastoreName 
    }else{ 
        Read-Host "Enter the datastore name" 
    }
    $NetworkName  = if ($conf -and $conf.NetworkName) { 
        $conf.NetworkName 
    }else{
        Read-Host "Enter the network/portgroup name" 
    }
    $BaseFolderName   = if ($conf -and $conf.BaseFolderName) { 
        $conf.BaseFolderName 
    }else{ 
        Read-Host "Enter the BASE-VMs folder name" 
    }
    $LinkedFolderName = if ($conf -and $conf.LinkedFolderName) { 
        $conf.LinkedFolderName 
    }else{ 
        Read-Host "Enter the LINKED-VMs folder name" 
    }

    # Gather vCenter objects 

    $snapshot = Get-Snapshot -VM $vm -Name $SnapshotName
    $vmhost   = Get-VMHost   -Name $VmHostName
    $datastore= Get-Datastore -Name $DatastoreName

    # The clone action, similar to the last milestone

    if ($CloneType -eq "Full") {
        Write-Host "`nCreating temporary linked clone..." -ForegroundColor Cyan

        # create a tempory linked clone from the Base snapshot
        $TempLinkedName = "{0}.linked.tmp" -f $vm.Name
        $linkedvm = New-VM -LinkedClone `
                           -Name $TempLinkedName `
                           -VM $vm `
                           -ReferenceSnapshot $snapshot `
                           -VMHost $vmhost `
                           -Datastore $datastore

        Write-Host "Moving to full clone '$CloneName'..." -ForegroundColor Cyan

        # created a full clone from the temp linked clone
        $newvm = New-VM -Name $CloneName `
                        -VM $linkedvm `
                        -VMHost $vmhost `
                        -Datastore $datastore

        # Snapshot the new full clone so it replicates the base
        $newvm | New-Snapshot -Name $SnapshotName

        # clean up and remove the temp linked clone
        try{
            $linkedvm | Remove-VM -Confirm:$false
            Write-Host "Temporary Linked clone has been removed" -ForegroundColor Green
        }catch{
            Write-Host "Warning: Could not be done, delete manually" -ForegroundColor Yellow
        }
        

        # move into BASE-VMs folder
        Move-VM -VM $newvm -InventoryLocation (Get-Folder -Name $BaseFolderName)

        Write-Host "Full clone '$CloneName' created and placed in '$BaseFolderName'." -ForegroundColor Green

    }elseif ($CloneType -eq "Linked") {
        Write-Host "`nCreating linked clone '$CloneName'..." -ForegroundColor Cyan

        # create linked clone from the Base snapshot
        $linkedvm = New-VM -LinkedClone `
                           -Name $CloneName `
                           -VM $vm `
                           -ReferenceSnapshot $snapshot `
                           -VMHost $vmhost `
                           -Datastore $datastore

        # attach to the correct network
        $linkedvm | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $NetworkName -Confirm:$false

        # move into LINKED-VMs folder
        Move-VM -VM $linkedvm -InventoryLocation (Get-Folder -Name $LinkedFolderName)

        Write-Host "Linked clone '$CloneName' created and placed in '$LinkedFolderName'." -ForegroundColor Green

    }else{
        Write-Host "'$CloneType' is not a valid clone type. Please enter 'Full' or 'Linked'." -ForegroundColor Red
    }
}

## Milestone 6 #### 

# Function that creates a new Virtual Switch and Portgroup
# Asks the user the new name for both

function NewNetwork([PSCustomObject]$conf) 
{
    $VmHost = Get-VMHost -Name $conf.VmHostName # Resolves the Host IP into an object for New-VirtualSwitch to use
    $SwitchName = Read-Host "Enter the name of the new Virtual Switch/Network"
    New-VirtualSwitch -VMHost $VmHost -Name $SwitchName
    $PortName = Read-Host "Enter the name of the new Virtual Port"
    New-VirtualPortGroup -VirtualSwitch $SwitchName -Name $PortName
}

# Function that gets the Network, IP and MAC address of the *first* interface
# of a named (specific) VM 

function GetIP([PSCustomObject]$conf)
{
    $chosen_vm = Select-VM -folder $conf.folder # Runs Select-VM function and Selects a folder to search through 
    $details = Get-NetworkAdapter -VM $chosen_vm
    Write-Host `n"Network   | " -ForegroundColor DarkCyan -NoNewline 
    Write-Host $details.NetworkName
    Write-Host "MAC Address | " -ForegroundColor DarkCyan -NoNewline 
    Write-Host $details.MacAddress
    Write-Host "IP Address  | " -ForegroundColor DarkCyan -NoNewline 
    Write-Host $chosen_vm.guest.ipaddress[0]
}

# Function that will start a VM or VMs by name
# Finally figured out a working loop! Using do and while! 

function StartVM([PSCustomObject]$conf)
{
    do{
        $Answer = Read-Host "Do you want to start a VM? [Y] [N]"
        if($Answer -eq 'Y'){
            $pickedVM = Select-VM -folder $conf.folder
            Start-VM -VM $pickedVM
            Write-Host "VM has been Started" -ForegroundColor Green
        }elseif($Answer -eq 'N'){
            Write-Host "Ending Function" -ForegroundColor Yellow
        }else{
            Write-Host "Imput did not match Y or N" -ForegroundColor Red
        }
    } while ($Answer -ne 'N')
}

# Function that will stop a VM or VMs by name
function StopVM([PSCustomObject]$conf)
{
    do{
        $Answer = Read-Host "Do you want to stop a VM? [Y] [N]"
        if($Answer -eq 'Y'){
            $pickedVM = Select-VM -folder $conf.folder
            Stop-VM -VM $pickedVM
            Write-Host "VM has been Stopped" -ForegroundColor Green
        }elseif($Answer -eq 'N'){
            Write-Host "Ending Function" -ForegroundColor Yellow
        }else{
            Write-Host "Imput did not match Y or N" -ForegroundColor Red
        }
    } while ($Answer -ne 'N')
}

# Function that sets a VM network adapter on different interfaces
# To the network of choice
function SetNetwork([PSCustomObject]$conf)
{
    Write-Host "Choosing a Network and Adapter" -ForegroundColor Cyan
    # Shows and lets the user choose a network
    $chosenVM = Select-VM -folder $conf.folder
    # Checker to see if a VM has been selected, returns if none is found
    if (-not $chosenVM){
        Write-Host "No VM Selected" -ForegroundColor Red
        return 
    }
        Write-Host "Available Networks:" -ForegroundColor DarkCyan
        try {
            $networks = Get-VirtualNetwork
            $index = 1
            foreach ($network in $networks){ #creating a loop to show all networks options
                Write-Host [$index] $network.Name
                $index++
            }
            $NetPick = Read-Host "Which network index [x] would you like?"
            # Ensures the user entered a valid number within the list range 
            if ($NetPick -ge 1 -and $NetPick -le $networks.Count){
            # Grabs the actual network from the array, first position is at 0 not 1
                $ChosenNetwork = $networks[$NetPick - 1] 
                Write-Host "Selected: $ChosenNetwork" -ForegroundColor DarkCyan
            }else{
                Write-Host "Invalid, try again" -ForegroundColor Yellow
                return
            }
        }catch{
            Write-Host "Could not grab the networks" -ForegroundColor Red
        }

    # Shows the adapters on the VM and lets the user pick one 
    Write-Host "Available Adapters" -ForegroundColor DarkCyan
    $adapters = Get-NetworkAdapter -VM $chosenVM
    $adapterIndex = 1
    foreach ($adapter in $adapters){
        Write-Host [$adapterIndex] "$($adapter.Name) | Currently: $($adapter.NetworkName)"
        $adapterIndex++
    }
    $adapterPick = Read-Host "Which adapter index [x] would you like to assign $ChosenNetwork to?"
    if ($adapterPick -ge 1 -and $adapterPick -le $adapters.Count){
        $SelectedAdapter = $adapters[$adapterPick - 1]

        # Applying the network to the adapter 
        Set-NetworkAdapter -NetworkAdapter $SelectedAdapter `
                            -NetworkName $ChosenNetwork.Name `
                            -Confirm:$false
        Write-Host "The Network $ChosenNetwork has been placed into $SelectedAdapter" -ForegroundColor Green
    }else{
        Write-Host "Invalid adapter" -ForegroundColor Yellow
    }
}

## Milestone 9 ##

# Function that set a static IP fpr windows systems 
# By ysing the Invoke-VMScript Powercli 
# Can call an OS command like Netsh and setup guest credentials

function SetWindowsIP([PSCustomObject]$conf)
{
$select_vm = Select-VM # Grabbing a VM from the other function
$user = Read-Host "Enter the username of" $select_vm.name # Grabbing the username
$pass = Read-Host -AsSecureString "Enter the password of $user" # Securly grabbing the password
$credential = [PScredential]::new($user,$pass) #storing the user and pass as a single credential object
$setIpAddr = 'netsh interface ip set address "eth1" static 10.0.5.5 255.255.255.0 10.0.5.2 10.0.5.2' # Setting Static IP, netmask, gateway, nameserver
$setDnsServer = 'netsh interface ip set dnsservers "eht1" static 10.0.5.2' # setting dns server
Invoke-VMScript -VM $select_vm "$setIpAddr $setDnsServer" -GuestCredential $credential # using Invoke-VMScript to run a script in the guest OS, setting what was specified in the varibles
}