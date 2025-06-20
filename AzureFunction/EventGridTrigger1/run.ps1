param($eventGridEvent, $TriggerMetadata)

# Modular Azure Function for RBAC-driven automation
# Inspired by Bellhop: https://azure.github.io/bellhop/#/README

# Handle Drasi.ControlSignal events
if ($eventGridEvent.type -eq 'Drasi.ControlSignal') {
    $payload = $eventGridEvent.data.payload
    $kind = $payload.kind
    $source = $payload.source
    if ($null -ne $source -and ($source -is [hashtable] -or $source -is [psobject])) {
        $sourceStr = $source | ConvertTo-Json -Compress
    } else {
        $sourceStr = $source
    }
    Write-Host "[DRASI CONTROL SIGNAL] kind: $kind, source: $sourceStr"
    return
}

Write-Host "=== Starting Drasi RBAC Action Handler ==="
$modulesPath = Join-Path $PSScriptRoot '..' 'Modules'

Import-Module (Join-Path $modulesPath 'Az.Accounts' '5.1.0' 'Az.Accounts.psd1') -Force
Import-Module (Join-Path $modulesPath 'Az.Resources' '8.0.0' 'Az.Resources.psd1') -Force
Import-Module (Join-Path $modulesPath 'Az.Network' '7.17.0' 'Az.Network.psd1') -Force
Import-Module (Join-Path $modulesPath 'Az.Compute' '10.0.1' 'Az.Compute.psd1') -Force

try {
    # Load required modules - look in parent directory
    $functionDir = Split-Path $PSScriptRoot -Parent
    $eventProcessorPath = Join-Path $functionDir "EventProcessor.ps1"
    $actionHandlersPath = Join-Path $functionDir "ActionHandlers.ps1"
    $configPath = Join-Path $functionDir "config.json"
    
    if (-not (Test-Path $eventProcessorPath)) {
        throw "EventProcessor.ps1 not found at: $eventProcessorPath"
    }
    
    if (-not (Test-Path $actionHandlersPath)) {
        throw "ActionHandlers.ps1 not found at: $actionHandlersPath"
    }
    
    if (-not (Test-Path $configPath)) {
        throw "config.json not found at: $configPath"
    }
    
    # Load modules
    . $eventProcessorPath
    . $actionHandlersPath
    
    Write-Host "[INFO] Modules loaded successfully"
    
    # Check authentication context
    $currentContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($currentContext) {
        Write-Host "[INFO] Azure authentication context found:"
        Write-Host "  - Account: $($currentContext.Account.Id)"
        Write-Host "  - Subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))"
        Write-Host "  - Tenant: $($currentContext.Tenant.Id)"
    } else {
        Write-Warning "[WARNING] No Azure authentication context found"
        # Try to re-authenticate using MSI
        if ($env:MSI_SECRET) {
            Write-Host "[INFO] Attempting to authenticate with MSI..."
            try {
                Disable-AzContextAutosave -Scope Process | Out-Null
                $connectResult = Connect-AzAccount -Identity -ErrorAction Stop
                Write-Host "[INFO] Successfully authenticated with MSI: $($connectResult.Context.Account.Id)"
            } catch {
                Write-Error "[ERROR] Failed to authenticate with MSI: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "[WARNING] No MSI_SECRET environment variable found"
        }
    }
    
    # Initialize configuration manager
    $configManager = [ConfigurationManager]::new($configPath)
    $globalConfig = $configManager.GetGlobalConfiguration()
    
    # Log event details if logging is enabled
    if ($globalConfig.enableLogging) {
        Write-Host "=== Event Grid Event Data ==="
        $eventGridEvent | ConvertTo-Json -Depth 10 | Write-Host
        
        if ($eventGridEvent.data) {
            Write-Host "=== Event Data ==="
            $eventGridEvent.data | ConvertTo-Json -Depth 5 | Write-Host
        }
    }
    
    # Parse the Drasi event
    Write-Host "[INFO] Parsing Drasi event..."
    $parsedEvent = Parse-DrasiEvent $eventGridEvent
    
    if (-not $parsedEvent.isValid) {
        Write-Warning "Event validation failed. This may not be a role assignment event."
        Write-Host "=== Parsed Event Details ==="
        $parsedEvent | ConvertTo-Json -Depth 10 | Write-Host
        return
    }
    
    # Log parsed event details
    $roleName = $configManager.GetRoleName($parsedEvent.roleDefinitionId)
    Write-Host "[INFO] Valid RBAC event detected:"
    Write-Host "  - Role: $roleName"
    Write-Host "  - Operation: $($parsedEvent.operationType)"
    Write-Host "  - Scope: $($parsedEvent.scope)"
    Write-Host "  - Principal ID: $($parsedEvent.principalId)"
    Write-Host "  - Correlation ID: $($parsedEvent.correlationId)"
    
    # Initialize action orchestrator and process event
    $orchestrator = [ActionOrchestrator]::new($configManager)
    $results = $orchestrator.ProcessEvent($parsedEvent)
    
    # Log results
    Write-Host "=== Action Results ==="
    foreach ($result in $results) {
        $status = if ($result.success) { "SUCCESS" } else { "FAILED" }
        Write-Host "[$status] $($result.action): $($result.message)"
        
        if ($result.details -and $globalConfig.enableLogging) {
            Write-Host "  Details: $($result.details | ConvertTo-Json -Depth 2)"
        }
    }
    
    # Summary
    $successCount = ($results | Where-Object { $_.success }).Count
    $totalCount = $results.Count
    Write-Host "[INFO] Action execution completed: $successCount/$totalCount successful"
    
}
catch {
    Write-Error "[ERROR] Function execution failed: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
    
    # Still log the original event for debugging
    Write-Host "=== Original Event (for debugging) ==="
    $eventGridEvent | ConvertTo-Json -Depth 10 | Write-Host
}

Write-Host "=== Drasi RBAC Action Handler Complete ==="