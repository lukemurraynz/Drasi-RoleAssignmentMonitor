# Azure Function for Drasi-based Bastion Management

This Azure Function extends the Drasi role assignment monitoring system to automatically manage Azure Bastion resources based on VM Administrator Login role assignments.

## Overview

The solution follows an event-driven architecture inspired by [Bellhop](https://github.com/Azure/bellhop) but uses Drasi reactions and Event Grid instead of tags and schedules:

```
Azure Activity Logs → Event Hub → Drasi Source → Continuous Query → Reaction → Event Grid → Azure Function → Bastion Management
```

## Architecture

### Components

1. **ProcessRoleAssignment Function**: Event Grid-triggered function that processes role assignment events
2. **BastionManager Module**: Core logic for creating and managing Azure Bastion hosts
3. **RoleProcessor Module**: Handles role assignment event parsing and validation
4. **ResourceManager Module**: Extensible framework for managing different Azure resources
5. **ConfigurationManager Module**: Centralized configuration management
6. **Logger Module**: Structured logging for monitoring and troubleshooting

### Design Principles

Following the Azure Well-Architected Framework:

- **Security**: Uses managed identity, least privilege access, secure configuration
- **Reliability**: Comprehensive error handling, retry logic, validation
- **Performance**: Efficient processing, appropriate scaling with consumption plan
- **Cost**: Right-sized resources, cleanup automation to prevent waste
- **Operational Excellence**: Detailed logging, monitoring, automated deployment

## Features

### Core Functionality

- **Automatic Bastion Creation**: Creates Azure Bastion when VM Administrator Login role is assigned
- **Intelligent Cleanup**: Removes Bastion only when no other VMs in the VNet have admin roles
- **VNet Integration**: Automatically detects VM's VNet and creates appropriate subnets
- **Resource Validation**: Validates prerequisites before attempting operations

### Extensibility

The solution is designed for extensibility:

- **Role-Based Actions**: Easy to add new roles and associated actions
- **Resource Types**: Framework supports additional Azure resource types
- **Configuration-Driven**: Behavior controlled through environment variables
- **Modular Design**: Clean separation of concerns for maintainability

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

### Adding New Roles

1. **Update configuration** in `ConfigurationManager.ps1`:
   ```powershell
   "new-role-id" = @{
       Name = "New Role Name"
       SupportedResourceTypes = @("Microsoft.Compute/virtualMachines")
       Actions = @{
           Assigned = @("CreateSomeResource")
           Removed = @("CleanupSomeResource")
       }
   }
   ```

2. **Implement handlers** in `ResourceManager.ps1`:
   ```powershell
   function Invoke-SomeResourceOperation {
       # Implementation here
   }
   ```

### Adding New Resource Types

1. **Add resource type** to `ResourceManager.ps1`
2. **Implement operations** (Create, Delete, Update, Validate)
3. **Add configuration** in `ConfigurationManager.ps1`
4. **Update role mappings** to include new resource type

### Example: Adding NSG Rule Management

```powershell
# In ResourceManager.ps1
function Invoke-NetworkSecurityGroupOperation {
    param($Operation, $Parameters)
    
    switch ($Operation) {
        "Create" { 
            # Add security rules for admin access
        }
        "Delete" { 
            # Remove security rules
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