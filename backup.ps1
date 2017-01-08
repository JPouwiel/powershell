#only need one parameter here, defaulted to "server"
param([string]$server = "server")

#calculate disk-usage for vm
function Get-VmSize($VMRAW){
  $VHDs=Get-VHD $VMRAW.harddrives.path -ComputerName $VMRAW.computername
    foreach ($VHD in $VHDs) {
      New-Object PSObject -Property @{
          Name = $VMRAW.name
          Type = $VHD.VhdType
          Path = $VHD.Path
          $VHDTotalGB = [math]::Round($VHD.Size/1GB)
          $VHDUsedGB = [math]::Round($VHD.FileSize/1GB)
          $VHDFreeGB =  [math]::Round($VHD.Size/1GB- $VHD.FileSize/1GB)
      }
   }
}


#housekeeping
function housekeeping(){
  $DATETIME = get-date -format r
  $VMHostName = (get-vmhost | select name).Name.ToString()
  $VMHostCPU = (get-vmhost | select LogicalProcessorCount).LogicalProcessorCount
  #$VMHostMEM = (get-vmhost | select 'MemoryCapacity`(M`)').MemoryCapacity`(M`) 
  #$VMHostMEM = get-vmhost -filter {name -like '$nameregex' 
  $VMHostMEM = [math]::Round((Get-VMhost -ComputerName bdc701).MemoryCapacity / 1024 / 1024 / 1024)
  #$hdtotal = Get-VM -VMName $VMName | Select-Object VMId | Get-VHD
  $VMHDCount = ((Get-VM -VMName $VMName | Select-Object VMId | Get-VHD)|measure).Count
  Get-VmSize($VMRAW)
  Write-host -foregroundcolor black ";;"
  Write-host -foregroundcolor black "Backup: Release 0.01.0 - Production on $DATETIME"
  Write-host -foregroundcolor black ""
  Write-host -foregroundcolor black "Copyright (c) 2017, Pouwiel.com. All rights reserved"
  Write-host -foregroundcolor black "Connected to: $VMHostName, which has $VMHostCPU logical CPUs and total $VMHostMEM GiB memory."
  Write-host -foregroundcolor black "Total numbers of VHD to backup: $VMHDCount"
  Write-host -foregroundcolor black "VHD filedetails: TotalSize: $VHDTotalGB GiB, Used: $VHDUsedGB GiB, Free: $VHDFreeGB GiB"
  BackupVM
}

