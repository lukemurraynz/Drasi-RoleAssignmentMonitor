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
    if ($this.Config.roleMappings) {
        foreach ($key in $this.Config.roleMappings.Keys) {
            # Match if the roleDefinitionId ends with the mapping key (handles any prefix)
            if ($roleDefinitionId -like "*$key") {
                return $this.Config.roleMappings.$key
            }
        }
    }
    return "Unknown Role ($roleDefinitionId)"
}
}

# Event parsing function for Drasi events
function Parse-DrasiEvent {
    param([hashtable]$eventGridEvent)
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
                $extractedSubId = $Matches[1]
                # Validate the subscription ID format before using it
                if ($extractedSubId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    $result.scope = "/subscriptions/$extractedSubId"
                } else {
                    # If the extracted subscription ID is malformed, don't set scope
                    # Let the action classes handle this using their config values
                    Write-Warning "Extracted subscription ID '$extractedSubId' is not in valid GUID format, scope will be handled by action configuration"
                }
            }

            # Try to extract role definition from response body if available
            try {
                # Ensure responseBody is parsed from string if needed
                $responseBodyRaw = $payload.properties.responseBody
                if ($responseBodyRaw -is [string]) {
                    $responseBody = $responseBodyRaw | ConvertFrom-Json
                } else {
                    $responseBody = $responseBodyRaw
                }
                $result.roleDefinitionId = $responseBody.properties.roleDefinitionId
                $result.principalId = $responseBody.properties.principalId
            } catch {
                # Fallback to VM Admin Login role assumption
                $result.roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"
                $result.principalId = "unknown"
            }
            # Fallback values for DELETE operations without response body (if above fails)
            if (-not $result.roleDefinitionId) {
                $result.roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"
            }
            if (-not $result.principalId) {
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
        
        if ($actionsToExecute.Count -eq 0) {
            $results += [ActionResult]::new($true, "No actions determined for this event", @{
                reason = "Event did not match action criteria"
                roleDefinitionId = $parsedEvent.roleDefinitionId
                operationType = $parsedEvent.operationType
                azureOperationName = $parsedEvent.azureOperationName
            })
            return $results
        }
        
        foreach ($actionName in $actionsToExecute) {
            try {
                $actionConfig = $this.ConfigManager.GetActionConfiguration($actionName)
                if (-not $actionConfig) {
                    $results += [ActionResult]::new($false, "Configuration not found for action: $actionName", @{})
                    continue
                }
                
                if (-not $actionConfig.enabled) {
                    $results += [ActionResult]::new($true, "Action skipped (disabled): $actionName", @{
                        action = $actionName
                        skipped = $true
                    })
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
                    stackTrace = $_.ScriptStackTrace
                })
            }
        }
        
        return $results
    }


