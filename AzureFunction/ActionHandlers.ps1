# Modular action handlers for Azure resource automation
# Inspired by Bellhop pattern: https://azure.github.io/bellhop/#/README

class ActionResult {
    [bool]$Success
    [string]$Message
    [hashtable]$Details
    
    ActionResult([bool]$success, [string]$message, [hashtable]$details = @{}) {
        $this.Success = $success
        $this.Message = $message
        $this.Details = $details
    }
}

class BaseAction {
    [hashtable]$Config
    [hashtable]$GlobalConfig
    
    BaseAction([hashtable]$config, [hashtable]$globalConfig) {
        $this.Config = $config
        $this.GlobalConfig = $globalConfig
    }
    
    [ActionResult] Execute([hashtable]$context) {
        throw "Execute method must be implemented by derived classes"
    }
    
    [void] LogInfo([string]$message) {
        if ($this.GlobalConfig.enableLogging) {
            Write-Host "[INFO] $message"
        }
    }
    
    [void] LogWarning([string]$message) {
        if ($this.GlobalConfig.enableLogging) {
            Write-Warning "[WARNING] $message"
        }
    }
    
    [void] LogError([string]$message) {
        if ($this.GlobalConfig.enableLogging) {
            Write-Error "[ERROR] $message"
        }
    }
}

class CreateBastionAction : BaseAction {
    CreateBastionAction([hashtable]$config, [hashtable]$globalConfig) : base($config, $globalConfig) {}
    
    [ActionResult] Execute([hashtable]$context) {
        $this.LogInfo("Starting CreateBastion action for scope: $($context.scope)")
        
        if ($this.GlobalConfig.dryRun) {
            $this.LogInfo("DRY RUN: Would create Bastion for scope: $($context.scope)")
            return [ActionResult]::new($true, "Dry run completed successfully", @{
                action = "CreateBastion"
                scope = $context.scope
                dryRun = $true
            })
        }
        
        try {
            # Extract resource information from scope
            $resourceInfo = $this.ParseScope($context.scope)
            if (-not $resourceInfo) {
                return [ActionResult]::new($false, "Could not parse resource scope", @{})
            }
            
            # Check if Bastion already exists
            $existingBastion = $this.FindExistingBastion($resourceInfo.ResourceGroupName, $resourceInfo.SubscriptionId)
            if ($existingBastion) {
                $this.LogInfo("Bastion already exists: $($existingBastion.Name)")
                return [ActionResult]::new($true, "Bastion already exists", @{
                    action = "CreateBastion"
                    existingBastion = $existingBastion.Name
                    skipped = $true
                })
            }
            
            # Create Bastion
            $result = $this.CreateBastion($resourceInfo)
            
            return [ActionResult]::new($true, "Bastion created successfully", @{
                action = "CreateBastion"
                bastionName = $result.Name
                resourceGroup = $resourceInfo.ResourceGroupName
                subscriptionId = $resourceInfo.SubscriptionId
            })
        }
        catch {
            $this.LogError("Failed to create Bastion: $($_.Exception.Message)")
            return [ActionResult]::new($false, "Failed to create Bastion: $($_.Exception.Message)", @{
                error = $_.Exception.Message
            })
        }
    }
    
    [hashtable] ParseScope([string]$scope) {
        # Parse Azure resource scope
        # Example: /subscriptions/11b74992-d520-46e1-a9e9-b55c57d2e890/providers/Microsoft.Authorization/roleAssignments/d6f61a53-f73c-4631-a59a-02d594ca5c9d
        if ($scope -match '/subscriptions/([^/]+)') {
            $subscriptionId = $Matches[1]
            
            # For simplicity, derive resource group name from subscription
            # In real scenarios, you might want to extract this from additional context
            $resourceGroupName = $this.GlobalConfig.defaultResourceGroupPattern -replace '\{subscriptionId\}', $subscriptionId
            
            return @{
                SubscriptionId = $subscriptionId
                ResourceGroupName = $resourceGroupName
            }
        }
        
        return $null
    }
    
