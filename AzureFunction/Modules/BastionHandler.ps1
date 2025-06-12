# BastionHandler.ps1 - Specific handler for Azure Bastion operations
# Decoupled from VM dependencies for more flexible deployment

. "$PSScriptRoot\Logger.ps1"
. "$PSScriptRoot\BastionManager.ps1"

function Invoke-BastionHandler {
    <#
    .SYNOPSIS
    Handles Bastion-related actions for role assignments
    
    .DESCRIPTION
    Processes Bastion creation and removal actions without requiring VM context
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )
    
    try {
        $action = $Parameters.Action
        $roleInfo = $Parameters.RoleInfo
        $roleConfig = $Parameters.RoleConfig
        $configuration = $Parameters.Configuration
        
        Write-LogInfo "Processing Bastion action: $action"
        
        switch ($action) {
            "CreateBastion" {
                return Invoke-BastionCreationForRole -RoleInfo $roleInfo -Configuration $configuration
            }
            "EvaluateBastionRemoval" {
                return Invoke-BastionRemovalEvaluation -RoleInfo $roleInfo -Configuration $configuration
            }
            default {
                Write-LogWarning "Unknown Bastion action: $action"
                return @{ Success = $false; Message = "Unknown action: $action" }
            }
        }
    }
    catch {
        Write-LogError "Error in Bastion handler: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Bastion handler failed: $($_.Exception.Message)" }
    }
}

function Invoke-BastionCreationForRole {
    <#
    .SYNOPSIS
    Creates Bastion based on role assignment context (not VM-specific)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-LogInfo "Creating Bastion for role assignment in subscription: $($RoleInfo.SubscriptionId)"
        
        # Connect to Azure
        $connectionResult = Connect-AzureWithManagedIdentity -SubscriptionId $RoleInfo.SubscriptionId
        if (-not $connectionResult.Success) {
            return @{ Success = $false; Message = "Azure connection failed: $($connectionResult.Message)" }
        }
        
        # Determine deployment strategy based on resource type and configuration
        switch ($RoleInfo.ResourceType) {
            "Microsoft.Compute/virtualMachines" {
                # For VM role assignments, deploy Bastion in the VM's VNet
                return Invoke-BastionCreationForVM -RoleInfo $RoleInfo -Configuration $Configuration
            }
            "Microsoft.Resources/subscriptions" {
                # For subscription-level assignments, deploy in default location
                return Invoke-BastionCreationForSubscription -RoleInfo $RoleInfo -Configuration $Configuration
            }
            "Microsoft.Resources/resourceGroups" {
                # For resource group assignments, deploy in that resource group
                return Invoke-BastionCreationForResourceGroup -RoleInfo $RoleInfo -Configuration $Configuration
            }
            default {
                Write-LogInfo "Resource type $($RoleInfo.ResourceType) - deploying Bastion in resource group"
                return Invoke-BastionCreationForResourceGroup -RoleInfo $RoleInfo -Configuration $Configuration
            }
        }
    }
    catch {
        Write-LogError "Error creating Bastion for role: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Bastion creation failed: $($_.Exception.Message)" }
    }
}

function Invoke-BastionCreationForVM {
    <#
    .SYNOPSIS
    Creates Bastion in the same VNet as the VM (original logic)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        # Get VM to determine VNet
        $vm = Get-AzVM -ResourceGroupName $RoleInfo.ResourceGroup -Name $RoleInfo.ResourceName -ErrorAction SilentlyContinue
        
        if (-not $vm) {
            Write-LogWarning "VM $($RoleInfo.ResourceName) not found, deploying Bastion in resource group instead"
            return Invoke-BastionCreationForResourceGroup -RoleInfo $RoleInfo -Configuration $Configuration
        }
        
        # Use existing Bastion creation logic
        return Invoke-BastionCreation -SubscriptionId $RoleInfo.SubscriptionId -ResourceGroupName $RoleInfo.ResourceGroup -VirtualMachineName $RoleInfo.ResourceName
    }
    catch {
        Write-LogError "Error creating Bastion for VM: $($_.Exception.Message)"
        return @{ Success = $false; Message = "VM-based Bastion creation failed: $($_.Exception.Message)" }
    }
}

