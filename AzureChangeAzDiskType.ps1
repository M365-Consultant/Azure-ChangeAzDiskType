<#PSScriptInfo
.VERSION 0.1
.GUID 3cd8210-c04c-4a63-b687-876ac916b2c8
.AUTHOR Dominik Gilgen
.COMPANYNAME Dominik Gilgen (Personal)
.COPYRIGHT 2023 Dominik Gilgen. All rights reserved.
.LICENSEURI https://github.com/M365-Consultant/Azure-ChangeAzDiskType/blob/main/LICENSE
.PROJECTURI https://github.com/M365-Consultant/Azure-ChangeAzDiskType
.EXTERNALMODULEDEPENDENCIES Az.Accounts, Az.Compute
.RELEASENOTES
First beta release.
#>

<# 

.DESCRIPTION 
 Azure Runbook - Change AzDisk Type
 
 This script is designed for a Azure Runbook to change the Disktype of an Azure VM including a shutdown and restart-feature.

 Before running this, you need to set up an automation account with a managed identity.
 
 The managed identity requires the following Permissions on the Subscription:
    - Virtual Machine Contributor

 The script requires the following modules:
    - Az.Accounts
    - Az.Compute

 There are a few parameters which must be set for a job run:
    - $subscription -> The name of the subscription
    - $rgName -> The name of the resourcegroup
    - $vmNames -> The name of the VM. If you want more than one VM, you can seperate them with ;
    - $storageType -> The storage type you want (e.g. 'Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS',...)
    - $shutdown -> If set to True the VMs will be shutdown, because only on a deallocated VM the Disk-Type can be changed
    - $restart -> If set to True the VMs will be started after the Disk-Type change

#> 


param (
    [string]$subscription,
    [string]$rgName,
    [string]$vmNames,
    [string]$storageType,
    [System.Boolean]$shutdown,
    [System.Boolean]$restart
)

Connect-AzAccount -Identity
Set-AzContext -Subscription $subscription

$vmArray = $vmNames.Split(";")

foreach($vmName in $vmArray){
        Write-Output "Excuting tasks for VM $vmName"
        # Get Azure VM
        $vm = Get-AzVM -Name $vmName -resourceGroupName $rgName
        $vm_status = Get-AzVM -Name $vmName -resourceGroupName $rgName -Status

        if (($shutdown -eq "True") -and ($vm_status.Statuses[1].Code -ne 'PowerState/deallocated')){
            Write-Output "Stopping VM..."
            Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force

        }
        elseif($shutdown-eq "True"){
            Write-Output "VM is already deallocated!"
        }

        $vm_status = Get-AzVM -Name $vmName -resourceGroupName $rgName -Status

        if ($vm_status.Statuses[1].Code -eq 'PowerState/deallocated')
        {
                    # Get all disks in the resource group of the VM
                $vmDisks = Get-AzDisk -ResourceGroupName $rgName 

                # For disks that belong to the selected VM, convert to Premium storage
                foreach ($disk in $vmDisks)
                {
                    if ($disk.ManagedBy -eq $vm.Id)
                    {
                        $disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
                        $disk | Update-AzDisk
                    }
                }
        }
        else{
            Write-Warning "Disk-Change failed, because Host is not deallocated!"
        }

        if ($restart -eq "True"){
            Write-Output "Starting VM..."
            Start-AzVM -ResourceGroupName $rgName -Name $vmName
        }
}

Disconnect-AzAccount