    [object] FindExistingBastion([string]$resourceGroupName, [string]$subscriptionId) {
        try {
            $this.LogInfo("Checking for existing Bastion in RG: $resourceGroupName")
            
            # Set context to correct subscription
            Set-AzContext -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
            
            # Look for existing Bastion hosts
            $bastions = Get-AzBastion -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
            
            return $bastions | Select-Object -First 1
        }
        catch {
            $this.LogWarning("Could not check for existing Bastion: $($_.Exception.Message)")
            return $null
        }
    }
    
    [object] CreateBastion([hashtable]$resourceInfo) {
        $this.LogInfo("Creating Bastion in subscription: $($resourceInfo.SubscriptionId)")
        
        # Set context to correct subscription
        Set-AzContext -SubscriptionId $resourceInfo.SubscriptionId
        
        $bastionName = "$($this.Config.parameters.bastionNamePrefix)-$(Get-Random -Maximum 9999)"
        $publicIpName = "$($this.Config.parameters.publicIpNamePrefix)-$(Get-Random -Maximum 9999)"
        
        # Create or get virtual network
        $vnet = $this.EnsureVirtualNetwork($resourceInfo.ResourceGroupName)
        
        # Create or get Bastion subnet
        $bastionSubnet = $this.EnsureBastionSubnet($vnet)
        
        # Create public IP
        $publicIp = $this.CreatePublicIp($publicIpName, $resourceInfo.ResourceGroupName)
        
        # Create Bastion
        $this.LogInfo("Creating Bastion host: $bastionName")
        
        $bastion = New-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName `
                                 -Name $bastionName `
                                 -PublicIpAddress $publicIp `
                                 -VirtualNetwork $vnet `
                                 -Tag $this.GlobalConfig.tags
        
        $this.LogInfo("Bastion created successfully: $($bastion.Name)")
        return $bastion
    }
    
    [object] EnsureVirtualNetwork([string]$resourceGroupName) {
        # Try to find existing VNet, or create a simple one
        $vnets = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
        
        if ($vnets) {
            $this.LogInfo("Using existing VNet: $($vnets[0].Name)")
            return $vnets[0]
        }
        
        # Create a simple VNet for Bastion
        $this.LogInfo("Creating new VNet for Bastion")
        $vnetName = "vnet-bastion-auto-$(Get-Random -Maximum 9999)"
        
        $vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName `
                                     -Location "East US" `
                                     -Name $vnetName `
                                     -AddressPrefix "10.0.0.0/16" `
                                     -Tag $this.GlobalConfig.tags
        
        return $vnet
    }
    
    [object] EnsureBastionSubnet([object]$vnet) {
        # Check if AzureBastionSubnet exists
        $bastionSubnet = $vnet.Subnets | Where-Object { $_.Name -eq "AzureBastionSubnet" }
        
        if ($bastionSubnet) {
            $this.LogInfo("Using existing AzureBastionSubnet")
            return $bastionSubnet
        }
        
        # Create Bastion subnet
        $this.LogInfo("Creating AzureBastionSubnet")
        $subnetConfig = Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet `
                                                         -Name "AzureBastionSubnet" `
                                                         -AddressPrefix $this.Config.parameters.subnetAddressPrefix
        
        $vnet | Set-AzVirtualNetwork | Out-Null
        
        # Refresh VNet object
        $updatedVnet = Get-AzVirtualNetwork -ResourceGroupName $vnet.ResourceGroupName -Name $vnet.Name
        return $updatedVnet.Subnets | Where-Object { $_.Name -eq "AzureBastionSubnet" }
    }
    