function Invoke-BastionCreationForResourceGroup {
    <#
    .SYNOPSIS
    Creates Bastion in the specified resource group with automatic VNet detection/creation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-LogInfo "Creating Bastion in resource group: $($RoleInfo.ResourceGroup)"
        
        $bastionConfig = $Configuration.Resources.Bastion
        $location = $Configuration.Azure.DefaultLocation
        
        # Look for existing VNets in the resource group
        $vnets = Get-AzVirtualNetwork -ResourceGroupName $RoleInfo.ResourceGroup -ErrorAction SilentlyContinue
        
        $targetVNet = $null
        
        if ($vnets -and $vnets.Count -gt 0) {
            # Use the first VNet found
            $targetVNet = $vnets[0]
            Write-LogInfo "Found existing VNet: $($targetVNet.Name)"
        } else {
            # Create a new VNet for Bastion
            Write-LogInfo "No VNet found, creating new VNet for Bastion"
            $vnetResult = New-VNetForBastion -ResourceGroupName $RoleInfo.ResourceGroup -Location $location -Configuration $bastionConfig
            
            if (-not $vnetResult.Success) {
                return @{ Success = $false; Message = "Failed to create VNet: $($vnetResult.Message)" }
            }
            
            $targetVNet = $vnetResult.VNet
        }
        
        # Check/create Bastion subnet
        $bastionSubnetResult = Ensure-BastionSubnet -VirtualNetwork $targetVNet -Configuration $bastionConfig
        
        if (-not $bastionSubnetResult.Success) {
            return @{ Success = $false; Message = "Failed to ensure Bastion subnet: $($bastionSubnetResult.Message)" }
        }
        
        # Create Bastion
        $bastionName = Get-BastionName -ResourceGroup $RoleInfo.ResourceGroup -Configuration $bastionConfig
        $bastionResult = New-BastionHost -ResourceGroupName $RoleInfo.ResourceGroup -BastionName $bastionName -VirtualNetwork $targetVNet -Configuration $bastionConfig
        
        return $bastionResult
    }
    catch {
        Write-LogError "Error creating Bastion for resource group: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Resource group Bastion creation failed: $($_.Exception.Message)" }
    }
}

function Invoke-BastionCreationForSubscription {
    <#
    .SYNOPSIS
    Creates Bastion at subscription level - uses default resource group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-LogInfo "Creating Bastion for subscription-level role assignment"
        
        # Use or create a default resource group for subscription-level Bastion
        $defaultRGName = $env:DEFAULT_BASTION_RESOURCE_GROUP ?? "rg-bastion-default"
        $location = $Configuration.Azure.DefaultLocation
        
        # Ensure resource group exists
        $rg = Get-AzResourceGroup -Name $defaultRGName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-LogInfo "Creating default Bastion resource group: $defaultRGName"
            $rg = New-AzResourceGroup -Name $defaultRGName -Location $location
        }
        
        # Create modified role info for the default resource group
        $modifiedRoleInfo = [PSCustomObject]@{
            RoleId = $RoleInfo.RoleId
            ResourceId = $RoleInfo.ResourceId
            ResourceType = $RoleInfo.ResourceType
            SubscriptionId = $RoleInfo.SubscriptionId
            ResourceGroup = $defaultRGName
            ResourceName = "subscription-level-access"
        }
        
        return Invoke-BastionCreationForResourceGroup -RoleInfo $modifiedRoleInfo -Configuration $Configuration
    }
    catch {
        Write-LogError "Error creating Bastion for subscription: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Subscription Bastion creation failed: $($_.Exception.Message)" }
    }
}

