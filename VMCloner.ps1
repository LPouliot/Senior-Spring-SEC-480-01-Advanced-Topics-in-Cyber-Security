# Configuration
$VmHostName = "192.168.3.224"
$DatastoreName = "datastore1"
$SnapshotName = "Base"
$NetworkName = "480-Interenal"
$BaseFolderName = "BASE VMs"
$LinkedFolderName = "LINKED VMs"

# Asking the User
$VMName = Read-Host "Enter the name of the VM to be cloned"
$CloneName = Read-Host "Enter the name of the new Clone"
$CloneType = Read-Host "Would you like a Full or Linked type" 

# Variables 
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
$linkedvm | Remove-VM -DeletePermanently -Confirm:$false
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