    [object] CreatePublicIp([string]$publicIpName, [string]$resourceGroupName) {
        $this.LogInfo("Creating public IP: $publicIpName")
        
        return New-AzPublicIpAddress -ResourceGroupName $resourceGroupName `
                                     -Location "East US" `
                                     -Name $publicIpName `
                                     -AllocationMethod Static `
                                     -Sku Standard `
                                     -Tag $this.GlobalConfig.tags
    }
}

class CleanupBastionAction : BaseAction {
    CleanupBastionAction([hashtable]$config, [hashtable]$globalConfig) : base($config, $globalConfig) {}
    
    [ActionResult] Execute([hashtable]$context) {
        $this.LogInfo("Starting CleanupBastion action for scope: $($context.scope)")
        
        if ($this.GlobalConfig.dryRun) {
            $this.LogInfo("DRY RUN: Would cleanup Bastion for scope: $($context.scope)")
            return [ActionResult]::new($true, "Dry run completed successfully", @{
                action = "CleanupBastion"
                scope = $context.scope
                dryRun = $true
            })
        }
        
        try {
            # Extract resource information from scope
            $resourceInfo = $this.ParseScope($context.scope)
            if (-not $resourceInfo) {
                return [ActionResult]::new($false, "Could not parse resource scope", @{})
            }
            
            # Check if we should preserve Bastion due to other assignments
            if ($this.Config.parameters.preserveIfOtherAssignments) {
                $hasOtherAssignments = $this.CheckForOtherRoleAssignments($resourceInfo)
                if ($hasOtherAssignments) {
                    $this.LogInfo("Preserving Bastion due to other role assignments")
                    return [ActionResult]::new($true, "Bastion preserved due to other assignments", @{
                        action = "CleanupBastion"
                        preserved = $true
                        reason = "Other role assignments exist"
                    })
                }
            }
            
            # Find and remove Bastion
            $result = $this.RemoveBastion($resourceInfo)
            
            return [ActionResult]::new($true, "Bastion cleanup completed", @{
                action = "CleanupBastion"
                removed = $result.Removed
                bastionName = $result.BastionName
            })
        }
        catch {
            $this.LogError("Failed to cleanup Bastion: $($_.Exception.Message)")
            return [ActionResult]::new($false, "Failed to cleanup Bastion: $($_.Exception.Message)", @{
                error = $_.Exception.Message
            })
        }
    }
    
    [hashtable] ParseScope([string]$scope) {
        # Same parsing logic as CreateBastionAction
        if ($scope -match '/subscriptions/([^/]+)') {
            $subscriptionId = $Matches[1]
            $resourceGroupName = $this.GlobalConfig.defaultResourceGroupPattern -replace '\{subscriptionId\}', $subscriptionId
            
            return @{
                SubscriptionId = $subscriptionId
                ResourceGroupName = $resourceGroupName
            }
        }
        
        return $null
    }
    
    [bool] CheckForOtherRoleAssignments([hashtable]$resourceInfo) {
        # In a real implementation, you would check for other VM admin role assignments
        # For now, return false to allow cleanup
        $this.LogInfo("Checking for other role assignments (simplified implementation)")
        return $false
    }
    
    [hashtable] RemoveBastion([hashtable]$resourceInfo) {
        # Set context to correct subscription
        Set-AzContext -SubscriptionId $resourceInfo.SubscriptionId
        
        # Find Bastion hosts
        $bastions = Get-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName -ErrorAction SilentlyContinue
        
        if (-not $bastions) {
            $this.LogInfo("No Bastion hosts found to remove")
            return @{ Removed = $false; BastionName = $null }
        }
        
        $bastionToRemove = $bastions | Where-Object { $_.Name -like "*auto*" } | Select-Object -First 1
        
        if ($bastionToRemove) {
            $this.LogInfo("Removing Bastion: $($bastionToRemove.Name)")
            Remove-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName -Name $bastionToRemove.Name -Force
            
            return @{ Removed = $true; BastionName = $bastionToRemove.Name }
        }
        
        return @{ Removed = $false; BastionName = $null }
    }
}

# Action factory function
function New-Action {
    param(
        [string]$ActionName,
        [hashtable]$Config,
        [hashtable]$GlobalConfig
    )
    
    switch ($ActionName) {
        "CreateBastion" { 
            return [CreateBastionAction]::new($Config, $GlobalConfig) 
        }
        "CleanupBastion" { 
            return [CleanupBastionAction]::new($Config, $GlobalConfig) 
        }
        default { 
            throw "Unknown action: $ActionName" 
        }
    }
}