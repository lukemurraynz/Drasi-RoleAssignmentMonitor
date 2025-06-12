# BastionManager.ps1 - Functions for managing Azure Bastion resources

. "$PSScriptRoot\Logger.ps1"

function Invoke-BastionCreation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$VirtualMachineName
    )
    
    try {
        Write-LogInfo "Starting Bastion creation process for VM: $VirtualMachineName in RG: $ResourceGroupName"
        
        # Connect to Azure using managed identity
        $connectionResult = Connect-AzureWithManagedIdentity -SubscriptionId $SubscriptionId
        if (-not $connectionResult.Success) {
            return @{ Success = $false; Message = "Failed to connect to Azure: $($connectionResult.Message)" }
        }
        
        # Get VM details to determine VNet and location
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction SilentlyContinue
        if (-not $vm) {
            return @{ Success = $false; Message = "Virtual Machine '$VirtualMachineName' not found in resource group '$ResourceGroupName'" }
        }
        
        # Get the VM's network interface to find VNet
        $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
        $vnetId = ($nic.IpConfigurations[0].Subnet.Id -split '/subnets/')[0]
        $vnet = Get-AzVirtualNetwork -ResourceId $vnetId
        
        Write-LogInfo "VM Location: $($vm.Location), VNet: $($vnet.Name)"
        
        # Check if Bastion subnet exists
        $bastionSubnet = Get-BastionSubnet -VirtualNetwork $vnet
        if (-not $bastionSubnet.Exists) {
            # Create Bastion subnet if it doesn't exist
            $subnetResult = New-BastionSubnet -VirtualNetwork $vnet -ResourceGroupName $ResourceGroupName
            if (-not $subnetResult.Success) {
                return @{ Success = $false; Message = "Failed to create Bastion subnet: $($subnetResult.Message)" }
            }
            $bastionSubnet = $subnetResult.Subnet
        }
        
        # Generate unique Bastion name
        $bastionName = "bastion-$($vm.Name.ToLower())-$(Get-Random -Minimum 1000 -Maximum 9999)"
        
        # Check if Bastion already exists for this VNet
        $existingBastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | 
            Where-Object { $_.IpConfigurations.Subnet.Id -like "*$($vnet.Name)*" }
        
        if ($existingBastion) {
            Write-LogInfo "Bastion already exists for this VNet: $($existingBastion.Name)"
            return @{ Success = $true; Message = "Bastion already exists: $($existingBastion.Name)" }
        }
        
        # Create public IP for Bastion
        $publicIpResult = New-BastionPublicIP -ResourceGroupName $ResourceGroupName -Location $vm.Location -BastionName $bastionName
        if (-not $publicIpResult.Success) {
            return @{ Success = $false; Message = "Failed to create public IP: $($publicIpResult.Message)" }
        }
        
        # Create Bastion
        $bastionResult = New-AzureBastionHost -ResourceGroupName $ResourceGroupName -BastionName $bastionName -PublicIP $publicIpResult.PublicIP -VirtualNetwork $vnet -Location $vm.Location
        
        return $bastionResult
    }
    catch {
        Write-LogError "Error in Bastion creation: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Unexpected error: $($_.Exception.Message)" }
    }
}

function Invoke-BastionCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$VirtualMachineName
    )
    
    try {
        Write-LogInfo "Starting Bastion cleanup process for VM: $VirtualMachineName in RG: $ResourceGroupName"
        
        # Connect to Azure using managed identity
        $connectionResult = Connect-AzureWithManagedIdentity -SubscriptionId $SubscriptionId
        if (-not $connectionResult.Success) {
            return @{ Success = $false; Message = "Failed to connect to Azure: $($connectionResult.Message)" }
        }
        
        # Get VM details to determine VNet
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction SilentlyContinue
        if (-not $vm) {
            Write-LogWarning "Virtual Machine '$VirtualMachineName' not found, proceeding with cleanup anyway"
            return @{ Success = $true; Message = "VM not found, cleanup not required" }
        }
        
        # Get the VM's VNet
        $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
        $vnetId = ($nic.IpConfigurations[0].Subnet.Id -split '/subnets/')[0]
        $vnet = Get-AzVirtualNetwork -ResourceId $vnetId
        
        # Check for other VMs with VM Administrator Login role in the same VNet
        $shouldKeepBastion = Test-OtherVMsWithAdminRole -VirtualNetwork $vnet -ResourceGroupName $ResourceGroupName -ExcludeVM $VirtualMachineName
        
        if ($shouldKeepBastion) {
            Write-LogInfo "Other VMs with VM Administrator Login role found in VNet, keeping Bastion"
            return @{ Success = $true; Message = "Bastion retained due to other VMs with admin access" }
        }
        
        # Find and remove Bastion for this VNet
        $bastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | 
            Where-Object { $_.IpConfigurations.Subnet.Id -like "*$($vnet.Name)*" }
        
        if (-not $bastion) {
            Write-LogInfo "No Bastion found for VNet: $($vnet.Name)"
            return @{ Success = $true; Message = "No Bastion found to remove" }
        }
        
        # Remove Bastion
        $removalResult = Remove-AzureBastionHost -Bastion $bastion -ResourceGroupName $ResourceGroupName
        
        return $removalResult
    }
    catch {
        Write-LogError "Error in Bastion cleanup: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Unexpected error: $($_.Exception.Message)" }
    }
}

