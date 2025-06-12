# RoleProcessor.ps1 - Functions for processing role assignment events

. "$PSScriptRoot\Logger.ps1"

function Test-VMAdminRoleAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleAssignment,
        [Parameter(Mandatory = $true)]
        [string]$VMAdminRoleId
    )
    
    try {
        # Parse the properties to extract role definition ID
        if ($RoleAssignment.properties -and $RoleAssignment.properties.entity) {
            $entity = $RoleAssignment.properties.entity
            
            # Check if the role definition ID matches VM Administrator Login role
            if ($entity.roleDefinitionId -and $entity.roleDefinitionId -like "*$VMAdminRoleId*") {
                Write-LogInfo "VM Administrator Login role detected in assignment"
                return $true
            }
        }
        
        # Alternative check - look in the resource ID or properties for role information
        if ($RoleAssignment.resourceId -and $RoleAssignment.resourceId -like "*$VMAdminRoleId*") {
            Write-LogInfo "VM Administrator Login role detected in resource ID"
            return $true
        }
        
        Write-LogDebug "Role assignment does not match VM Administrator Login role"
        return $false
    }
    catch {
        Write-LogError "Error checking VM Admin role assignment: $($_.Exception.Message)"
        return $false
    }
}

function Get-ResourceInformation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceId
    )
    
    try {
        # Parse Azure resource ID
        # Format: /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/{resource-provider}/{resource-type}/{resource-name}
        $parts = $ResourceId -split '/'
        
        if ($parts.Length -lt 9) {
            Write-LogError "Invalid resource ID format: $ResourceId"
            return $null
        }
        
        $subscriptionId = $parts[2]
        $resourceGroup = $parts[4]
        $resourceProvider = $parts[6]
        $resourceType = $parts[7]
        $resourceName = $parts[8]
        
        return [PSCustomObject]@{
            SubscriptionId = $subscriptionId
            ResourceGroup = $resourceGroup
            Provider = $resourceProvider
            Type = "$resourceProvider/$resourceType"
            Name = $resourceName
            FullResourceId = $ResourceId
        }
    }
    catch {
        Write-LogError "Error parsing resource information: $($_.Exception.Message)"
        return $null
    }
}

function Get-RoleAssignmentContext {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleAssignment
    )
    
    try {
        $context = [PSCustomObject]@{
            CorrelationId = $RoleAssignment.correlationId
            Timestamp = $RoleAssignment.timestamp
            Operation = $RoleAssignment.operationName
            ResultType = $RoleAssignment.resultType
            CallerIpAddress = $RoleAssignment.callerIpAddress
            TenantId = $RoleAssignment.tenantId
            Identity = $RoleAssignment.identity
            ResourceId = $RoleAssignment.resourceId
        }
        
        # Extract additional details from properties if available
        if ($RoleAssignment.properties) {
            $context | Add-Member -NotePropertyName "Properties" -NotePropertyValue $RoleAssignment.properties
        }
        
        return $context
    }
    catch {
        Write-LogError "Error creating role assignment context: $($_.Exception.Message)"
        return $null
    }
}