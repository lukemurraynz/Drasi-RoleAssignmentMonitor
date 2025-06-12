# Azure Function for Drasi-based Role Assignment Automation

This Azure Function provides a modular, extensible engine for automating Azure resource management based on role assignment events from Drasi. Inspired by [Bellhop](https://github.com/Azure/bellhop), it uses an event-driven architecture to respond to role assignments with appropriate resource provisioning.

## Overview

The solution follows an event-driven architecture with modular handlers for different roles and resources:

```
Azure Activity Logs → Event Hub → Drasi Source → Continuous Query → Reaction → Event Grid → Azure Function → Resource Management
```

## Architecture

### Core Engine Components

1. **ProcessRoleAssignment Function**: Event Grid-triggered entry point
2. **RoleAssignmentEngine Module**: Main orchestrator that routes role events to appropriate handlers
3. **Handler Modules**: Specialized modules for different resource types and roles
4. **ConfigurationManager Module**: Extensible role-to-action mapping
5. **Logger Module**: Structured logging for monitoring and troubleshooting

### Handler Modules (Extensible)

- **BastionHandler**: Manages Azure Bastion creation/removal for VM Administrator Login roles
- **LoggingHandler**: Provides audit logging and telemetry for all role assignments
- **StorageHandler**: Example handler for Storage Account Blob Contributor roles (placeholder)
- **[Future Handlers]**: Easy to add new handlers for additional roles and resources

### Design Principles

Following the Azure Well-Architected Framework and Bellhop-inspired patterns:

- **Security**: Uses managed identity, least privilege access, secure configuration
- **Reliability**: Comprehensive error handling, retry logic, validation
- **Performance**: Efficient processing, appropriate scaling with consumption plan
- **Cost**: Right-sized resources, cleanup automation to prevent waste
- **Operational Excellence**: Detailed logging, monitoring, automated deployment
- **Extensibility**: Modular design allows easy addition of new roles and resources

## Features

### Core Functionality

- **Event-Driven Automation**: Responds to any configured role assignment event
- **Modular Role Processing**: Extensible engine routes different roles to appropriate handlers
- **Smart Resource Management**: Creates resources only when needed, with intelligent cleanup
- **Resource Validation**: Validates prerequisites before attempting operations
- **Flexible Deployment**: Supports resource group, subscription, and resource-level assignments

### Bastion Management (Example Implementation)

- **Automatic Creation**: Creates Azure Bastion when VM Administrator Login role is assigned
- **Intelligent Cleanup**: Removes Bastion only when no other assignments require it
- **VNet Integration**: Automatically integrates with existing VNets or creates new ones
- **Location Flexibility**: Deploys Bastion without requiring specific VM references

### Security & Monitoring

- **Managed Identity**: Secure authentication without stored credentials
- **Application Insights**: Comprehensive logging and monitoring
- **Event Validation**: Validates incoming events for security
- **Audit Trail**: Detailed logs for compliance and troubleshooting

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VM_ADMIN_ROLE_ID` | Virtual Machine Administrator Login role ID | `1c0163c0-47e6-4577-8991-ea5c82e286e4` |
| `BASTION_SKU` | Azure Bastion SKU (Basic/Standard) | `Basic` |
| `BASTION_SUBNET_NAME` | Name for Bastion subnet | `AzureBastionSubnet` |
| `LOG_LEVEL` | Logging level (Information/Debug) | `Information` |
| `MAX_RETRIES` | Maximum retry attempts for operations | `3` |
| `DRY_RUN_MODE` | Enable dry run mode for testing | `false` |

### Azure Permissions Required

The managed identity needs the following permissions:

- **Contributor** on resource groups where Bastions will be created
- **Reader** at subscription level to check role assignments across VMs
- **Event Grid Data Receiver** for receiving events (if using service principal)

## Deployment

### Prerequisites

- Azure CLI installed and authenticated
- PowerShell 7.2 or later
- Azure Functions Core Tools (optional, for local testing)

### Quick Deployment

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd drasi/Deployment
   ```

2. **Run the deployment script**:
   ```bash
   ./deploy.sh
   ```

3. **Follow the prompts** to configure:
   - Resource Group name
   - Subscription ID
   - Function App name

### Manual Deployment

1. **Deploy infrastructure**:
   ```bash
   az deployment group create \
     --resource-group <your-rg> \
     --template-file function-app.bicep \
     --parameters @function-app.parameters.json
   ```

2. **Deploy function code**:
   ```bash
   cd ../AzureFunction
   zip -r ../function-app.zip .
   az functionapp deployment source config-zip \
     --resource-group <your-rg> \
     --name <function-app-name> \
     --src ../function-app.zip
   ```

3. **Configure Event Grid subscription**:
   ```bash
   # Get function key and create webhook URL
   FUNCTION_KEY=$(az functionapp keys list --resource-group <your-rg> --name <function-app-name> --query "functionKeys.default" -o tsv)
   WEBHOOK_URL="https://<function-app-name>.azurewebsites.net/runtime/webhooks/eventgrid?functionName=ProcessRoleAssignment&code=$FUNCTION_KEY"
   
   # Update your Drasi reaction or Event Grid subscription to use this webhook
   ```

## Usage

### Triggering Bastion Creation

When a user is assigned the VM Administrator Login role on a virtual machine:

1. Azure Activity Log captures the role assignment
2. Drasi processes the event and sends it to Event Grid
3. Azure Function receives the event and:
   - Validates the role assignment
   - Checks if the VM exists and gets its VNet
   - Creates Bastion subnet if needed
   - Creates Azure Bastion host
   - Logs the operation

### Triggering Bastion Cleanup

When the VM Administrator Login role is removed:

1. Function receives the role removal event
2. Checks if other VMs in the same VNet have the admin role
3. If no other VMs have admin access, removes the Bastion
4. Cleans up associated resources (public IP)

### Example Event Flow

```json
{
  "id": "event-id",
  "eventType": "Microsoft.EventGrid.SubscriptionValidationEvent",
  "subject": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Authorization/roleAssignments/{id}",
  "data": {
    "correlationId": "correlation-id",
    "operationName": "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE",
    "resourceId": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm-name}",
    "resultType": "Start",
    "properties": {
      "entity": {
        "roleDefinitionId": "/subscriptions/{sub}/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4"
      }
    }
  }
}
```

## Monitoring

### Application Insights

The function automatically logs to Application Insights with structured data:

- **Operation success/failure**
- **Processing time**
- **Resource creation/deletion events**
- **Error details and stack traces**

### Key Metrics

Monitor these KQL queries in Application Insights:

```kusto
// Successful Bastion operations
traces
| where customDimensions.Category == "BastionOperation"
| where customDimensions.Result == "Success"
| summarize count() by bin(timestamp, 1h)

// Failed operations
traces
| where severityLevel >= 3
| where customDimensions.FunctionName == "ProcessRoleAssignment"
| project timestamp, message, customDimensions
```

### Alerts

Consider setting up alerts for:

- Function execution failures
- Bastion creation failures
- High execution duration
- Authentication failures

## Testing

### Local Testing

1. **Set up local environment**:
   ```powershell
   # In AzureFunction directory
   copy local.settings.json.template local.settings.json
   # Edit local.settings.json with your values
   ```

2. **Run locally**:
   ```bash
   func start
   ```

3. **Test with sample event**:
   ```bash
   curl -X POST http://localhost:7071/runtime/webhooks/eventgrid?functionName=ProcessRoleAssignment \
     -H "Content-Type: application/json" \
     -d @sample-event.json
   ```

### Integration Testing

Use the `DRY_RUN_MODE` environment variable to test without creating actual resources:

```bash
az functionapp config appsettings set \
  --resource-group <your-rg> \
  --name <function-app-name> \
  --settings DRY_RUN_MODE=true
```

## Extensibility

The modular engine architecture makes it easy to add support for new roles and resources.

### Adding New Roles

1. **Update Configuration** in `ConfigurationManager.ps1`:
   ```powershell
   StorageBlobContributor = @{
       RoleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
       Actions = @{
           OnAssigned = @("CreateStorageAccount", "LogAssignment")
           OnRemoved = @("EvaluateStorageRemoval", "LogRemoval")
       }
       ResourceTypes = @("Microsoft.Storage/storageAccounts", "Microsoft.Resources/subscriptions", "Microsoft.Resources/resourceGroups")
   }
   ```

2. **Create Handler Module** (e.g., `StorageHandler.ps1`):
   ```powershell
   function Invoke-StorageHandler {
       param([hashtable]$Parameters)
       
       switch ($Parameters.Action) {
           "CreateStorageAccount" { 
               return Invoke-StorageAccountCreation -RoleInfo $Parameters.RoleInfo -Configuration $Parameters.Configuration
           }
           "EvaluateStorageRemoval" { 
               return Invoke-StorageAccountRemovalEvaluation -RoleInfo $Parameters.RoleInfo -Configuration $Parameters.Configuration
           }
       }
   }
   ```

3. **Update Action Mapping** in `RoleAssignmentEngine.ps1`:
   ```powershell
   $actionMap = @{
       "CreateStorageAccount" = "StorageHandler"
       "EvaluateStorageRemoval" = "StorageHandler"
       # ... other mappings
   }
   ```

4. **Register Handler** in `Get-AvailableHandlers`:
   ```powershell
   $handlerFiles = @(
       "$PSScriptRoot\BastionHandler.ps1"
       "$PSScriptRoot\LoggingHandler.ps1"
       "$PSScriptRoot\StorageHandler.ps1"
       "$PSScriptRoot\YourNewHandler.ps1"  # Add here
   )
   ```

### Example: Network Security Group Handler

For managing NSG rules based on Network Contributor role assignments:

```powershell
# NetworkHandler.ps1
function Invoke-NetworkHandler {
    param([hashtable]$Parameters)
    
    switch ($Parameters.Action) {
        "ConfigureNetworkRules" {
            # Add NSG rules for network access
            return New-NetworkSecurityRules -RoleInfo $Parameters.RoleInfo
        }
        "RemoveNetworkRules" {
            # Remove NSG rules when role is removed
            return Remove-NetworkSecurityRules -RoleInfo $Parameters.RoleInfo
        }
    }
}
```

### Supported Role Examples

The engine currently supports:

1. **VM Administrator Login** (`1c0163c0-47e6-4577-8991-ea5c82e286e4`)
   - Creates Azure Bastion for VM access
   - Intelligent cleanup when no longer needed

2. **Storage Blob Contributor** (`ba92f5b4-2d11-453d-a403-e96b0029c9fe`) - *Placeholder*
   - Could create/configure storage accounts
   - Manage access policies and security settings

3. **Network Contributor** (`4d97b98b-1d4f-4787-a291-c67834d212e7`) - *Placeholder*
   - Could configure network security rules
   - Manage VNet configurations

### Configuration Examples

Environment variables for role configuration:

```bash
# VM Administrator Login role (default)
VM_ADMIN_ROLE_ID=1c0163c0-47e6-4577-8991-ea5c82e286e4

# Storage Blob Contributor role
STORAGE_BLOB_CONTRIBUTOR_ROLE_ID=ba92f5b4-2d11-453d-a403-e96b0029c9fe

# Network Contributor role
NETWORK_CONTRIBUTOR_ROLE_ID=4d97b98b-1d4f-4787-a291-c67834d212e7

# Default location for resource creation
DEFAULT_AZURE_LOCATION="Australia East"

# Bastion-specific settings
BASTION_SKU=Basic
BASTION_SUBNET_SIZE=26
BASTION_AUTO_CLEANUP=true
```
        }
    }
}
```

## Troubleshooting

### Common Issues

1. **Function not triggering**:
   - Check Event Grid subscription configuration
   - Verify webhook URL and function key
   - Check Drasi reaction is sending events

2. **Authentication failures**:
   - Verify managed identity has required permissions
   - Check subscription ID is correct
   - Ensure identity is assigned to function app

3. **Bastion creation failures**:
   - Check VNet has available address space
   - Verify location supports Bastion
   - Check resource group permissions

### Debug Steps

1. **Check function logs**:
   ```bash
   az functionapp logs tail --resource-group <rg> --name <function-name>
   ```

2. **Query Application Insights**:
   ```kusto
   traces
   | where timestamp > ago(1h)
   | where customDimensions.FunctionName == "ProcessRoleAssignment"
   | order by timestamp desc
   ```

3. **Test Event Grid connectivity**:
   Use Event Grid viewer to see if events are being received

## Security Considerations

### Data Protection

- **No sensitive data in logs**: Role assignment details are logged but sanitized
- **Secure configuration**: Use Key Vault for sensitive configuration values
- **Event validation**: Validates event source and format

### Access Control

- **Least privilege**: Function uses minimal required permissions
- **Resource isolation**: Operations scoped to specific resource groups
- **Audit trail**: All operations logged for security review

### Network Security

- **HTTPS only**: Function app requires HTTPS
- **VNet integration**: Can be deployed with VNet integration for network isolation
- **Private endpoints**: Supports private endpoints for additional security

## Cost Optimization

### Design Decisions

- **Consumption plan**: Pay only for execution time
- **Basic Bastion SKU**: Default to cost-effective option
- **Automatic cleanup**: Removes unused resources to prevent waste
- **Efficient processing**: Minimal execution time reduces costs

### Cost Monitoring

Monitor these aspects:

- Function execution count and duration
- Bastion host usage and lifecycle
- Storage costs for function app
- Application Insights ingestion

## Support and Maintenance

### Updating the Function

1. **Test changes locally** using the development container
2. **Deploy to staging** environment first
3. **Monitor metrics** after deployment
4. **Rollback plan** using deployment slots if needed

### Health Monitoring

The function includes health checks for:

- Azure connectivity
- Required permissions
- Configuration validity
- Event processing capability

### Backup and Recovery

- **Source code**: Stored in Git repository
- **Configuration**: Documented and version controlled
- **Deployment automation**: Reproducible through Bicep templates
- **Data recovery**: Function is stateless, no data to backup

## Contributing

When extending this solution:

1. **Follow PowerShell best practices**
2. **Add comprehensive logging**
3. **Include error handling**
4. **Update documentation**
5. **Add configuration options**
6. **Consider security implications**

### Code Standards

- Use approved PowerShell verbs
- Include parameter validation
- Add help documentation
- Follow consistent naming conventions
- Include unit tests where possible