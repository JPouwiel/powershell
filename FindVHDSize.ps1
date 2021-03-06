# Prompt for the Hyper-V Server to use
$HyperVServer = Read-Host "Specify the Hyper-V Server to use (enter '.' for the local computer)"

# Prompt for the virtual machine to use
$VMName = Read-Host "Specify the name of the virtual machine"

# Get Storage management service
#$ImgService = gwmi Msvm_ImageManagementService -namespace "root\virtualization" -computername $HyperVServer -locale MS_409

# Get the virtual machine object
#$VM = gwmi MSVM_ComputerSystem -namespace "root\virtualization" -computername $HyperVServer -locale MS_409 | where {$_.ElementName -eq $VMName}

# Create an empty hashtable
$table = @{}

# Set size variables
$totalSize = 0
 
# Go over each of the virtual machines "system setting data" objects.  There will be a system setting data
# for each snapshot associated with the virtual machine, and one for the active virtual machine.
foreach ($VSSD in @($VM.getRelated("Msvm_VirtualSystemSettingData"))) 
  {
   # Get all the VHDs associated with the current system setting data
   $VHDs = [array]($VSSD.getRelated("Msvm_ResourceAllocationSettingData") | where {$_.ResourceType -eq 21} | where {$_.ResourceSubType -eq "Microsoft Virtual Hard Disk"})

   # Only continue if the system setting data actually had virtual hard disks
   if ($VHDs)
      {
      # Intialize index, and get the VHD and VHDPath for the first virtual hard disk      
      $index = 0
      $VHD = $VHDs[$index]
      $VHDPath = $VHD.Connection | select -first 1"background: darkgray"

      # loop through all virtual hard disks
      do      
         {
         # Get the detailed information for the current virtual hard disk
         $xml = [xml]($ImgService.GetVirtualHardDiskInfo($VHDPath)).info
      
         # Only continue if the current virtual hard disk is not in the hashtable
         if (!$table.ContainsKey($VHDPath)) 
            {
            # Store the file size for the virtual hard disk in the table - and add it to $totalSize
            $table[$VHDPath] = [uint64]($xml.Instance.Property | ?{$_.Name -eq "fileSize"}).value
            $totalSize = $totalSize + [uint64]($xml.Instance.Property | ?{$_.Name -eq "fileSize"}).value
            
            # Check to see if the current virtual hard disk has a parent virtual hard disk
            if (($xml.Instance.Property | ?{$_.Name -eq "ParentPath"}).value)
               {
               # if it does - make the parent the next virtual hard disk that we look at
               $VHDPath = ($xml.Instance.Property | ?{$_.Name -eq "ParentPath"}).value
               }
            # If the current virtual hard disk does not have a parent - just move onto the next virtual
            # hard disk in the system settings data object
            else
               {
               # Increase the index - and make sure that we have not gone past the last virtual hard disk
               $index = $index + 1
               if ($index -ne $VHDs.count)
                  {
                  # Setup new values for next time through
                  $VHD = $VHDs[$index]
                  $VHDPath = $VHD.Connection | select -first 1}
                  }
         
               }

         # If the current virtual hard disk is already in the hashtable - move onto the next virtual
         # hard disk in the system settings data object         
         else
            {
            # Increase the index - and make sure that we have not gone past the last virtual hard disk
            $index = $index + 1
            if ($index -ne $VHDs.count)
               {
               # Setup new values for next time through
               $VHD = $VHDs[$index]
               $VHDPath = $VHD.Connection | select -first 1
               }
            }
         }
      
      # loop until we have covered all virtual hard disks
      until ($index -eq $VHDs.count)
      }
   }

# Get the VSSD and VHD array for the currently active virtual machine
$activeVSSD = $VM.getRelated("Msvm_VirtualSystemSettingData") | ?{$_.SettingType -eq 3}
$activeVHDs = [array]($activeVSSD.getRelated("Msvm_ResourceAllocationSettingData") | where {$_.ResourceType -eq 21} | where {$_.ResourceSubType -eq "Microsoft Virtual Hard Disk"})

# Setup some blank varibles
$activeVMSize = 0
$activeVMCapacity = 0

# Calculate the total file size and internal capacity only for the active virtual machine
foreach ($VHD in $activeVHDs) 
  {
  $VHDPath = $VHD.Connection | select -first 1
  $xml = [xml]($ImgService.GetVirtualHardDiskInfo($VHDPath)).info
  $activeVMSize = $activeVMSize + [uint64]($xml.Instance.Property | ?{$_.Name -eq "fileSize"}).value
  $activeVMCapacity = $activeVMCapacity + [uint64]($xml.Instance.Property | ?{$_.Name -eq "MaxInternalSize"}).value
  }

# Do some math and formatting to get from bytes to gigagytes
$totalPossibleSize = "{0:N2}" -f (($totalSize - $activeVMSize + $activeVMCapacity) / 1073741824)
$totalSize = "{0:N2}" -f ($totalSize / 1073741824)

# Display the results
write-host "Total disk space used by the virtual machine:" $totalSize "GB"
write-host "Most disk space that can be used by the virtual machine:" $totalPossibleSize "GB"