# Utility functions for Drasi event processing and configuration management

class EventParser {
    static [hashtable] ParseDrasiEvent([object]$eventGridEvent) {
        try {
            $result = @{
                isValid = $false
                operationType = $null
                roleDefinitionId = $null
                scope = $null
                principalId = $null
                correlationId = $null
                timestamp = $null
                callerIpAddress = $null
                rawEvent = $eventGridEvent
            }
            
            # Check if this is a Drasi change event
            if ($eventGridEvent.type -ne "Drasi.ChangeEvent") {
                Write-Warning "Event type is not Drasi.ChangeEvent: $($eventGridEvent.type)"
                return $result
            }
            
            # Extract operation type (i = insert/create, d = delete, u = update)
            $operationType = $eventGridEvent.data.payload.op
            if (-not $operationType) {
                Write-Warning "No operation type found in event payload"
                return $result
            }
            
            $result.operationType = switch ($operationType) {
                "i" { "create" }
                "d" { "delete" }
                "u" { "update" }
                default { $operationType }
            }
            
            # Extract role assignment data
            $payloadData = $null
            if ($operationType -eq "i" -and $eventGridEvent.data.payload.after) {
                $payloadData = $eventGridEvent.data.payload.after
            }
            elseif ($operationType -eq "d" -and $eventGridEvent.data.payload.before) {
                $payloadData = $eventGridEvent.data.payload.before
            }
            
            if (-not $payloadData) {
                Write-Warning "No payload data found for operation type: $operationType"
                return $result
            }
            
            # Extract role definition ID from properties.requestbody
            if ($payloadData.properties -and $payloadData.properties.requestbody) {
                try {
                    $requestBody = $payloadData.properties.requestbody | ConvertFrom-Json
                    $result.roleDefinitionId = $requestBody.Properties.RoleDefinitionId
                    $result.principalId = $requestBody.Properties.PrincipalId
                    $result.scope = $requestBody.Properties.Scope
                }
                catch {
                    Write-Warning "Failed to parse requestbody JSON: $($_.Exception.Message)"
                }
            }
            
            # Extract additional metadata
            $result.correlationId = $payloadData.correlationId
            $result.timestamp = $payloadData.timestamp
            $result.callerIpAddress = $payloadData.callerIpAddress
            
            # Validate required fields
            if ($result.roleDefinitionId -and $result.scope) {
                $result.isValid = $true
            }
            
            return $result
        }
        catch {
            Write-Error "Failed to parse Drasi event: $($_.Exception.Message)"
            return @{ isValid = $false; error = $_.Exception.Message }
        }
    }
}

class ConfigurationManager {
    [hashtable]$Config
    [string]$ConfigPath
    
