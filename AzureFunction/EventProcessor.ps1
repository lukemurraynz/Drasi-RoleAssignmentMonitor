# Modular action handlers for Azure resource automation

# Configuration management class
class ConfigurationManager {
    [hashtable]$Config
    [string]$ConfigPath
    
    ConfigurationManager([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.LoadConfiguration()
    }
    
    [void] LoadConfiguration() {
        if (Test-Path $this.ConfigPath) {
            $configContent = Get-Content $this.ConfigPath -Raw | ConvertFrom-Json
            $this.Config = $this.ConvertPSObjectToHashtable($configContent)
        } else {
            throw "Configuration file not found: $($this.ConfigPath)"
        }
    }
    
    [hashtable] ConvertPSObjectToHashtable([object]$inputObject) {
        $output = @{}
        if ($inputObject -is [PSCustomObject]) {
            foreach ($property in $inputObject.PSObject.Properties) {
                if ($property.Value -is [PSCustomObject]) {
                    $output[$property.Name] = $this.ConvertPSObjectToHashtable($property.Value)
                } elseif ($property.Value -is [array]) {
                    $output[$property.Name] = @()
                    foreach ($item in $property.Value) {
                        if ($item -is [PSCustomObject]) {
                            $output[$property.Name] += $this.ConvertPSObjectToHashtable($item)
                        } else {
                            $output[$property.Name] += $item
                        }
                    }
                } else {
                    $output[$property.Name] = $property.Value
                }
            }
        } else {
            return $inputObject
        }
        return $output
    }
    
    [hashtable] GetGlobalConfiguration() {
        return $this.Config.global
    }
    
    [hashtable] GetActionConfiguration([string]$actionName) {
        return $this.Config.actions.$actionName
    }
    
    [string] GetRoleName([string]$roleDefinitionId) {
        if ($this.Config.roleMappings -and $this.Config.roleMappings.$roleDefinitionId) {
            return $this.Config.roleMappings.$roleDefinitionId
        }
        return "Unknown Role ($roleDefinitionId)"
    }
}

# Event parsing class for Drasi events

static [hashtable] ParseDrasiEvent([hashtable]$eventGridEvent) {
    $result = @{
        isValid = $false
        operationType = $null
        roleDefinitionId = $null
        scope = $null
        principalId = $null
        correlationId = $null
        timestamp = $null
        callerIpAddress = $null
        azureOperationName = $null  # Add this field
    }
    
    try {
        # Check if this is a Drasi ChangeEvent
        if ($eventGridEvent.type -ne 'Drasi.ChangeEvent') {
            return $result
        }
        
        $data = $eventGridEvent.data
        if (-not $data -or -not $data.payload -or -not $data.payload.after) {
            return $result
        }
        
        $payload = $data.payload.after
        
        # Capture the actual Azure operation name
        $result.azureOperationName = $payload.operationName
        
        # Check if this is a role assignment operation (CREATE or DELETE)
        $isRoleWrite = $payload.operationName -eq 'MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE'
        $isRoleDelete = $payload.operationName -eq 'MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/DELETE'
        
        if (-not ($isRoleWrite -or $isRoleDelete)) {
            return $result
        }
        
        $result.isValid = $true
        $result.operationType = $data.op # 'i' for insert/create, 'd' for delete
        $result.correlationId = $payload.correlationId
        $result.timestamp = $payload.timestamp
        $result.callerIpAddress = $payload.callerIpAddress
        
        if ($isRoleWrite -and $payload.properties.requestbody) {
            # Parse the request body to get role assignment details for CREATE operations
            $requestBody = $payload.properties.requestbody | ConvertFrom-Json
            $result.roleDefinitionId = $requestBody.Properties.RoleDefinitionId
            $result.scope = $requestBody.Properties.Scope
            $result.principalId = $requestBody.Properties.PrincipalId
        } elseif ($isRoleDelete) {
            # For DELETE operations, extract from the resource ID and response body
            $resourceId = $payload.resourceId
            if ($resourceId -match '/subscriptions/([^/]+)') {
                $result.scope = "/subscriptions/$($Matches[1])"
            }
            
            # Try to extract role definition from response body if available
            if ($payload.properties.responseBody) {
                try {
                    $responseBody = $payload.properties.responseBody | ConvertFrom-Json
                    $result.roleDefinitionId = $responseBody.properties.roleDefinitionId
                    $result.principalId = $responseBody.properties.principalId
                } catch {
                    # Fallback to VM Admin Login role assumption
                    $result.roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"
                    $result.principalId = "unknown"
                }
            } else {
                # Fallback values for DELETE operations without response body
                $result.roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"
                $result.principalId = "unknown"
            }
        }
        
        return $result
    }
    catch {
        Write-Warning "Failed to parse Drasi event: $($_.Exception.Message)"
        return $result
    }
}

# Action orchestrator class
class ActionOrchestrator {
    [ConfigurationManager]$ConfigManager
    