function Connect-AzureWithManagedIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )
    
    try {
        Write-LogInfo "Connecting to Azure using managed identity"
        
        # Connect using managed identity
        $context = Connect-AzAccount -Identity -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        Write-LogInfo "Successfully connected to Azure. Subscription: $SubscriptionId"
        return @{ Success = $true; Context = $context }
    }
    catch {
        Write-LogError "Failed to connect to Azure: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Get-BastionSubnet {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )
    
    $bastionSubnetName = $env:BASTION_SUBNET_NAME ?? "AzureBastionSubnet"
    $bastionSubnet = $VirtualNetwork.Subnets | Where-Object { $_.Name -eq $bastionSubnetName }
    
    if ($bastionSubnet) {
        return @{ Exists = $true; Subnet = $bastionSubnet }
    }
    else {
        return @{ Exists = $false; Subnet = $null }
    }
}

function New-BastionSubnet {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    try {
        Write-LogInfo "Creating AzureBastionSubnet in VNet: $($VirtualNetwork.Name)"
        
        # Find available address space for Bastion subnet (requires /26 or larger)
        $bastionSubnetAddress = Get-AvailableSubnetAddressSpace -VirtualNetwork $VirtualNetwork -SubnetSize 26
        
        if (-not $bastionSubnetAddress) {
            return @{ Success = $false; Message = "No available address space for Bastion subnet (/26 required)" }
        }
        
        # Add Bastion subnet to VNet
        $bastionSubnetName = $env:BASTION_SUBNET_NAME ?? "AzureBastionSubnet"
        Add-AzVirtualNetworkSubnetConfig -Name $bastionSubnetName -VirtualNetwork $VirtualNetwork -AddressPrefix $bastionSubnetAddress
        
        # Update VNet
        $VirtualNetwork | Set-AzVirtualNetwork
        
        # Get the updated subnet
        $updatedVNet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VirtualNetwork.Name
        $bastionSubnet = $updatedVNet.Subnets | Where-Object { $_.Name -eq $bastionSubnetName }
        
        Write-LogInfo "Successfully created Bastion subnet: $bastionSubnetAddress"
        return @{ Success = $true; Subnet = $bastionSubnet }
    }
    catch {
        Write-LogError "Error creating Bastion subnet: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Get-AvailableSubnetAddressSpace {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [Parameter(Mandatory = $true)]
        [int]$SubnetSize
    )
    
    # This is a simplified implementation - in production, you'd want more sophisticated logic
    # to find available address space within the VNet's address space
    
    $vnetAddressSpace = $VirtualNetwork.AddressSpace.AddressPrefixes[0]
    $vnetNetwork = [System.Net.IPAddress]::Parse(($vnetAddressSpace -split '/')[0])
    $vnetPrefix = [int]($vnetAddressSpace -split '/')[1]
    
    # For simplicity, try common Bastion subnet addresses
    $candidateSubnets = @(
        "10.0.1.0/26",
        "10.0.2.0/26", 
        "10.0.3.0/26",
        "192.168.1.0/26",
        "192.168.2.0/26",
        "172.16.1.0/26"
    )
    
    foreach ($candidate in $candidateSubnets) {
        $candidateNetwork = [System.Net.IPAddress]::Parse(($candidate -split '/')[0])
        
        # Check if this candidate overlaps with existing subnets
        $overlap = $false
        foreach ($subnet in $VirtualNetwork.Subnets) {
            if (Test-SubnetOverlap -Subnet1 $candidate -Subnet2 $subnet.AddressPrefix) {
                $overlap = $true
                break
            }
        }
        
        if (-not $overlap) {
            return $candidate
        }
    }
    
    Write-LogWarning "Could not find available subnet address space automatically"
    return $null
}

