# RoleAssignmentEngine.ps1 - Main orchestrator for processing role assignment events
# Inspired by Bellhop architecture for extensible resource management

. "$PSScriptRoot\Logger.ps1"
. "$PSScriptRoot\ConfigurationManager.ps1"
. "$PSScriptRoot\RoleProcessor.ps1"

function Initialize-RoleAssignmentEngine {
    <#
    .SYNOPSIS
    Initializes the role assignment processing engine
    
    .DESCRIPTION
    Sets up the engine with configuration and available handlers
    #>
    
    Write-LogInfo "Initializing Role Assignment Engine"
    
    $config = Get-FunctionConfiguration
    $validation = Test-ConfigurationValidity -Configuration $config
    
    if (-not $validation.IsValid) {
        Write-LogError "Configuration validation failed: $($validation.Errors -join ', ')"
        throw "Invalid configuration"
    }
    
    # Load available handlers
    $handlers = Get-AvailableHandlers
    
    Write-LogInfo "Engine initialized with $($handlers.Count) handlers: $($handlers.Keys -join ', ')"
    
    return [PSCustomObject]@{
        Configuration = $config
        Handlers = $handlers
        Initialized = $true
    }
}

function Process-RoleAssignmentEvent {
    <#
    .SYNOPSIS
    Main entry point for processing role assignment events
    
    .DESCRIPTION
    Analyzes the role assignment event and routes to appropriate handlers
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleAssignment,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Engine
    )
    
    try {
        Write-LogInfo "Processing role assignment event - Operation: $($RoleAssignment.operationName)"
        
        # Extract role information from the event
        $roleInfo = Get-RoleInformationFromEvent -RoleAssignment $RoleAssignment
        
        if (-not $roleInfo) {
            Write-LogWarning "Could not extract role information from event"
            return @{ Success = $false; Message = "Invalid role assignment event" }
        }
        
        Write-LogInfo "Detected role: $($roleInfo.RoleId) on resource: $($roleInfo.ResourceType)"
        
        # Find matching role configuration
        $roleConfig = Get-RoleConfiguration -RoleId $roleInfo.RoleId -Configuration $Engine.Configuration
        
        if (-not $roleConfig) {
            Write-LogInfo "No configuration found for role $($roleInfo.RoleId), skipping"
            return @{ Success = $true; Message = "Role not configured for processing" }
        }
        
        Write-LogInfo "Found configuration for role: $($roleConfig.Name)"
        
        # Check if this resource type is supported for this role
        if ($roleConfig.SupportedResourceTypes -notcontains $roleInfo.ResourceType) {
            Write-LogInfo "Resource type $($roleInfo.ResourceType) not supported for role $($roleInfo.RoleId)"
            return @{ Success = $true; Message = "Resource type not supported for this role" }
        }
        
        # Determine the operation type (assigned/removed)
        $operation = Get-OperationType -RoleAssignment $RoleAssignment
        
        if (-not $operation) {
            Write-LogWarning "Could not determine operation type from event"
            return @{ Success = $false; Message = "Invalid operation type" }
        }
        
        Write-LogInfo "Operation type: $operation"
        
        # Get the actions to execute for this operation
        $actions = Get-ActionsForOperation -RoleConfig $roleConfig -Operation $operation
        
        if (-not $actions -or $actions.Count -eq 0) {
            Write-LogInfo "No actions configured for role $($roleInfo.RoleId) operation $operation"
            return @{ Success = $true; Message = "No actions required" }
        }
        
        Write-LogInfo "Executing $($actions.Count) actions: $($actions -join ', ')"
        
        # Execute each action
        $results = @()
        foreach ($action in $actions) {
            $actionResult = Invoke-RoleAction -Action $action -RoleInfo $roleInfo -RoleConfig $roleConfig -Engine $Engine
            $results += $actionResult
            
            if (-not $actionResult.Success) {
                Write-LogError "Action $action failed: $($actionResult.Message)"
                # Continue with other actions rather than failing completely
            }
        }
        
        # Summarize results
        $successfulActions = $results | Where-Object { $_.Success }
        $failedActions = $results | Where-Object { -not $_.Success }
        
        $summary = @{
            Success = $failedActions.Count -eq 0
            Message = "Executed $($successfulActions.Count) of $($results.Count) actions successfully"
            ActionsExecuted = $results
        }
        
        Write-LogInfo $summary.Message
        
        return $summary
        
    }
    catch {
        Write-LogError "Error processing role assignment event: $($_.Exception.Message)"
        Write-LogError "Stack trace: $($_.ScriptStackTrace)"
        return @{ Success = $false; Message = "Processing failed: $($_.Exception.Message)" }
    }
}