    ActionOrchestrator([ConfigurationManager]$configManager) {
        $this.ConfigManager = $configManager
    }
    
    [array] ProcessEvent([hashtable]$parsedEvent) {
        $results = @()
        $globalConfig = $this.ConfigManager.GetGlobalConfiguration()
        
        # Determine which actions to execute based on the event
        $actionsToExecute = $this.DetermineActions($parsedEvent)
        
        foreach ($actionName in $actionsToExecute) {
            try {
                $actionConfig = $this.ConfigManager.GetActionConfiguration($actionName)
                if (-not $actionConfig) {
                    $results += [ActionResult]::new($false, "Configuration not found for action: $actionName", @{})
                    continue
                }
                
                # Create action instance
                $action = New-Action -ActionName $actionName -Config $actionConfig -GlobalConfig $globalConfig
                
                # Create context for action execution
                $context = @{
                    scope = $parsedEvent.scope
                    principalId = $parsedEvent.principalId
                    roleDefinitionId = $parsedEvent.roleDefinitionId
                    operationType = $parsedEvent.operationType
                    correlationId = $parsedEvent.correlationId
                }
                
                # Execute action
                $result = $action.Execute($context)
                $result.Details.action = $actionName
                $results += $result
            }
            catch {
                $results += [ActionResult]::new($false, "Failed to execute action $actionName`: $($_.Exception.Message)", @{
                    action = $actionName
                    error = $_.Exception.Message
                })
            }
        }
        
        return $results
    }


[array] DetermineActions([hashtable]$parsedEvent) {
    $actions = @()
    $globalConfig = $this.ConfigManager.GetGlobalConfiguration()
    
    # Check if this is a VM Admin Login role (1c0163c0-47e6-4577-8991-ea5c82e286e4)
    $vmAdminLoginRoleId = "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"
    
    if ($parsedEvent.roleDefinitionId -eq $vmAdminLoginRoleId) {
        # The key fix: Look at the actual Azure operation, not just the Drasi operation
        # Since all events come as 'i' (insert) in Drasi, we need to check what actually happened in Azure
        
        # Parse the operation type from the event data to determine actual Azure action
        $isRoleCreation = $false
        $isRoleDeletion = $false
        
        # Check if this represents a role assignment creation or deletion
        # For role assignments, we need to look at the Azure operation name in the audit log
        if ($parsedEvent.operationType -eq 'i') {
            # This is a new audit log entry, but we need to check what Azure operation it represents
            # The operation name is embedded in the event data
            
            # Access the original event data to get the actual Azure operation
            $azureOperationName = $this.GetAzureOperationFromEvent($parsedEvent)
            
            if ($azureOperationName -like "*WRITE*" -or $azureOperationName -like "*PUT*") {
                # Role assignment was created/granted
                $isRoleCreation = $true
                $actions += "CreateBastion"
            } elseif ($azureOperationName -like "*DELETE*") {
                # Role assignment was deleted/removed
                $isRoleDeletion = $true
                $actions += "CleanupBastion"
            }
        } elseif ($parsedEvent.operationType -eq 'd') {
            # This would be a deletion of the audit log entry itself (rare)
            # For now, we'll treat this as no action needed
        }
    }
    
    return $actions
}

[string] GetAzureOperationFromEvent([hashtable]$parsedEvent) {
    # This method should extract the actual Azure operation name from the parsed event
    # You'll need to pass this information through from the original event parsing
    # For now, we'll use a simplified approach and check if we have context about the operation
    
    # If the parsed event contains operation context, use it
    if ($parsedEvent.ContainsKey('azureOperationName')) {
        return $parsedEvent.azureOperationName
    }
    
    # Fallback: if we have a principalId of "unknown", it's likely a DELETE operation
    # since DELETE operations don't contain the principal ID in the response
    if ($parsedEvent.principalId -eq "unknown") {
        return "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/DELETE"
    }
    
    # Default to WRITE operation
    return "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE"
}


    
}

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
        # Prefer explicit config values if set, otherwise parse from scope
        $subscriptionId = $null
        $resourceGroupName = $null