[array] DetermineActions([hashtable]$parsedEvent) {
    $actions = @()
    $globalConfig = $this.ConfigManager.GetGlobalConfiguration()
    
    $vmAdminLoginRoleId = "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"

    # Debug: Log all relevant information
    Write-Host "[DEBUG] DetermineActions: operationType=$($parsedEvent.operationType), azureOperationName=$($parsedEvent.azureOperationName), roleDefinitionId=$($parsedEvent.roleDefinitionId)"

    # Check if this is a VM Admin Login role
    if ($parsedEvent.roleDefinitionId -like "*$vmAdminLoginRoleId*") {
        # Use the actual Azure operation name to determine action
        $azureOperationName = $parsedEvent.azureOperationName
        
        if ($azureOperationName -like "*DELETE*") {
            Write-Host "[DEBUG] Scheduling CleanupBastion action for DELETE operation"
            $actions += "CleanupBastion"
        } elseif ($azureOperationName -like "*WRITE*") {
            Write-Host "[DEBUG] Scheduling CreateBastion action for WRITE operation"
            $actions += "CreateBastion"
        } else {
            Write-Host "[DEBUG] Unknown Azure operation: $azureOperationName"
        }
    } else {
        Write-Host "[DEBUG] Role $($parsedEvent.roleDefinitionId) is not VM Admin Login role"
    }
    
    Write-Host "[DEBUG] Determined actions: $($actions -join ', ')"
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
        
        # Add extensive debugging for configuration
        $this.LogInfo("=== DEBUGGING CONFIGURATION ===")
        $this.LogInfo("GlobalConfig type: $($this.GlobalConfig.GetType().Name)")
        $this.LogInfo("GlobalConfig keys: $($this.GlobalConfig.Keys -join ', ')")
        $this.LogInfo("Config type: $($this.Config.GetType().Name)")
        $this.LogInfo("Config keys: $($this.Config.Keys -join ', ')")
        
        if ($this.GlobalConfig) {
            foreach ($key in $this.GlobalConfig.Keys) {
                $value = $this.GlobalConfig[$key]
                $valueType = if ($value) { $value.GetType().Name } else { 'null' }
                $this.LogInfo("GlobalConfig[$key] = '$value' (type: $valueType)")
            }
        }
        
        if ($this.Config -and $this.Config.parameters) {
            $this.LogInfo("Config.parameters keys: $($this.Config.parameters.Keys -join ', ')")
            foreach ($key in $this.Config.parameters.Keys) {
                $value = $this.Config.parameters[$key]
                $valueType = if ($value) { $value.GetType().Name } else { 'null' }
                $this.LogInfo("Config.parameters[$key] = '$value' (type: $valueType)")
            }
        }
        $this.LogInfo("=== END CONFIGURATION DEBUG ===")
        
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
        # Always use config values - completely ignore parsed scope
        $subscriptionId = $null
        $resourceGroupName = $null

        $this.LogInfo("ParseScope called for CreateBastion - ignoring scope parameter and using config values only")

        # Debug the global config structure
        $this.LogInfo("GlobalConfig keys: $($this.GlobalConfig.Keys -join ', ')")
        $this.LogInfo("GlobalConfig.defaultSubscriptionId exists: $($this.GlobalConfig.ContainsKey('defaultSubscriptionId'))")
        $this.LogInfo("GlobalConfig.defaultResourceGroupName exists: $($this.GlobalConfig.ContainsKey('defaultResourceGroupName'))")

        # Always use global config values first (most reliable and consistent)
        if ($this.GlobalConfig.ContainsKey('defaultSubscriptionId') -and $this.GlobalConfig.defaultSubscriptionId) {
            $subscriptionId = $this.GlobalConfig.defaultSubscriptionId
            $this.LogInfo("Using default subscription ID from global config: $subscriptionId")
        } elseif ($this.Config.parameters.ContainsKey('subscriptionId') -and $this.Config.parameters.subscriptionId -and $this.Config.parameters.subscriptionId -ne '<your-subscription-id>') {
            $subscriptionId = $this.Config.parameters.subscriptionId
            $this.LogInfo("Using subscription ID from action config: $subscriptionId")
        }

        # Always use global config values first (most reliable and consistent)
        if ($this.GlobalConfig.ContainsKey('defaultResourceGroupName') -and $this.GlobalConfig.defaultResourceGroupName) {
            $resourceGroupName = $this.GlobalConfig.defaultResourceGroupName
            $this.LogInfo("Using default resource group from global config: $resourceGroupName")
        } elseif ($this.Config.parameters.ContainsKey('resourceGroupName') -and $this.Config.parameters.resourceGroupName -and $this.Config.parameters.resourceGroupName -ne '<your-resource-group>') {
            $resourceGroupName = $this.Config.parameters.resourceGroupName
            $this.LogInfo("Using resource group from action config: $resourceGroupName")
        }

        # Validate that we have both required values
        if (-not $subscriptionId) {
            $this.LogError("No subscription ID found in configuration")
            $this.LogError("Global config defaultSubscriptionId: '$($this.GlobalConfig.defaultSubscriptionId)'")
            $this.LogError("Action config subscriptionId: '$($this.Config.parameters.subscriptionId)'")
            $this.LogError("Full GlobalConfig: $($this.GlobalConfig | ConvertTo-Json -Depth 2)")
            return $null
        }

        if (-not $resourceGroupName) {
            $this.LogError("No resource group name found in configuration")
            $this.LogError("Global config defaultResourceGroupName: '$($this.GlobalConfig.defaultResourceGroupName)'")
            $this.LogError("Action config resourceGroupName: '$($this.Config.parameters.resourceGroupName)'")
            $this.LogError("Full GlobalConfig: $($this.GlobalConfig | ConvertTo-Json -Depth 2)")
            return $null
        }

        # Validate subscription ID format
        if (-not ($subscriptionId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
            $this.LogError("Invalid subscription ID format in config: '$subscriptionId'")
            return $null
        }

        $this.LogInfo("Successfully parsed config values for CreateBastion - Subscription: $subscriptionId, ResourceGroup: $resourceGroupName")
        return @{
            SubscriptionId = $subscriptionId
            ResourceGroupName = $resourceGroupName
        }
    }
    
    [object] FindExistingBastion([string]$resourceGroupName, [string]$subscriptionId) {
        try {
            $this.LogInfo("Checking for existing Bastion in RG: $resourceGroupName, Subscription: $subscriptionId")
            
            # Validate subscription ID format
            if (-not ($subscriptionId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
                $this.LogWarning("Invalid subscription ID format: $subscriptionId")
                return $null
            }
            
            # Set context to correct subscription with error handling
            $context = Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
            $this.LogInfo("Successfully set Azure context to subscription: $($context.Subscription.Name)")
            
            # Look for existing Bastion hosts
            $bastions = Get-AzBastion -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
            
            if ($bastions) {
                $this.LogInfo("Found $($bastions.Count) existing Bastion host(s)")
                return $bastions | Select-Object -First 1
            } else {
                $this.LogInfo("No existing Bastion hosts found")
                return $null
            }
        }
        catch {
            $this.LogWarning("Could not check for existing Bastion: $($_.Exception.Message)")
            return $null
        }
    }
    
    [object] CreateBastion([hashtable]$resourceInfo) {
        $this.LogInfo("Creating Bastion in subscription: $($resourceInfo.SubscriptionId)")
        
        # Validate subscription ID format
        if (-not ($resourceInfo.SubscriptionId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
            throw "Invalid subscription ID format: $($resourceInfo.SubscriptionId)"
        }
        
        # Set context to correct subscription with proper error handling
        try {
            $context = Set-AzContext -SubscriptionId $resourceInfo.SubscriptionId -ErrorAction Stop
            $this.LogInfo("Successfully set Azure context to subscription: $($context.Subscription.Name)")
        }
        catch {
            throw "Failed to set Azure context for subscription $($resourceInfo.SubscriptionId): $($_.Exception.Message)"
        }

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
        
        # Add extensive debugging for configuration
        $this.LogInfo("=== DEBUGGING CONFIGURATION ===")
        $this.LogInfo("GlobalConfig type: $($this.GlobalConfig.GetType().Name)")
        $this.LogInfo("GlobalConfig keys: $($this.GlobalConfig.Keys -join ', ')")
        $this.LogInfo("Config type: $($this.Config.GetType().Name)")
        $this.LogInfo("Config keys: $($this.Config.Keys -join ', ')")
        
        if ($this.GlobalConfig) {
            foreach ($key in $this.GlobalConfig.Keys) {
                $value = $this.GlobalConfig[$key]
                $valueType = if ($value) { $value.GetType().Name } else { 'null' }
                $this.LogInfo("GlobalConfig[$key] = '$value' (type: $valueType)")
            }
        }
        
        if ($this.Config -and $this.Config.parameters) {
            $this.LogInfo("Config.parameters keys: $($this.Config.parameters.Keys -join ', ')")
            foreach ($key in $this.Config.parameters.Keys) {
                $value = $this.Config.parameters[$key]
                $valueType = if ($value) { $value.GetType().Name } else { 'null' }
                $this.LogInfo("Config.parameters[$key] = '$value' (type: $valueType)")
            }
        }
        $this.LogInfo("=== END CONFIGURATION DEBUG ===")
        
        try {
            # Extract resource information from scope
            $resourceInfo = $this.ParseScope($context.scope)
            if (-not $resourceInfo) {
                $errorMsg = "Could not parse resource scope: $($context.scope)"
                $this.LogError($errorMsg)
                return [ActionResult]::new($false, $errorMsg, @{
                    action = "CleanupBastion"
                    scope = $context.scope
                    globalConfig = $this.GlobalConfig | ConvertTo-Json -Depth 2
                })
            }
            
            $this.LogInfo("Parsed resource info - SubscriptionId: $($resourceInfo.SubscriptionId), ResourceGroupName: $($resourceInfo.ResourceGroupName)")
            
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
            
            # Check if there was an error in RemoveBastion
            if ($result.ContainsKey('Error')) {
                return [ActionResult]::new($false, "Failed to cleanup Bastion: $($result.Error)", @{
                    action = "CleanupBastion"
                    error = $result.Error
                    resourceInfo = $resourceInfo
                })
            }
            
            return [ActionResult]::new($true, "Bastion cleanup completed", @{
                action = "CleanupBastion"
                removed = $result.Removed
                bastionName = $result.BastionName
                publicIpRemoved = $result.PublicIpRemoved
                publicIpName = $result.PublicIpName
                resourceInfo = $resourceInfo
            })
        }
        catch {
            $errorMsg = "Failed to cleanup Bastion: $($_.Exception.Message)"
            $this.LogError($errorMsg)
            $this.LogError("Stack trace: $($_.ScriptStackTrace)")
            return [ActionResult]::new($false, $errorMsg, @{
                action = "CleanupBastion"
                error = $_.Exception.Message
                stackTrace = $_.ScriptStackTrace
                scope = $context.scope
                globalConfig = $this.GlobalConfig | ConvertTo-Json -Depth 2
            })
        }
    }
    
    [hashtable] ParseScope([string]$scope) {
        # Always use config values - completely ignore parsed scope  
        $subscriptionId = $null
        $resourceGroupName = $null

        $this.LogInfo("ParseScope called for CleanupBastion - ignoring scope parameter and using config values only")

        # Debug the global config structure
        $this.LogInfo("GlobalConfig keys: $($this.GlobalConfig.Keys -join ', ')")
        $this.LogInfo("GlobalConfig.defaultSubscriptionId exists: $($this.GlobalConfig.ContainsKey('defaultSubscriptionId'))")
        $this.LogInfo("GlobalConfig.defaultResourceGroupName exists: $($this.GlobalConfig.ContainsKey('defaultResourceGroupName'))")

        # Always use global config values first (most reliable and consistent)
        if ($this.GlobalConfig.ContainsKey('defaultSubscriptionId') -and $this.GlobalConfig.defaultSubscriptionId) {
            $subscriptionId = $this.GlobalConfig.defaultSubscriptionId
            $this.LogInfo("Using default subscription ID from global config: $subscriptionId")
        } elseif ($this.Config.parameters.ContainsKey('subscriptionId') -and $this.Config.parameters.subscriptionId -and $this.Config.parameters.subscriptionId -ne '<your-subscription-id>') {
            $subscriptionId = $this.Config.parameters.subscriptionId
            $this.LogInfo("Using subscription ID from action config: $subscriptionId")
        }

        # Always use global config values first (most reliable and consistent)
        if ($this.GlobalConfig.ContainsKey('defaultResourceGroupName') -and $this.GlobalConfig.defaultResourceGroupName) {
            $resourceGroupName = $this.GlobalConfig.defaultResourceGroupName
            $this.LogInfo("Using default resource group from global config: $resourceGroupName")
        } elseif ($this.Config.parameters.ContainsKey('resourceGroupName') -and $this.Config.parameters.resourceGroupName -and $this.Config.parameters.resourceGroupName -ne '<your-resource-group>') {
            $resourceGroupName = $this.Config.parameters.resourceGroupName
            $this.LogInfo("Using resource group from action config: $resourceGroupName")
        }

        # Validate that we have both required values
        if (-not $subscriptionId) {
            $this.LogError("No subscription ID found in configuration")
            $this.LogError("Global config defaultSubscriptionId: '$($this.GlobalConfig.defaultSubscriptionId)'")
            $this.LogError("Action config subscriptionId: '$($this.Config.parameters.subscriptionId)'")
            $this.LogError("Full GlobalConfig: $($this.GlobalConfig | ConvertTo-Json -Depth 2)")
            return $null
        }

        if (-not $resourceGroupName) {
            $this.LogError("No resource group name found in configuration")
            $this.LogError("Global config defaultResourceGroupName: '$($this.GlobalConfig.defaultResourceGroupName)'")
            $this.LogError("Action config resourceGroupName: '$($this.Config.parameters.resourceGroupName)'")
            $this.LogError("Full GlobalConfig: $($this.GlobalConfig | ConvertTo-Json -Depth 2)")
            return $null
        }

        # Validate subscription ID format
        if (-not ($subscriptionId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
            $this.LogError("Invalid subscription ID format in config: '$subscriptionId'")
            return $null
        }

        $this.LogInfo("Successfully parsed config values for CleanupBastion - Subscription: $subscriptionId, ResourceGroup: $resourceGroupName")
        return @{
            SubscriptionId = $subscriptionId
            ResourceGroupName = $resourceGroupName
        }
    }
    
    [bool] CheckForOtherRoleAssignments([hashtable]$resourceInfo) {
        # In a real implementation, you would check for other VM admin role assignments
        # For now, return false to allow cleanup
        $this.LogInfo("Checking for other role assignments (simplified implementation)")
        return $false
    }
    
    [hashtable] RemoveBastion([hashtable]$resourceInfo) {
        try {
            $this.LogInfo("RemoveBastion called with SubscriptionId: $($resourceInfo.SubscriptionId), ResourceGroupName: $($resourceInfo.ResourceGroupName)")
            
            # Validate inputs with detailed error messages
            if (-not $resourceInfo) {
                throw "Resource info is null"
            }
            if (-not $resourceInfo.ContainsKey('SubscriptionId') -or -not $resourceInfo.SubscriptionId) {
                throw "Subscription ID is null or empty. ResourceInfo keys: $($resourceInfo.Keys -join ', ')"
            }
            if (-not $resourceInfo.ContainsKey('ResourceGroupName') -or -not $resourceInfo.ResourceGroupName) {
                throw "Resource Group Name is null or empty. ResourceInfo keys: $($resourceInfo.Keys -join ', ')"
            }
            
            # Validate subscription ID format
            if (-not ($resourceInfo.SubscriptionId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
                throw "Invalid subscription ID format: $($resourceInfo.SubscriptionId)"
            }
            
            # Check current context first
            $currentContext = Get-AzContext -ErrorAction SilentlyContinue
            if ($currentContext) {
                $this.LogInfo("Current Azure context: Subscription=$($currentContext.Subscription.Id), Account=$($currentContext.Account.Id)")
                
                # If we're already in the correct subscription, don't change context
                if ($currentContext.Subscription.Id -eq $resourceInfo.SubscriptionId) {
                    $this.LogInfo("Already in correct subscription context, skipping Set-AzContext")
                } else {
                    $this.LogInfo("Need to switch from subscription $($currentContext.Subscription.Id) to $($resourceInfo.SubscriptionId)")
                    # Set context to correct subscription with proper error handling
                    try {
                        $context = Set-AzContext -SubscriptionId $resourceInfo.SubscriptionId -ErrorAction Stop
                        $this.LogInfo("Successfully set Azure context to subscription: $($context.Subscription.Name) ($($context.Subscription.Id))")
                    } catch {
                        # If setting by subscription ID fails, try to list available subscriptions for debugging
                        try {
                            $this.LogInfo("Failed to set context to subscription $($resourceInfo.SubscriptionId). Listing available subscriptions:")
                            $availableSubscriptions = Get-AzSubscription -ErrorAction SilentlyContinue
                            if ($availableSubscriptions) {
                                foreach ($sub in $availableSubscriptions) {
                                    $this.LogInfo("Available subscription: $($sub.Name) ($($sub.Id))")
                                }
                            } else {
                                $this.LogWarning("No subscriptions found or unable to list subscriptions")
                            }
                        } catch {
                            $this.LogWarning("Unable to list subscriptions: $($_.Exception.Message)")
                        }
                        throw "Failed to set Azure context for subscription $($resourceInfo.SubscriptionId): $($_.Exception.Message)"
                    }
                }
            } else {
                $this.LogWarning("No current Azure context found - attempting to authenticate with MSI")
                try {
                    # Try to re-authenticate using MSI if no context exists
                    if ($env:MSI_SECRET) {
                        Disable-AzContextAutosave -Scope Process | Out-Null
                        $connectResult = Connect-AzAccount -Identity -ErrorAction Stop
                        $this.LogInfo("Successfully re-authenticated with MSI: $($connectResult.Context.Account.Id)")
                        
                        # Now set the subscription context
                        $context = Set-AzContext -SubscriptionId $resourceInfo.SubscriptionId -ErrorAction Stop
                        $this.LogInfo("Successfully set Azure context to subscription: $($context.Subscription.Name) ($($context.Subscription.Id))")
                    } else {
                        throw "No MSI_SECRET environment variable found and no current context"
                    }
                } catch {
                    throw "Failed to authenticate: $($_.Exception.Message)"
                }
            }
        }
        catch {
            $errorMsg = "Failed to set Azure context for subscription $($resourceInfo.SubscriptionId): $($_.Exception.Message)"
            $this.LogError($errorMsg)
            return @{ Removed = $false; BastionName = $null; Error = $errorMsg }
        }
        
        try {
            # Find Bastion hosts
            $this.LogInfo("Looking for Bastion hosts in resource group: $($resourceInfo.ResourceGroupName)")
            $bastions = Get-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName -ErrorAction SilentlyContinue
            
            if (-not $bastions) {
                $this.LogInfo("No Bastion hosts found to remove")
                return @{ Removed = $false; BastionName = $null; PublicIpRemoved = $false; PublicIpName = $null }
            }
            
            $this.LogInfo("Found $($bastions.Count) Bastion host(s)")
            
            # Look for auto-created bastions first, otherwise take the first one
            $bastionToRemove = $bastions | Where-Object { $_.Name -like "*auto*" } | Select-Object -First 1
            if (-not $bastionToRemove) {
                $bastionToRemove = $bastions | Select-Object -First 1
                $this.LogInfo("No auto-created Bastion found, will remove first available: $($bastionToRemove.Name)")
            } else {
                $this.LogInfo("Found auto-created Bastion to remove: $($bastionToRemove.Name)")
            }
            
            $publicIpRemoved = $false
            $publicIpName = $null
            
            # Get the public IP resource ID from the Bastion's IP configuration
            if ($bastionToRemove.IpConfigurations -and $bastionToRemove.IpConfigurations.Count -gt 0) {
                $publicIpId = $bastionToRemove.IpConfigurations[0].PublicIpAddress.Id
                if ($publicIpId) {
                    $publicIpName = ($publicIpId -split "/")[-1]
                    $this.LogInfo("Associated Public IP found: $publicIpName")
                }
            }
            
            # Remove Bastion
            $this.LogInfo("Removing Bastion: $($bastionToRemove.Name)")
            Remove-AzBastion -ResourceGroupName $resourceInfo.ResourceGroupName -Name $bastionToRemove.Name -Force -ErrorAction Stop
            $this.LogInfo("Successfully removed Bastion: $($bastionToRemove.Name)")
            
            # Remove the associated Public IP if found
            if ($publicIpName) {
                try {
                    $this.LogInfo("Removing associated Public IP: $publicIpName")
                    Remove-AzPublicIpAddress -ResourceGroupName $resourceInfo.ResourceGroupName -Name $publicIpName -Force -ErrorAction Stop
                    $publicIpRemoved = $true
                    $this.LogInfo("Successfully removed Public IP: $publicIpName")
                }
                catch {
                    $this.LogWarning("Failed to remove Public IP $publicIpName`: $($_.Exception.Message)")
                }
            }
            
            return @{ 
                Removed = $true; 
                BastionName = $bastionToRemove.Name; 
                PublicIpRemoved = $publicIpRemoved; 
                PublicIpName = $publicIpName 
            }
        }
        catch {
            $errorMsg = "Failed to remove Bastion: $($_.Exception.Message)"
            $this.LogError($errorMsg)
            return @{ Removed = $false; BastionName = $null; Error = $errorMsg }
        }
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