function Invoke-BastionRemovalEvaluation {
    <#
    .SYNOPSIS
    Evaluates whether Bastion should be removed based on remaining role assignments
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-LogInfo "Evaluating Bastion removal for role assignment"
        
        # Connect to Azure
        $connectionResult = Connect-AzureWithManagedIdentity -SubscriptionId $RoleInfo.SubscriptionId
        if (-not $connectionResult.Success) {
            return @{ Success = $false; Message = "Azure connection failed: $($connectionResult.Message)" }
        }
        
        # Check if there are other active role assignments that require Bastion
        $hasOtherAssignments = Test-OtherActiveRoleAssignments -RoleInfo $RoleInfo -Configuration $Configuration
        
        if ($hasOtherAssignments) {
            Write-LogInfo "Other active role assignments found, keeping Bastion"
            return @{ Success = $true; Message = "Bastion retained due to other active assignments" }
        }
        
        # Determine cleanup strategy based on how Bastion was originally deployed
        switch ($RoleInfo.ResourceType) {
            "Microsoft.Compute/virtualMachines" {
                return Invoke-BastionCleanup -SubscriptionId $RoleInfo.SubscriptionId -ResourceGroupName $RoleInfo.ResourceGroup -VirtualMachineName $RoleInfo.ResourceName
            }
            default {
                return Invoke-BastionCleanupForResourceGroup -RoleInfo $RoleInfo -Configuration $Configuration
            }
        }
    }
    catch {
        Write-LogError "Error evaluating Bastion removal: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Bastion removal evaluation failed: $($_.Exception.Message)" }
    }
}

function Test-OtherActiveRoleAssignments {
    <#
    .SYNOPSIS
    Checks if there are other active role assignments that require Bastion
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        # This is a simplified check - in a real implementation, you would:
        # 1. Query Azure Resource Graph or RBAC API for active role assignments
        # 2. Check for VM Administrator Login roles in the same scope
        # 3. Consider subscription, resource group, and resource-level assignments
        
        Write-LogInfo "Checking for other active role assignments requiring Bastion"
        
        # For now, implement a basic check based on configuration
        $cleanupDelay = $Configuration.Resources.Bastion.CleanupDelayHours
        
        if ($cleanupDelay -gt 0) {
            Write-LogInfo "Cleanup delay of $cleanupDelay hours configured - scheduling for later"
            # In a real implementation, this could queue the cleanup for later
            return $true
        }
        
        # TODO: Implement actual RBAC query logic here
        # For demonstration, assume no other assignments
        return $false
    }
    catch {
        Write-LogError "Error checking other role assignments: $($_.Exception.Message)"
        return $true  # Err on the side of caution - keep Bastion
    }
}

function Invoke-BastionCleanupForResourceGroup {
    <#
    .SYNOPSIS
    Cleans up Bastion resources in a resource group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-LogInfo "Cleaning up Bastion in resource group: $($RoleInfo.ResourceGroup)"
        
        # Find Bastion hosts in the resource group
        $bastions = Get-AzBastion -ResourceGroupName $RoleInfo.ResourceGroup -ErrorAction SilentlyContinue
        
        if (-not $bastions -or $bastions.Count -eq 0) {
            Write-LogInfo "No Bastion hosts found in resource group"
            return @{ Success = $true; Message = "No Bastion hosts to clean up" }
        }
        
        $results = @()
        
        foreach ($bastion in $bastions) {
            Write-LogInfo "Removing Bastion: $($bastion.Name)"
            
            try {
                # Check dry run mode
                $dryRunMode = $Configuration.Global.DryRunMode
                
                if ($dryRunMode) {
                    Write-LogInfo "DRY RUN: Would remove Bastion $($bastion.Name)"
                    $results += @{ Success = $true; Message = "DRY RUN: Bastion $($bastion.Name) would be removed" }
                } else {
                    Remove-AzBastion -ResourceGroupName $RoleInfo.ResourceGroup -Name $bastion.Name -Force
                    Write-LogInfo "Successfully removed Bastion: $($bastion.Name)"
                    $results += @{ Success = $true; Message = "Bastion $($bastion.Name) removed successfully" }
                }
            }
            catch {
                Write-LogError "Failed to remove Bastion $($bastion.Name): $($_.Exception.Message)"
                $results += @{ Success = $false; Message = "Failed to remove Bastion $($bastion.Name): $($_.Exception.Message)" }
            }
        }
        
        $successCount = ($results | Where-Object { $_.Success }).Count
        $totalCount = $results.Count
        
        return @{
            Success = $successCount -eq $totalCount
            Message = "Cleaned up $successCount of $totalCount Bastion hosts"
            Details = $results
        }
    }
    catch {
        Write-LogError "Error during Bastion cleanup: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Bastion cleanup failed: $($_.Exception.Message)" }
    }
}