        if ($this.Config.parameters.subscriptionId -and $this.Config.parameters.subscriptionId -ne '<your-subscription-id>') {
            $subscriptionId = $this.Config.parameters.subscriptionId
        } elseif ($this.GlobalConfig.defaultSubscriptionId) {
            $subscriptionId = $this.GlobalConfig.defaultSubscriptionId
        } elseif ($scope -match '/subscriptions/([^/]+)') {
            $subscriptionId = $Matches[1]
        }

        if ($this.Config.parameters.resourceGroupName -and $this.Config.parameters.resourceGroupName -ne '<your-resource-group>') {
            $resourceGroupName = $this.Config.parameters.resourceGroupName
        } elseif ($this.GlobalConfig.defaultResourceGroupName) {
            $resourceGroupName = $this.GlobalConfig.defaultResourceGroupName
        } elseif ($subscriptionId -and $this.GlobalConfig.defaultResourceGroupPattern) {
            $resourceGroupName = $this.GlobalConfig.defaultResourceGroupPattern -replace '\{subscriptionId\}', $subscriptionId
        }

        if ($subscriptionId -and $resourceGroupName) {
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

        # Ensure Resource Group exists
        $rg = Get-AzResourceGroup -Name $resourceInfo.ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            $this.LogInfo("Resource group '$($resourceInfo.ResourceGroupName)' does not exist. Creating it.")
            $location = "New Zealand North"  # Default location; optionally make this configurable
            $rg = New-AzResourceGroup -Name $resourceInfo.ResourceGroupName -Location $location -Tag $this.GlobalConfig.tags
        } else {
            $this.LogInfo("Resource group '$($resourceInfo.ResourceGroupName)' already exists.")
            $location = $rg.Location
        }

        # Use bastionName from config if set, else generate
        if ($this.Config.parameters.bastionName -and $this.Config.parameters.bastionName -ne '<your-bastion-name>') {
            $bastionName = $this.Config.parameters.bastionName
        } else {
            $bastionName = "$($this.Config.parameters.bastionNamePrefix)-$(Get-Random -Maximum 9999)"
        }
        $publicIpName = "$($this.Config.parameters.publicIpNamePrefix)-$(Get-Random -Maximum 9999)"
        
        # Create or get virtual network
        $vnet = $this.EnsureVirtualNetwork($resourceInfo.ResourceGroupName, $location)
        
        # Create or get Bastion subnet
        $bastionSubnet = $this.EnsureBastionSubnet($vnet)
        
        # Create public IP
        $publicIp = $this.CreatePublicIp($publicIpName, $resourceInfo.ResourceGroupName, $location)
        
        # Create Bastion
        $this.LogInfo("Creating Bastion host: $bastionName")

        $bastion = New-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName `
                                 -Name $bastionName `
                                 -PublicIpAddressRgName $resourceInfo.ResourceGroupName `
                                 -PublicIpAddressName $publicIp.Name `
                                 -VirtualNetworkRgName $resourceInfo.ResourceGroupName `
                                 -VirtualNetworkName $vnet.Name `
                                 -Sku "Standard" `
                                 -ScaleUnit 2
        
        $this.LogInfo("Bastion created successfully: $($bastion.Name)")
        return $bastion
    }
    
    [object] EnsureVirtualNetwork([string]$resourceGroupName, [string]$location) {
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
                                     -Location $location `
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
    
    [object] CreatePublicIp([string]$publicIpName, [string]$resourceGroupName, [string]$location) {
        $this.LogInfo("Creating public IP: $publicIpName")
        
        return New-AzPublicIpAddress -ResourceGroupName $resourceGroupName `
                                     -Location $location `
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
        
        $publicIpRemoved = $false
        $publicIpName = $null
        if ($bastionToRemove) {
            $this.LogInfo("Removing Bastion: $($bastionToRemove.Name)")
            # Get the public IP resource ID from the Bastion's IP configuration
            $publicIpId = $bastionToRemove.IpConfigurations[0].PublicIpAddress.Id
            if ($publicIpId) {
                $publicIpName = ($publicIpId -split "/")[-1]
            }
            Remove-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName -Name $bastionToRemove.Name -Force
            # Remove the associated Public IP if found
            if ($publicIpName) {
                $this.LogInfo("Removing Public IP: $publicIpName")
                Remove-AzPublicIpAddress -ResourceGroupName $resourceInfo.ResourceGroupName -Name $publicIpName -Force -ErrorAction SilentlyContinue
                $publicIpRemoved = $true
            }
            return @{ Removed = $true; BastionName = $bastionToRemove.Name; PublicIpRemoved = $publicIpRemoved; PublicIpName = $publicIpName }
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