    ConfigurationManager([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.LoadConfiguration()
    }
    
    [void] LoadConfiguration() {
        try {
            if (Test-Path $this.ConfigPath) {
                $configContent = Get-Content $this.ConfigPath -Raw
                $configObj = $configContent | ConvertFrom-Json
                
                # Initialize config structure
                $this.Config = @{
                    roleActions = @{}
                    actionConfiguration = @{}
                    global = @{}
                }
                
                # Convert roleActions
                if ($configObj.roleActions) {
                    $configObj.roleActions.PSObject.Properties | ForEach-Object {
                        $roleId = $_.Name
                        $roleData = $_.Value
                        
                        $this.Config.roleActions[$roleId] = @{
                            name = $roleData.name
                            description = $roleData.description
                            actions = @{}
                        }
                        
                        if ($roleData.actions) {
                            $roleData.actions.PSObject.Properties | ForEach-Object {
                                $opType = $_.Name
                                $actionList = $_.Value
                                $this.Config.roleActions[$roleId].actions[$opType] = @($actionList)
                            }
                        }
                    }
                }
                
                # Convert actionConfiguration
                if ($configObj.actionConfiguration) {
                    $configObj.actionConfiguration.PSObject.Properties | ForEach-Object {
                        $actionName = $_.Name
                        $actionData = $_.Value
                        
                        $this.Config.actionConfiguration[$actionName] = @{
                            enabled = $actionData.enabled
                            parameters = @{}
                        }
                        
                        if ($actionData.parameters) {
                            $actionData.parameters.PSObject.Properties | ForEach-Object {
                                $this.Config.actionConfiguration[$actionName].parameters[$_.Name] = $_.Value
                            }
                        }
                    }
                }
                
                # Convert global settings
                if ($configObj.global) {
                    $configObj.global.PSObject.Properties | ForEach-Object {
                        if ($_.Name -eq "tags" -and $_.Value) {
                            $this.Config.global[$_.Name] = @{}
                            $_.Value.PSObject.Properties | ForEach-Object {
                                $this.Config.global.tags[$_.Name] = $_.Value
                            }
                        }
                        else {
                            $this.Config.global[$_.Name] = $_.Value
                        }
                    }
                }
                
                Write-Host "Configuration loaded successfully from: $($this.ConfigPath)"
            }
            else {
                throw "Configuration file not found: $($this.ConfigPath)"
            }
        }
        catch {
            Write-Error "Failed to load configuration: $($_.Exception.Message)"
            # Provide minimal default configuration
            $this.Config = @{
                roleActions = @{}
                actionConfiguration = @{}
                global = @{
                    enableLogging = $true
                    dryRun = $false
                    defaultResourceGroupPattern = "rg-{subscriptionId}"
                    tags = @{}
                }
            }
        }
    }
    
    [array] GetActionsForRole([string]$roleDefinitionId, [string]$operationType) {
        if (-not $this.Config.roleActions.ContainsKey($roleDefinitionId)) {
            Write-Warning "No actions configured for role: $roleDefinitionId"
            return @()
        }
        
        $roleConfig = $this.Config.roleActions[$roleDefinitionId]
        
        if (-not $roleConfig.actions.ContainsKey($operationType)) {
            Write-Warning "No actions configured for operation '$operationType' on role: $roleDefinitionId"
            return @()
        }
        
        return $roleConfig.actions[$operationType]
    }
    
    [hashtable] GetActionConfiguration([string]$actionName) {
        if ($this.Config.actionConfiguration.ContainsKey($actionName)) {
            return $this.Config.actionConfiguration[$actionName]
        }
        
        Write-Warning "No configuration found for action: $actionName"
        return @{ enabled = $false }
    }
    
    [hashtable] GetGlobalConfiguration() {
        return $this.Config.global
    }
    
    [string] GetRoleName([string]$roleDefinitionId) {
        if ($this.Config.roleActions.ContainsKey($roleDefinitionId)) {
            return $this.Config.roleActions[$roleDefinitionId].name
        }
        return "Unknown Role"
    }
}

class ActionOrchestrator {
    [ConfigurationManager]$ConfigManager
    [hashtable]$GlobalConfig
    
    ActionOrchestrator([ConfigurationManager]$configManager) {
        $this.ConfigManager = $configManager
        $this.GlobalConfig = $configManager.GetGlobalConfiguration()
    }
    
    [array] ProcessEvent([hashtable]$parsedEvent) {
        $results = @()
        
        if (-not $parsedEvent.isValid) {
            $results += @{
                success = $false
                message = "Invalid event data"
                action = "validation"
                details = $parsedEvent
            }
            return $results
        }
        
        # Get actions for this role and operation
        $actions = $this.ConfigManager.GetActionsForRole($parsedEvent.roleDefinitionId, $parsedEvent.operationType)
        
        if ($actions.Count -eq 0) {
            $roleName = $this.ConfigManager.GetRoleName($parsedEvent.roleDefinitionId)
            $results += @{
                success = $true
                message = "No actions configured for role '$roleName' operation '$($parsedEvent.operationType)'"
                action = "skip"
                details = @{
                    roleDefinitionId = $parsedEvent.roleDefinitionId
                    operationType = $parsedEvent.operationType
                }
            }
            return $results
        }
        
        # Execute each action
        foreach ($actionName in $actions) {
            try {
                $actionConfig = $this.ConfigManager.GetActionConfiguration($actionName)
                
                if (-not $actionConfig.enabled) {
                    $results += @{
                        success = $true
                        message = "Action '$actionName' is disabled"
                        action = $actionName
                        details = @{ disabled = $true }
                    }
                    continue
                }
                
                # Create action context
                $context = @{
                    scope = $parsedEvent.scope
                    roleDefinitionId = $parsedEvent.roleDefinitionId
                    principalId = $parsedEvent.principalId
                    operationType = $parsedEvent.operationType
                    correlationId = $parsedEvent.correlationId
                    timestamp = $parsedEvent.timestamp
                }
                
                # Execute action using factory function
                $action = New-Action -ActionName $actionName -Config $actionConfig -GlobalConfig $this.GlobalConfig
                $actionResult = $action.Execute($context)
                
                $results += @{
                    success = $actionResult.Success
                    message = $actionResult.Message
                    action = $actionName
                    details = $actionResult.Details
                }
            }
            catch {
                $results += @{
                    success = $false
                    message = "Failed to execute action '$actionName': $($_.Exception.Message)"
                    action = $actionName
                    details = @{
                        error = $_.Exception.Message
                        stackTrace = $_.ScriptStackTrace
                    }
                }
            }
        }
        
        return $results
    }
}