function New-VNetForBastion {
    <#
    .SYNOPSIS
    Creates a new VNet suitable for Bastion deployment
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$Location,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        $vnetName = "vnet-bastion-auto-$(Get-Random)"
        $addressPrefix = "10.0.0.0/16"
        
        Write-LogInfo "Creating VNet: $vnetName"
        
        if ($Configuration.DryRunMode) {
            Write-LogInfo "DRY RUN: Would create VNet $vnetName"
            return @{
                Success = $true
                Message = "DRY RUN: VNet would be created"
                VNet = @{ Name = $vnetName }
            }
        }
        
        $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location -Name $vnetName -AddressPrefix $addressPrefix
        
        Write-LogInfo "Successfully created VNet: $vnetName"
        
        return @{
            Success = $true
            Message = "VNet created successfully"
            VNet = $vnet
        }
    }
    catch {
        Write-LogError "Failed to create VNet: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "VNet creation failed: $($_.Exception.Message)"
            VNet = $null
        }
    }
}

function Ensure-BastionSubnet {
    <#
    .SYNOPSIS
    Ensures the AzureBastionSubnet exists in the VNet
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VirtualNetwork,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        $bastionSubnetName = "AzureBastionSubnet"
        
        # Check if Bastion subnet already exists
        $existingSubnet = $VirtualNetwork.Subnets | Where-Object { $_.Name -eq $bastionSubnetName }
        
        if ($existingSubnet) {
            Write-LogInfo "Bastion subnet already exists"
            return @{ Success = $true; Message = "Bastion subnet already exists" }
        }
        
        # Calculate address space for Bastion subnet
        $subnetPrefix = "10.0.1.0/26"  # Default /26 for Bastion
        
        Write-LogInfo "Creating Bastion subnet: $subnetPrefix"
        
        if ($Configuration.DryRunMode) {
            Write-LogInfo "DRY RUN: Would create Bastion subnet"
            return @{ Success = $true; Message = "DRY RUN: Bastion subnet would be created" }
        }
        
        $subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name $bastionSubnetName -AddressPrefix $subnetPrefix -VirtualNetwork $VirtualNetwork
        $VirtualNetwork | Set-AzVirtualNetwork
        
        Write-LogInfo "Successfully created Bastion subnet"
        
        return @{ Success = $true; Message = "Bastion subnet created successfully" }
    }
    catch {
        Write-LogError "Failed to create Bastion subnet: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Bastion subnet creation failed: $($_.Exception.Message)" }
    }
}

function Get-BastionName {
    <#
    .SYNOPSIS
    Generates a name for the Bastion host
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    $pattern = $Configuration.NamingPattern ?? "bastion-{resourcegroup}-{random}"
    $random = Get-Random
    
    $name = $pattern -replace '\{resourcegroup\}', $ResourceGroup -replace '\{random\}', $random
    
    return $name
}

function New-BastionHost {
    <#
    .SYNOPSIS
    Creates the Bastion host with required configuration
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$BastionName,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VirtualNetwork,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-LogInfo "Creating Bastion host: $BastionName"
        
        if ($Configuration.DryRunMode) {
            Write-LogInfo "DRY RUN: Would create Bastion host $BastionName"
            return @{ Success = $true; Message = "DRY RUN: Bastion host would be created" }
        }
        
        # Get the Bastion subnet
        $bastionSubnet = $VirtualNetwork.Subnets | Where-Object { $_.Name -eq "AzureBastionSubnet" }
        
        if (-not $bastionSubnet) {
            return @{ Success = $false; Message = "AzureBastionSubnet not found" }
        }
        
        # Create public IP for Bastion
        $publicIpName = "$BastionName-pip"
        $publicIp = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $VirtualNetwork.Location -Name $publicIpName -AllocationMethod Static -Sku Standard
        
        # Create Bastion
        $bastion = New-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName -PublicIpAddress $publicIp -VirtualNetwork $VirtualNetwork
        
        Write-LogInfo "Successfully created Bastion host: $BastionName"
        
        return @{
            Success = $true
            Message = "Bastion host created successfully"
            BastionHost = $bastion
        }
    }
    catch {
        Write-LogError "Failed to create Bastion host: $($_.Exception.Message)"
        return @{ Success = $false; Message = "Bastion host creation failed: $($_.Exception.Message)" }
    }
}