#check arguments
function switches(){
	if ($server -ne $null){
		#Clear-variable -Name "VMRAW"
		$VMRAW = (get-vm -name $server* -erroraction silentlycontinue)
		$VMCount = ($VMRAW.Name.ToString() | measure).Count
		if ($VMCount -eq 1) {$VMName = $VMRAW.Name.ToString()}
		if ($server -eq '')        {write-host -foregroundcolor red    `n";; ##########!! ERROR !!################################################################"
		                            write-host -foregroundcolor red      ";; ## Parameter not given or not recognized. Please look through the Usage section"
		                            write-host -foregroundcolor red      ";; ##"`n;usage;break}
		if ($server -eq '/?')      {usage;break}
		  elseif ($server -eq '/h')  {usage;break}
		  elseif ($server -eq '/H')  {usage;break}
		  elseif ($VMCount -eq 0)    {write-host -foregroundcolor yellow `n"Less than 1 server found`n`tBreaking off program";break}
		  elseif ($VMCount -gt 1)    {write-host -foregroundcolor red    `n"More than 1 server found`n`tBreaking off program";break}
		  elseif ($VMCount -eq 1)    {
		  	if     ($VMName -ne $null) {housekeeping}
		    else                       {write-host -foregroundcolor red    `n"Blijkbaar geen server die er op lijkt.." `n;break}}
	} else                       {write-host -foregroundcolor red    `n";; ##########!! ERROR !!################################################################"
		                            write-host -foregroundcolor red      ";; ## Parameter not given or not recognized. Please look through the Usage section"
		                            write-host -foregroundcolor red      ";; ##"`n;usage;break}
}
#typical usage statements
function usage(){
  Write-host -foregroundcolor black ";; ##########~~ INFORMATION ~~##########################################################"
  Write-host -foregroundcolor black ";; ## BACKUP"
  Write-host -foregroundcolor black ";;"
  write-host -foregroundcolor black ";; Description:"
  Write-host -foregroundcolor black ";;     Backs up a single Virtual Machine to the local shared folder BCK @ bdc701:H:"
  write-host -foregroundcolor black ";;     The command used is: 'WBADMIN START BACKUP -backupTarget:H: -hyperv:{vm_name}'"
  Write-host -foregroundcolor black ";;"
  write-host -foregroundcolor black ";; Usage:"
  Write-host -foregroundcolor black ";;     " -NoNewline
  Write-host -foregroundcolor darkblue "c:\Users\Administrator\Documents\backup.ps1 " -NoNewline
  Write-host -foregroundcolor darkgreen "bdc003"
  Write-host -foregroundcolor black ";;"
  Write-host -foregroundcolor black ";; Parameter List:"
  write-host -foregroundcolor black ";;     /?             Displays this help message."
  Write-host -foregroundcolor black ";;     vm_name        When given a vm_name, it will be passed as argument to the wbadmin program"
  write-host -foregroundcolor black ";;"
  Write-host -foregroundcolor black ";; Resources:"
  write-host -foregroundcolor black ";;     WBADMIN        @ https://blogs.msdn.microsoft.com/virtual_pc_guy/2013/02/25/backing-up-hyper-v-virtual-machines-from-the-command-line/"
  Write-host -foregroundcolor black ";;                    @ https://virtualizationreview.com/blogs/virtual-insider/2013/02/back-up-hyper-v-vms.aspx"
  write-host -foregroundcolor black ";;"
  Write-host -foregroundcolor black ";;     BATCH script   @ http://thephuck.com/virtualization/quick-script-i-need-to-get-vm-info-for-multiple-vms-get-vminfo-ps1/"
  write-host -foregroundcolor black ";;                    @ http://stackoverflow.com/questions/13408440/arguments-with-powershell-scripts-on-launch"
  write-host -foregroundcolor black ";;                    @ https://powershell.org/forums/topic/assign-a-variable-with-a-multi-line-string-array-right-in-the-console/"`n
}
 
#the main guts of the script
function BackupVM(){
 
            #lets check and see if we're already connected somewhere
            #if($global:DefaultVIServer){disconnect-viserver -confirm:$false}
            #connect-viserver vcentername > $NULL 2>&1
            #$vm = get-vm $server -erroraction silentlycontinue
            #$server = get-vm -name $server* | select name
            #$VM = $server.Name.ToString()
            if ($VMName -ne $null){
                #$vcls = get-cluster -vm $server
                #$vdc = get-datacenter -vm $server
                write-host -foregroundcolor black "Starting local backup for vm "  -NoNewline
                write-host -foregroundcolor magenta $VMName
                write-host -foregroundcolor black "OS is" $vm.Guest.OSFullName
                write-host -foregroundcolor black "Running on host" $vm.vmhost "in the $vcls cluster in the $vdc Datacenter"
                write-host -foregroundcolor black "starting 'WBADMIN START BACKUP -backupTarget:\\bdc701\BCK -hyperv:%arg1%'"
                #if ($vm.memorymb -gt 1024){
                #    $ram = [math]::round($vm.MemoryMB/1024, 0)
                #    write-host -foregroundcolor green `n "It has" $VM.HardDisks.Count "virtual disks," $vm.NumCPU "CPUs, and $ram GB of RAM" `n
                #    }
                #else{write-host -foregroundcolor green `n "It has" $VM.HardDisks.Count "virtual disks," $vm.NumCPU "CPUs, and" $vm.memorymb "MB of RAM" `n}
                }
            elseif ($VMName -eq $null){write-host -foregroundcolor red `n "Cannot find server on Host" `n;break}
            #if($global:DefaultVIServer){disconnect-viserver -confirm:$false -erroraction silentlycontinue}
#$VMs = Get-VM | foreach {$_.name}
#$VMList = $VMs -join ","
#$VMList = """$VMlist"""
#$arg1_vald = get-vm -name $name* | select name
#$VM = $arg1_vald.Name.ToString()
#Write-host $VM
#$Exec = "C:windowsSystem32wbadmin.exe"
#$Arg1 = "start"
#$Arg2 = "backup"
#$Arg3 = "-backuptarget:B:"
#$Arg4 = "-hyperv:$VMlist"
#$Arg5 = "-quiet"

#$Command = "$Exec $Arg1 $Arg2 $Arg3 $Arg4 $Arg5"

#Invoke-Expression $Command
}

 
#making sure we have parameters
If($servers -eq "servers"){
    usage
    break
    }
switches
#getinfo