function Get-RoleInformationFromEvent {
    <#
    .SYNOPSIS
    Extracts role and resource information from the event
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleAssignment
    )
    
    try {
        $roleInfo = [PSCustomObject]@{
            RoleId = $null
            ResourceId = $RoleAssignment.resourceId
            ResourceType = $null
            SubscriptionId = $null
            ResourceGroup = $null
            ResourceName = $null
        }
        
        # Extract role ID from the event
        if ($RoleAssignment.properties -and $RoleAssignment.properties.entity -and $RoleAssignment.properties.entity.roleDefinitionId) {
            # Extract GUID from the role definition ID
            $roleDefId = $RoleAssignment.properties.entity.roleDefinitionId
            if ($roleDefId -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
                $roleInfo.RoleId = $matches[1]
            }
        }
        
        # Alternative: check resource ID for role information
        if (-not $roleInfo.RoleId -and $RoleAssignment.resourceId) {
            if ($RoleAssignment.resourceId -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
                $roleInfo.RoleId = $matches[1]
            }
        }
        
        # Parse resource information
        if ($RoleAssignment.resourceId) {
            $resourceInfo = Get-ResourceInformation -ResourceId $RoleAssignment.resourceId
            if ($resourceInfo) {
                $roleInfo.ResourceType = $resourceInfo.Type
                $roleInfo.SubscriptionId = $resourceInfo.SubscriptionId
                $roleInfo.ResourceGroup = $resourceInfo.ResourceGroup
                $roleInfo.ResourceName = $resourceInfo.Name
            }
        }
        
        # Validate we have minimum required information
        if (-not $roleInfo.RoleId) {
            Write-LogWarning "Could not extract role ID from event"
            return $null
        }
        
        return $roleInfo
    }
    catch {
        Write-LogError "Error extracting role information: $($_.Exception.Message)"
        return $null
    }
}

function Get-RoleConfiguration {
    <#
    .SYNOPSIS
    Gets the configuration for a specific role ID
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleId,
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    # Search through all configured roles to find matching role ID
    foreach ($roleKey in $Configuration.Roles.Keys) {
        $role = $Configuration.Roles[$roleKey]
        if ($role.RoleId -eq $RoleId) {
            return [PSCustomObject]@{
                Name = $roleKey
                RoleId = $role.RoleId
                SupportedResourceTypes = $role.ResourceTypes
                Actions = $role.Actions
            }
        }
    }
    
    return $null
}

function Get-OperationType {
    <#
    .SYNOPSIS
    Determines if this is a role assignment or removal
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleAssignment
    )
    
    $operationName = $RoleAssignment.operationName
    $resultType = $RoleAssignment.resultType
    
    if ($operationName -like "*WRITE*" -and $resultType -eq "Start") {
        return "Assigned"
    }
    elseif ($operationName -like "*DELETE*" -and $resultType -eq "Start") {
        return "Removed"
    }
    
    return $null
}

function Get-ActionsForOperation {
    <#
    .SYNOPSIS
    Gets the list of actions to execute for a given operation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleConfig,
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )
    
    $actionKey = "On$Operation"
    
    if ($RoleConfig.Actions -and $RoleConfig.Actions.$actionKey) {
        return $RoleConfig.Actions.$actionKey
    }
    
    return @()
}

function Invoke-RoleAction {
    <#
    .SYNOPSIS
    Executes a specific action for a role assignment
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleInfo,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleConfig,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Engine
    )
    
    try {
        Write-LogInfo "Executing action: $Action"
        
        # Find the appropriate handler for this action
        $handlerName = Get-HandlerForAction -Action $Action
        
        if (-not $handlerName) {
            Write-LogWarning "No handler found for action: $Action"
            return @{ Success = $false; Message = "No handler available for action $Action" }
        }
        
        if (-not $Engine.Handlers.ContainsKey($handlerName)) {
            Write-LogError "Handler $handlerName not loaded"
            return @{ Success = $false; Message = "Handler $handlerName not available" }
        }
        
        Write-LogInfo "Using handler: $handlerName"
        
        # Prepare parameters for the handler
        $parameters = @{
            Action = $Action
            RoleInfo = $RoleInfo
            RoleConfig = $RoleConfig
            Configuration = $Engine.Configuration
        }
        
        # Invoke the handler
        $result = & $Engine.Handlers[$handlerName] -Parameters $parameters
        
        Write-LogInfo "Action $Action completed with result: $($result.Success)"
        
        return $result
    }
    catch {
        Write-LogError "Error executing action $Action : $($_.Exception.Message)"
        return @{ Success = $false; Message = "Action execution failed: $($_.Exception.Message)" }
    }
}

function Get-HandlerForAction {
    <#
    .SYNOPSIS
    Determines which handler should process a given action
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action
    )
    
    # Map actions to their handlers
    $actionMap = @{
        "CreateBastion" = "BastionHandler"
        "EvaluateBastionRemoval" = "BastionHandler"
        "LogAssignment" = "LoggingHandler"
        "LogRemoval" = "LoggingHandler"
        "CreateStorageAccount" = "StorageHandler"
        "EvaluateStorageRemoval" = "StorageHandler"
        "ConfigureNetworkRules" = "NetworkHandler"  # Future extension
    }
    
    return $actionMap[$Action]
}

function Get-AvailableHandlers {
    <#
    .SYNOPSIS
    Discovers and loads available action handlers
    #>
    
    $handlers = @{}
    $handlerFiles = @(
        "$PSScriptRoot\BastionHandler.ps1"
        "$PSScriptRoot\LoggingHandler.ps1"
        "$PSScriptRoot\StorageHandler.ps1"
        # Future handlers can be added here
    )
    
    foreach ($handlerFile in $handlerFiles) {
        if (Test-Path $handlerFile) {
            try {
                . $handlerFile
                $handlerName = [System.IO.Path]::GetFileNameWithoutExtension($handlerFile)
                $handlers[$handlerName] = Get-Command "Invoke-$handlerName" -ErrorAction SilentlyContinue
                Write-LogDebug "Loaded handler: $handlerName"
            }
            catch {
                Write-LogWarning "Failed to load handler $handlerFile : $($_.Exception.Message)"
            }
        }
    }
    
    return $handlers
}