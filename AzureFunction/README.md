# Modular Azure Function for RBAC-Driven Automation

This Azure Function provides modular, configuration-driven automation for Azure RBAC role assignment events. Inspired by the [Bellhop](https://azure.github.io/bellhop/#/README) pattern, it allows you to trigger different actions based on role assignments and deletions.

## Features

- **Event-Driven**: Triggered by Drasi Event Grid notifications for RBAC changes
- **Modular Design**: Easily extensible action system
- **Configuration-Driven**: Simple JSON configuration for role-to-action mapping
- **Azure Bastion Automation**: Built-in support for automatic Bastion creation/cleanup
- **Beginner-Friendly**: Designed for first-time Azure and PowerShell users
- **Comprehensive Logging**: Detailed logging for debugging and monitoring

## Quick Start

### 1. Configuration

The function is configured through `config.json`. The default configuration handles VM Administrator Login roles:

```json
{
  "roleActions": {
    "/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4": {
      "name": "Virtual Machine Administrator Login",
      "actions": {
        "create": ["CreateBastion"],
        "delete": ["CleanupBastion"]
      }
    }
  }
}
```

### 2. Supported Actions

#### CreateBastion
Automatically creates an Azure Bastion when VM admin roles are assigned.

**Configuration:**
```json
"CreateBastion": {
  "enabled": true,
  "parameters": {
    "bastionNamePrefix": "bastion-auto",
    "subnetAddressPrefix": "10.0.1.0/26",
    "publicIpNamePrefix": "pip-bastion-auto"
  }
}
```

#### CleanupBastion
Removes Bastion when VM admin roles are deleted (with safety checks).

**Configuration:**
```json
"CleanupBastion": {
  "enabled": true,
  "parameters": {
    "preserveIfOtherAssignments": true,
    "gracePeriodMinutes": 5
  }
}
```

### 3. Global Settings

```json
"global": {
  "enableLogging": true,
  "dryRun": false,
  "defaultResourceGroupPattern": "rg-{subscriptionId}",
  "tags": {
    "CreatedBy": "Drasi-AutoBastion",
    "Purpose": "Automated-RBAC-Response"
  }
}
```

## How It Works

1. **Event Reception**: Function receives Event Grid notifications from Drasi
2. **Event Parsing**: Extracts role assignment details from the event payload
3. **Action Mapping**: Looks up configured actions for the specific role and operation
4. **Action Execution**: Runs the appropriate action handlers
5. **Result Logging**: Logs success/failure and detailed information

## Event Flow

```
Azure Activity Log → Event Hub → Drasi → Event Grid → Azure Function → Azure Actions
```

## Sample Event Processing

When a VM Administrator Login role is assigned, the function will:

1. Parse the incoming Drasi event
2. Identify the role definition ID (`1c0163c0-47e6-4577-8991-ea5c82e286e4`)
3. Look up configured actions (`CreateBastion`)
4. Execute the Bastion creation logic
5. Log the results

## Adding New Roles and Actions

### Adding a New Role

1. Find the role definition ID from Azure
2. Add to `config.json`:

```json
"/providers/Microsoft.Authorization/roleDefinitions/YOUR-ROLE-ID": {
  "name": "Your Role Name",
  "description": "Role description",
  "actions": {
    "create": ["YourAction"],
    "delete": ["YourCleanupAction"]
  }
}
```

### Creating a New Action

1. Add action configuration to `config.json`
2. Create action class in `ActionHandlers.ps1`:

```powershell
class YourAction : BaseAction {
    [ActionResult] Execute([hashtable]$context) {
        # Your action logic here
        return [ActionResult]::new($true, "Action completed", @{})
    }
}
```

3. Register in ActionFactory:

```powershell
"YourAction" { return [YourAction]::new($config, $globalConfig) }
```

## Testing

### Dry Run Mode

Enable dry run to test without making actual changes:

```json
"global": {
  "dryRun": true
}
```

### Sample Test Event

Use this sample payload to test the function:

```json
{
  "type": "Drasi.ChangeEvent",
  "data": {
    "op": "i",
    "payload": {
      "after": {
        "properties": {
          "requestbody": "{\"Properties\":{\"RoleDefinitionId\":\"/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4\",\"PrincipalId\":\"test-principal\",\"Scope\":\"/subscriptions/test-sub\"}}"
        },
        "correlationId": "test-correlation-id",
        "timestamp": "2024-01-01T00:00:00Z"
      }
    }
  }
}
```

## Prerequisites

- Azure Function App with PowerShell 7 runtime
- Managed Identity with appropriate permissions:
  - `Network Contributor` (for Bastion creation)
  - `Virtual Machine Contributor` (for VM-related operations)
  - `Reader` (for resource discovery)
- Event Grid subscription configured to send Drasi events to the function

## Security Considerations

- Function uses Managed Identity for Azure authentication
- All created resources are tagged for tracking
- Dry run mode available for safe testing
- Role assignments are validated before action execution
- Cleanup actions include safety checks to prevent accidental deletion

## Troubleshooting

### Common Issues

1. **Configuration not loading**: Check `config.json` syntax
2. **Actions not executing**: Verify role definition IDs match exactly
3. **Permission errors**: Ensure Managed Identity has required permissions
4. **Resource creation failures**: Check resource naming and availability

### Debug Mode

Enable detailed logging:

```json
"global": {
  "enableLogging": true
}
```

### Log Analysis

The function provides structured logging:
- `[INFO]` - Normal operation
- `[WARNING]` - Non-critical issues
- `[ERROR]` - Failures requiring attention

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   config.json   │    │ EventProcessor  │    │ ActionHandlers  │
│                 │    │                 │    │                 │
│ Role Mappings   │───▶│ Event Parsing   │───▶│ Action Classes  │
│ Action Config   │    │ Orchestration   │    │ Azure Operations│
│ Global Settings │    │ Result Logging  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Contributing

To add new functionality:

1. Update `config.json` with new role/action mappings
2. Create new action classes in `ActionHandlers.ps1`
3. Register actions in `ActionFactory`
4. Test with dry run mode
5. Update this documentation

## References

- [Bellhop Pattern](https://azure.github.io/bellhop/#/README)
- [Azure Bastion Documentation](https://docs.microsoft.com/en-us/azure/bastion/)
- [Azure RBAC Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Drasi Documentation](https://drasi.io/)