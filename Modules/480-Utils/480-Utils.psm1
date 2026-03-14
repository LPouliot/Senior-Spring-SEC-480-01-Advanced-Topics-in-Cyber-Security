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
    $selected_vm = $null
    try 
    {
        $vms = Get-VM -Location $folder
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
    $folderName = if ($conf -and $conf.vm_folder) { $conf.vm_folder } else { Read-Host "Enter the VM folder name" }
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

function NewNetwork([PSCustomObject]$conf) #Is PsCustomObject needed? 
{
    $SwitchName = Read-Host "Enter the name of the new Virtual Switch/Network"
    New-VirtualSwitch -VMHost $vmhost.vm_host -Name $SwitchName
    $PortName = Read-Host "Enter the name of the new Virtual Port"
    New-VirtualPortGroup -VirtualSwitch $SwitchName -Name $PortName
}

# Function that gets the Network, IP and MAC address of the *first* interface
# of a named (specific) VM 

function GetIP(){
    $chosen_vm = CreateClone
    $details = Get-NetworkAdapter -VM $chosen_vm
    Write-Host `n"Network | " -ForegroundColor DarkCyan -NoNewline 
    Write-Host $details.NetworkName
    Write-Host "MAC Address | " -ForegroundColor DarkCyan -NoNewline 
    Write-Host $details.MacAddress
    Write-Error "IP Address | " -ForegroundColor DarkCyan -NoNewline 
    Write-Host $chosen_vm.guest.ipaddress[0]
}

