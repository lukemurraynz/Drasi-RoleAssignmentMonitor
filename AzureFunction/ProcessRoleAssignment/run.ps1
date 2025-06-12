using namespace System.Net

# Input bindings are passed in via param block.
param($eventGridEvent, $TriggerMetadata)

# Import the new modular role assignment engine
. "$PSScriptRoot\..\Modules\RoleAssignmentEngine.ps1"

try {
    Write-LogInfo "Processing Event Grid event: $($eventGridEvent.id)"
    Write-LogInfo "Event Type: $($eventGridEvent.eventType)"
    Write-LogInfo "Subject: $($eventGridEvent.subject)"
    
    # Parse the event data from Drasi reaction
    $eventData = $eventGridEvent.data
    
    if (-not $eventData) {
        Write-LogWarning "No event data found in Event Grid event"
        return
    }
    
    # Extract role assignment information from Drasi event
    $roleAssignment = ConvertFrom-Json ($eventData | ConvertTo-Json)
    
    Write-LogInfo "Processing role assignment - Operation: $($roleAssignment.operationName), Resource: $($roleAssignment.resourceId)"
    
    # Initialize the role assignment engine
    $engine = Initialize-RoleAssignmentEngine
    
    if (-not $engine.Initialized) {
        Write-LogError "Failed to initialize role assignment engine"
        throw "Engine initialization failed"
    }
    
    Write-LogInfo "Role assignment engine initialized successfully"
    
    # Process the role assignment event through the engine
    $result = Process-RoleAssignmentEvent -RoleAssignment $roleAssignment -Engine $engine
    
    if ($result.Success) {
        Write-LogInfo "Event processing completed successfully: $($result.Message)"
        
        if ($result.ActionsExecuted) {
            $successfulActions = ($result.ActionsExecuted | Where-Object { $_.Success }).Count
            $totalActions = $result.ActionsExecuted.Count
            Write-LogInfo "Actions summary: $successfulActions of $totalActions executed successfully"
            
            # Log any failed actions
            $failedActions = $result.ActionsExecuted | Where-Object { -not $_.Success }
            foreach ($failedAction in $failedActions) {
                Write-LogWarning "Action failed: $($failedAction.Message)"
            }
        }
    } else {
        Write-LogError "Event processing failed: $($result.Message)"
    }
    
    Write-LogInfo "Event processing workflow completed"
}
catch {
    Write-LogError "Error processing Event Grid event: $($_.Exception.Message)"
    Write-LogError "Stack trace: $($_.ScriptStackTrace)"
    throw
}