function Test-SubnetOverlap {
    param(
        [string]$Subnet1,
        [string]$Subnet2
    )
    
    # Simplified overlap detection - in production, use proper CIDR comparison
    $net1 = ($Subnet1 -split '/')[0] -split '\.'
    $net2 = ($Subnet2 -split '/')[0] -split '\.'
    
    # Simple check for same network class
    return ($net1[0] -eq $net2[0] -and $net1[1] -eq $net2[1])
}

function New-BastionPublicIP {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$Location,
        [Parameter(Mandatory = $true)]
        [string]$BastionName
    )
    
    try {
        $publicIpName = "$BastionName-pip"
        Write-LogInfo "Creating public IP: $publicIpName"
        
        $publicIp = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $publicIpName -Location $Location -AllocationMethod Static -Sku Standard -Zone @()
        
        Write-LogInfo "Successfully created public IP: $publicIpName"
        return @{ Success = $true; PublicIP = $publicIp }
    }
    catch {
        Write-LogError "Error creating public IP: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function New-AzureBastionHost {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$BastionName,
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress]$PublicIP,
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [Parameter(Mandatory = $true)]
        [string]$Location
    )
    
    try {
        Write-LogInfo "Creating Azure Bastion: $BastionName"
        
        $bastionSubnetName = $env:BASTION_SUBNET_NAME ?? "AzureBastionSubnet"
        $bastionSubnet = $VirtualNetwork.Subnets | Where-Object { $_.Name -eq $bastionSubnetName }
        
        if (-not $bastionSubnet) {
            return @{ Success = $false; Message = "Bastion subnet not found" }
        }
        
        $sku = $env:BASTION_SKU ?? "Basic"
        
        $bastion = New-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName -PublicIpAddress $PublicIP -VirtualNetwork $VirtualNetwork -Sku $sku
        
        Write-LogInfo "Successfully created Azure Bastion: $BastionName"
        return @{ Success = $true; Message = "Bastion created successfully: $BastionName"; Bastion = $bastion }
    }
    catch {
        Write-LogError "Error creating Azure Bastion: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Remove-AzureBastionHost {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSBastion]$Bastion,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    try {
        Write-LogInfo "Removing Azure Bastion: $($Bastion.Name)"
        
        # Remove Bastion
        Remove-AzBastion -ResourceGroupName $ResourceGroupName -Name $Bastion.Name -Force
        
        # Clean up associated public IP
        $publicIpName = "$($Bastion.Name)-pip"
        $publicIp = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $publicIpName -ErrorAction SilentlyContinue
        
        if ($publicIp) {
            Write-LogInfo "Removing associated public IP: $publicIpName"
            Remove-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $publicIpName -Force
        }
        
        Write-LogInfo "Successfully removed Azure Bastion: $($Bastion.Name)"
        return @{ Success = $true; Message = "Bastion removed successfully: $($Bastion.Name)" }
    }
    catch {
        Write-LogError "Error removing Azure Bastion: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function Test-OtherVMsWithAdminRole {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ExcludeVM
    )
    
    try {
        Write-LogInfo "Checking for other VMs with VM Administrator Login role in VNet: $($VirtualNetwork.Name)"
        
        # Get all VMs in the resource group
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
        
        $vmAdminRoleId = $env:VM_ADMIN_ROLE_ID
        
        foreach ($vm in $vms) {
            if ($vm.Name -eq $ExcludeVM) {
                continue
            }
            
            # Check if VM is in the same VNet
            $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
            $vmVnetId = ($nic.IpConfigurations[0].Subnet.Id -split '/subnets/')[0]
            
            if ($vmVnetId -eq $VirtualNetwork.Id) {
                # Check role assignments for this VM
                $roleAssignments = Get-AzRoleAssignment -Scope $vm.Id
                
                foreach ($assignment in $roleAssignments) {
                    if ($assignment.RoleDefinitionId -like "*$vmAdminRoleId*") {
                        Write-LogInfo "Found VM with admin role: $($vm.Name)"
                        return $true
                    }
                }
            }
        }
        
        Write-LogInfo "No other VMs with VM Administrator Login role found in VNet"
        return $false
    }
    catch {
        Write-LogError "Error checking for other VMs with admin role: $($_.Exception.Message)"
        # If we can't determine, err on the side of caution and keep the Bastion
        return $true
    }
}