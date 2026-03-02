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
    $conf=$null
    if(Test-Path $config_path){
        $conf = (Get-Content -Raw -Path $config_path | ConvertFrom-Json)
        $msg - "Using Configutation at {0}" -f $config_path
    }else{
        Write-Host -ForegroundColor "Yellow" "No Configuration"
    }
    return $conf
}

function Select-VM([string] $folder)
{
    $selected_vm=$null
    try 
    {
        $vms = Get-VM -Location $folder
        $index = 1
        foreach($vm in $vms)
        {
            Write-Host [$index] $vm.Name
            $index+=1
        }
        $pick_index = Read-Host "Which index number [x] do you wish to pick?"
        if($pick_index -ge 1 -and $pick_index -le $vms.Count){
            $selected_vm = $vms[$pick_index -1]
            Write-Host "You picked " $selected_vm.name
            # Note this is a full on vm object that is interactable
            return $selected_vm
        }else{
            Write-Host "Invalid input. Try a number through 1 to 4." -ForegroundColor "Yellow:"
        }
    }
    catch {
        Write-Host "Invalid Folder: $folder" -ForegroundColor "Red"
    }
}

# Milestone 5 Function below 
function CreateClone()
{
    $VMName = Read-Host "Enter the name of the VM to be cloned"
    $CloneName = Read-Host "Enter the name of the new Clone"
    $CloneType = Read-Host "Would you like a Full or Linked type" 
    
    $vm = Get-VM -Name $VMName
    $snapshot = Get-Snapshot -VM $vm -Name $SnapshotName
    $vmhost = Get-VMHost -Name $VmHostName
    $ids = Get-Datastore -Name $DatastoreName

    # Else if statement

    # If the user chooses Full
    if ($CloneType -eq "Full") {
        # Create a temp Linked Clone
        $TempLinkedName = "{0}.linked" -f $vm.name
        $linkedvm = New-VM -LinkedClone -Name $TempLinkedName -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ids
        # Change to Full Base Clone
        $newvm = New-VM -Name $CloneName -VM $linkedvm -VMHost $vmhost -Datastore $ids
        # Snapshot the VM and remove linked clone
        $newvm | new-Snapshot -Name $SnapshotName
        $linkedvm | Remove-VM -Confirm:$false
        # Move into BASE VMs folder
        Move-VM -VM $newvm -InventoryLocation (Get-Folder -Name $BaseFolderName)
        # Write that it was completed! 
        Write-Host "Full clone '$CloneName' created and placed in '$BaseFolderName'."
    }
    # Now if the user chooses Linked
    elseif ($CloneType -eq "Linked") {
        # Create the linked clone
        $linkedvm = New-VM -LinkedClone -Name $CloneName -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ids
        # Set Network Adapter
        $linkedvm | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $NetworkName
        # Move into LINKED VMs Folder
        Move-VM -VM $linkedvm -InventoryLocation (Get-Folder -Name $LinkedFolderName)
        # Write that it was completed!
        Write-Host "Linked clone '$CloneName' created and placed in '$LinkedFolderName'." 
    }
    else {
        Write-Host "'$CloneType' is not a clone type. Enter Full or Linked" 
    }
}
