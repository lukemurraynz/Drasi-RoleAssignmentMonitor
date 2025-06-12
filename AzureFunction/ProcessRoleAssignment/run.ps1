using namespace System.Net

# Input bindings are passed in via param block.
param($eventGridEvent, $TriggerMetadata)

# Import required modules and helper functions
. "$PSScriptRoot\..\Modules\BastionManager.ps1"
. "$PSScriptRoot\..\Modules\RoleProcessor.ps1"
. "$PSScriptRoot\..\Modules\Logger.ps1"

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
    
    # Check if this is a VM Administrator Login role assignment
    $vmAdminRoleId = $env:VM_ADMIN_ROLE_ID
    $isVMAdminRole = Test-VMAdminRoleAssignment -RoleAssignment $roleAssignment -VMAdminRoleId $vmAdminRoleId
    
    if (-not $isVMAdminRole) {
        Write-LogInfo "Event is not for VM Administrator Login role, skipping"
        return
    }
    
    # Extract resource information
    $resourceInfo = Get-ResourceInformation -ResourceId $roleAssignment.resourceId
    
    if (-not $resourceInfo) {
        Write-LogError "Unable to parse resource information from: $($roleAssignment.resourceId)"
        return
    }
    
    Write-LogInfo "Resource Type: $($resourceInfo.Type), Resource Group: $($resourceInfo.ResourceGroup), Subscription: $($resourceInfo.SubscriptionId)"
    
    # Only process VM-related resources
    if ($resourceInfo.Type -ne "Microsoft.Compute/virtualMachines") {
        Write-LogInfo "Resource is not a virtual machine, skipping Bastion management"
        return
    }
    
    # Determine the operation type
    $isRoleAssigned = $roleAssignment.operationName -like "*WRITE*" -and $roleAssignment.resultType -eq "Start"
    $isRoleRemoved = $roleAssignment.operationName -like "*DELETE*" -and $roleAssignment.resultType -eq "Start"
    
    if ($isRoleAssigned) {
        Write-LogInfo "VM Administrator Login role assigned - Creating/Ensuring Bastion exists"
        $result = Invoke-BastionCreation -SubscriptionId $resourceInfo.SubscriptionId -ResourceGroupName $resourceInfo.ResourceGroup -VirtualMachineName $resourceInfo.Name
        
        if ($result.Success) {
            Write-LogInfo "Bastion operation completed successfully: $($result.Message)"
        } else {
            Write-LogError "Bastion creation failed: $($result.Message)"
        }
    }
    elseif ($isRoleRemoved) {
        Write-LogInfo "VM Administrator Login role removed - Checking if Bastion should be removed"
        $result = Invoke-BastionCleanup -SubscriptionId $resourceInfo.SubscriptionId -ResourceGroupName $resourceInfo.ResourceGroup -VirtualMachineName $resourceInfo.Name
        
        if ($result.Success) {
            Write-LogInfo "Bastion cleanup completed successfully: $($result.Message)"
        } else {
            Write-LogError "Bastion cleanup failed: $($result.Message)"
        }
    }
    else {
        Write-LogInfo "Operation is not a role assignment or removal, skipping"
    }
    
    Write-LogInfo "Event processing completed successfully"
}
catch {
    Write-LogError "Error processing Event Grid event: $($_.Exception.Message)"
    Write-LogError "Stack trace: $($_.ScriptStackTrace)"
    throw
}