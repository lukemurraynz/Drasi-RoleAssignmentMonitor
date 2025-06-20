# Azure Role Assignment Monitor with Drasi

> **✨ Readme✨**

## What Does This Project Do?

Imagine you work at a company where people frequently need access to virtual machines (VMs) in Azure. Traditionally, an admin would:

1. **Manually** assign VM access permissions to users
2. **Manually** create a secure connection tool (Azure Bastion) for each VM
3. **Manually** clean up these resources when access is no longer needed

This project **automates all of that**! It watches for permission changes and automatically creates or removes the necessary infrastructure.

### Real-World Example

When Sarah from Marketing needs access to a VM:
1. An admin assigns her "VM Administrator Login" role
2. **Automatically**, this system detects the change
3. **Automatically**, it creates a secure Bastion host for that VM
4. Sarah can now securely connect to the VM
5. When her access is revoked, the Bastion is **automatically** cleaned up

## Key Technologies Explained

### 🔧 **Azure Functions**
Think of [Azure Functions](https://learn.microsoft.com/azure/azure-functions/functions-overview?WT.mc_id=AZ-MVP-5004796) like "mini-programs" that run in the cloud. They only execute when triggered by an event (like receiving a notification). You don't need to manage servers - Azure handles all the infrastructure.

### 📊 **Drasi**
[Drasi](https://drasi.io/) is a platform that watches for changes in your data and reacts instantly. It's like having a super-smart assistant that monitors everything and takes action when specific things happen.

**Drasi has three parts:**
- **Sources**: Where data comes from (in our case, Azure Activity Logs)
- **Continuous Queries**: What changes to watch for (role assignments)
- **Reactions**: What to do when changes happen (notify our Azure Function)

### 🛡️ **Azure Bastion**
A secure way to connect to VMs without exposing them to the internet. Think [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview?WT.mc_id=AZ-MVP-5004796) it as a secure "bridge" that lets users safely access VMs through their web browser.

### 💻 **PowerShell**
A scripting language that's excellent for automating Azure tasks. Don't worry if you're new to it - our code is well-commented and modular!

## How The System Works

```
📋 Azure Activity Logs → 📨 Event Hub → 🔍 Drasi → 📧 Event Grid → ⚡ Azure Function → 🛡️ Bastion
```

### Step-by-Step Flow

1. **Azure Activity Logs**: Every action in Azure (like assigning roles) gets logged
2. **Event Hub**: Collects these logs in real-time
3. **Drasi Source**: Reads events from the Event Hub
4. **Drasi Continuous Query**: Filters for role assignment events we care about
5. **Drasi Reaction**: Sends notifications to Event Grid when matches are found
6. **Azure Function**: Receives the notification and takes action
7. **Bastion Management**: Creates or removes Azure Bastion hosts as needed

## What's In This Repository

```
📁 Sources/              # Drasi configuration for reading Azure Event Hub
📁 Queries/              # Drasi query that watches for role changes
📁 Reactions/            # Drasi reaction that sends notifications
📁 AzureFunction/        # PowerShell code that manages Azure resources
   📄 run.ps1           # Main function entry point
   📄 ActionHandlers.ps1 # Classes that perform specific actions
   📄 EventProcessor.ps1 # Parses incoming events
   📄 config.json       # Configuration for actions and roles
```

## Prerequisites (What You Need Before Starting)

### 🔧 **Software to Install**
- **Azure CLI**: Tool for managing Azure resources ([install guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **kubectl**: Tool for managing Kubernetes clusters ([install guide](https://kubernetes.io/docs/tasks/tools/))
- **Drasi CLI**: Tool for managing Drasi ([install guide](https://drasi.io/getting-started/))

### ☁️ **Azure Resources You Need**
- **Azure Event Hub**: Where Azure Activity Logs will be sent
- **Azure Event Grid Topic**: For receiving notifications from Drasi
- **Azure Function App**: With PowerShell 7 runtime to run our automation code
- **Managed Identity**: Special account that allows secure access to Azure resources

### 🔐 **Permissions Required**
Your Managed Identity needs these roles:
- `Network Contributor` (to create/delete Bastion hosts)
- `Virtual Machine Contributor` (to work with VMs)
- `Reader` (to discover existing resources)

## Quick Start Guide

### 1. Deploy Drasi

Choose how you want to run Drasi:

#### Option A: Docker (Easiest for Testing)
```bash
# Initialize Drasi with Docker support
drasi init --docker
```

#### Option B: Kubernetes (Best for Production)
```bash
# Initialize Drasi on your Kubernetes cluster
drasi init
```

### 2. Configure the Azure Function

#### Update Configuration File
Edit `AzureFunction/config.json` with your Azure details:

```json
{
  "global": {
    "enableLogging": true,
    "defaultSubscriptionId": "YOUR-SUBSCRIPTION-ID",
    "defaultResourceGroupName": "YOUR-RESOURCE-GROUP",
    "tags": {
      "CreatedBy": "Drasi-AutoBastion",
      "Purpose": "Automated-RBAC-Response"
    }
  },
  "actions": {
    "CreateBastion": {
      "enabled": true,
      "parameters": {
        "bastionNamePrefix": "bastion-auto",
        "subnetAddressPrefix": "10.0.1.0/26",
        "publicIpNamePrefix": "pip-bastion-auto"
      }
    }
  }
}
```

#### Deploy the Azure Function
1. Create an Azure Function App with PowerShell 7 runtime
2. Enable Managed Identity for the Function App
3. Upload the contents of the `AzureFunction/` folder
4. Configure Event Grid subscription to trigger the function

### 3. Deploy Drasi Components

#### Deploy the Event Hub Source
```bash
# Update Sources/eventhubsource.yaml with your Event Hub details
drasi apply -f Sources/eventhubsource.yaml
```

#### Deploy the Continuous Query
```bash
# This watches for role assignment changes
drasi apply -f Queries/azure-role-change-vmadminlogin.yaml
```

#### Deploy the Reaction
```bash
# Update Reactions/azure-role-change-vmadminloginaction.yaml with your Event Grid details
drasi apply -f Reactions/azure-role-change-vmadminloginaction.yaml
```

### 4. Test the System

Create a test role assignment:
```bash
# Assign VM Administrator Login role to test
az role assignment create \
  --assignee "user@domain.com" \
  --role "Virtual Machine Administrator Login" \
  --scope "/subscriptions/YOUR-SUB-ID/resourceGroups/YOUR-RG/providers/Microsoft.Compute/virtualMachines/YOUR-VM"
```

Watch the logs in your Azure Function to see the automation in action!

## Visual Quick Start Overview

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Step 1    │    │   Step 2    │    │   Step 3    │    │   Step 4    │
│             │    │             │    │             │    │             │
│ Install     │───▶│ Configure   │───▶│ Deploy      │───▶│ Test        │
│ Drasi CLI   │    │ Azure       │    │ Components  │    │ System      │
│             │    │ Function    │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Understanding the Azure Function Code

The Azure Function is the "brain" of our automation. Here's how it's organized:

### 📄 **run.ps1** - The Main Entry Point
This file receives Event Grid notifications and orchestrates the response:

```powershell
# 1. Validates the incoming event
# 2. Parses role assignment details
# 3. Determines what actions to take
# 4. Executes the actions
# 5. Logs the results
```

### 📄 **EventProcessor.ps1** - Event Understanding
This file contains smart logic to understand different types of role assignment events:

```powershell
# Extracts information like:
# - What role was assigned/removed?
# - Who got the role?
# - What resource is involved?
# - When did it happen?
```

### 📄 **ActionHandlers.ps1** - The Action Performers
This file contains "action classes" that do the actual work:

```powershell
# CreateBastionAction: Creates Bastion hosts
# CleanupBastionAction: Removes Bastion hosts
# Future actions can be added here!
```

### 📄 **config.json** - The Control Center
This file defines:
- Which roles trigger which actions
- Configuration parameters for each action
- Global settings like logging and tagging

## How to Extend This System

Want to add new automation? Here's how:

### 📋 **Adding a New Role**

1. Find the role definition ID in Azure:
```bash
az role definition list --name "Your Role Name" --query "[].name"
```

2. Add to `config.json`:
```json
"roleMappings": {
  "/providers/Microsoft.Authorization/roleDefinitions/YOUR-ROLE-ID": "Your Role Name"
},
"actions": {
  "YourNewAction": {
    "enabled": true,
    "parameters": {
      "setting1": "value1"
    }
  }
}
```

### ⚡ **Creating a New Action**

1. Create a new class in `ActionHandlers.ps1`:
```powershell
class YourNewAction : BaseAction {
    YourNewAction([hashtable]$config, [hashtable]$globalConfig) : base($config, $globalConfig) {}
    
    [ActionResult] Execute([hashtable]$context) {
        $this.LogInfo("Starting your new action...")
        
        try {
            # Your automation logic here
            # For example: Create storage account, send email, etc.
            
            return [ActionResult]::new($true, "Action completed successfully", @{})
        }
        catch {
            return [ActionResult]::new($false, "Action failed: $($_.Exception.Message)", @{})
        }
    }
}
```

2. Register your action in the factory function:
```powershell
function New-Action {
    # ... existing code ...
    switch ($ActionName) {
        "YourNewAction" { 
            return [YourNewAction]::new($Config, $GlobalConfig) 
        }
        # ... other actions ...
    }
}
```

### 🔍 **Modifying the Drasi Query**

Want to watch for different events? Edit `Queries/azure-role-change-vmadminlogin.yaml`:

```yaml
# Change the filter to watch for different operations
selector: $.records[?(@.operationName == 'YOUR.OPERATION/HERE')]

# Or modify the query to return different data
query: |
  MATCH (r:RoleAssignment)
  WHERE r.operationName CONTAINS 'YOUR_FILTER'
  RETURN r.customField AS customData
```

## Troubleshooting

### 🚨 **Common Issues**

#### "Function not triggering"
- Check Event Grid subscription is pointing to your function
- Verify Drasi reaction has correct Event Grid URL and key
- Look at Azure Function logs for errors

#### "Permission denied errors"
- Ensure Managed Identity has required roles assigned
- Check that the identity is enabled on your Function App

#### "Bastion creation failing"
- Verify your VNet has available IP address space
- Check that the subnet CIDR doesn't conflict with existing subnets
- Ensure you have sufficient quota in your Azure subscription

### 📊 **Debug Mode**

Enable detailed logging in `config.json`:
```json
"global": {
  "enableLogging": true
}
```

### 🔍 **Testing Without Real Events**

Use the sample event in `AzureFunction/sample-events.json` to test your function locally.

## Security Best Practices

### 🔐 **Authentication**
- Always use Managed Identity (never store credentials in code)
- Regularly rotate Event Grid access keys
- Use the least-privilege principle for role assignments

### 🏷️ **Resource Tagging**
All created resources are automatically tagged for tracking:
```json
"tags": {
  "CreatedBy": "Drasi-AutoBastion",
  "Purpose": "Automated-RBAC-Response"
}
```

### 🛡️ **Safety Features**
- Dry-run mode available for testing
- Cleanup actions check for other dependencies before deleting
- All operations are logged for audit trails

## Advanced Configuration

### 🔧 **Fine-tuning Bastion Creation**

```json
"CreateBastion": {
  "parameters": {
    "bastionNamePrefix": "custom-bastion",
    "subnetAddressPrefix": "10.1.0.0/26",  // Customize IP range
    "publicIpNamePrefix": "pip-custom",
    "bastionSku": "Standard",              // or "Basic"
    "scaleUnits": 2                        // Number of scale units
  }
}
```

### ⏱️ **Cleanup Timing**

```json
"CleanupBastion": {
  "parameters": {
    "preserveIfOtherAssignments": true,    // Safety check
    "gracePeriodMinutes": 10,              // Wait before cleanup
    "forceCleanup": false                  // Emergency override
  }
}
```

## Monitoring and Observability

### 📈 **Azure Function Metrics**
Monitor these key metrics in the Azure Portal:
- Function execution count
- Success/failure rates
- Duration and performance
- Error frequency

### 📝 **Logging Strategy**
The function provides structured logging:
- `[INFO]` - Normal operations
- `[WARNING]` - Non-critical issues  
- `[ERROR]` - Failures requiring attention

### 🔔 **Alerting**
Set up Azure Monitor alerts for:
- Function execution failures
- Bastion creation/deletion events
- Permission-related errors

## Cost Management

### 💰 **Azure Bastion Costs**
- Standard SKU: ~$140/month per instance
- Basic SKU: ~$87/month per instance
- Consider cleanup automation to minimize costs

### 📊 **Resource Optimization**
- Use tags to track automation-created resources
- Implement cost alerts for your resource groups
- Regular audit of created Bastion hosts

## Contributing

Want to improve this project? Here's how:

### 🐛 **Reporting Issues**
1. Check existing issues first
2. Provide detailed error messages and logs
3. Include your configuration (sanitized)

### 🚀 **Adding Features**
1. Fork the repository
2. Create a feature branch
3. Add your new action classes
4. Update configuration examples
5. Test thoroughly
6. Submit a pull request

### 📖 **Documentation**
Help improve this README by:
- Adding more examples
- Clarifying complex concepts
- Fixing typos or errors

## Additional Resources

### 📚 **Learning More**
- [Drasi Documentation](https://drasi.io/)
- [Azure Functions PowerShell Guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-powershell?tabs=portal&WT.mc_id=AZ-MVP-5004796)
- [Azure Bastion Documentation](https://docs.microsoft.com/azure/bastion/)
- [PowerShell for Azure](https://docs.microsoft.com/powershell/azure/)

### 🤝 **Community**
- [Drasi GitHub](https://github.com/orgs/drasi-project/discussions](https://github.com/drasi-project)
- [Azure PowerShell Community](https://github.com/Azure/azure-powershell)

---

**Happy Automating! 🚀**

*This project demonstrates the power of event-driven automation using Drasi and Azure Functions. Start small, learn as you go, and gradually add more sophisticated automation to your environment.*

## Getting Started Fast 🚀

New to this project? We've made it super easy:

1. **📋 Run the setup checker:** `./setup.sh` - Verifies you have everything installed
2. **📝 Use the config template:** Copy `AzureFunction/config.template.json` to `AzureFunction/config.json`
3. **🆘 Having issues?** Check `TROUBLESHOOTING.md` for common problems and solutions
4. **📚 Follow the detailed guide below** for step-by-step instructions
