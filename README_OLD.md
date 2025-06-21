# Azure Role Assignment Monitor with Drasi

This repository demonstrates how to monitor Azure role assignment changes in real-time using [Drasi](https://drasi.io/), a continuous event processing platform. The system watches for Azure role assignment creations, updates, and deletions, then automatically triggers notifications via Azure Event Grid.

## What is Drasi?

[Drasi](https://drasi.io/) is a modern event-driven platform that enables real-time monitoring and reaction to changes in your data. It uses a declarative approach with three main components:

- **Sources**: Where data comes from (Event Hub, databases, APIs, etc.)
- **Continuous Queries**: What changes to watch for (using Drasi Query Language - DQL)
- **Reactions**: What to do when changes occur (send to Event Grid, webhook, etc.)

## What This Repository Does

This implementation monitors Azure Activity Logs for role assignment operations and automatically:

1. **Captures** Azure role assignment events from an Event Hub
2. **Processes** the events using a continuous query to extract relevant information
3. **Triggers** notifications to Azure Event Grid when role assignments are created, updated, or deleted
4. **Manages** Azure Bastion resources automatically via PowerShell Azure Function

### New: Azure Function for Bastion Management

The repository now includes a PowerShell-based Azure Function (`AzureFunction/`) that:

- **Receives** Event Grid events from the Drasi reaction
- **Creates** Azure Bastion hosts when VM Administrator Login roles are assigned
- **Removes** Bastion hosts when roles are revoked (if no other VMs need access)
- **Provides** an extensible framework for managing other Azure resources based on role assignments

This follows an event-driven automation pattern, using Drasi reactions instead of tag-based scheduling.

### Architecture Overview

```
Azure Activity Logs → Event Hub → Drasi Source → Continuous Query → Reaction → Event Grid → Azure Function → Bastion
```

This repository now includes an **Azure Function** that extends the event processing pipeline to automatically manage Azure Bastion resources based on VM Administrator Login role assignments.

## Prerequisites

Before getting started, ensure you have:

- **Azure CLI** installed and authenticated
- **kubectl** configured to access your Kubernetes cluster
- **Drasi CLI** installed ([installation guide](https://drasi.io/getting-started/))
- **Azure Event Hub** configured to receive Activity Logs
- **Azure Event Grid** topic for receiving notifications
- **Managed Identity** with appropriate permissions _for AKS Cluster_ or _Azure Resource modification_
- **Azure Function App** (for Bastion management) with PowerShell runtime

## Quick Start

### 1. Install and Initialize Drasi

Choose one of the deployment options below:

#### Option A: Docker Deployment (Recommended for Development)

```bash
# Initialize Drasi with Docker support
drasi init --docker
```

#### Option B: Kubernetes Deployment (Production)

```bash
# Install kubectl if not already installed
sudo az aks install-cli

# Login to Azure and get cluster credentials
az login
az aks get-credentials --resource-group <your-resource-group> --name <your-cluster-name>

# Initialize Drasi on Kubernetes
drasi init --namespace drasi-system --version 0.3.4

# Verify installation
kubectl get pods -n drasi-system
```

### 2. Configure Azure Authentication

For Kubernetes deployments, set up managed identity federated credentials:

```bash
# Create federated credential for the Event Hub source
az identity federated-credential create \
    --name drasi-eventhub \
    --identity-name "<your-managed-identity-name>" \
    --resource-group "<your-resource-group>" \
    --issuer "<your-aks-oidc-issuer-url>" \
    --subject system:serviceaccount:"drasi-system":"source.azure-role-eventhub-source" \
    --audience api://AzureADTokenExchange

# Create federated credential for the reaction
az identity federated-credential create \
    --name drasi-reaction \
    --identity-name "<your-managed-identity-name>" \
    --resource-group "<your-resource-group>" \
    --issuer "<your-aks-oidc-issuer-url>" \
    --subject system:serviceaccount:"drasi-system":"reaction.my-reactionvmlogin" \
    --audience api://AzureADTokenExchange
```

### 3. Configure Your Environment

Update the configuration files with your Azure resources:

#### Update Event Hub Source (`Sources/eventhubsource.yaml`)
```yaml
# Update these values with your Azure resources
spec:
  identity:
    clientId: <your-managed-identity-client-id>
  properties:
    host: <your-eventhub-namespace>.servicebus.windows.net
    eventHubs:
      - <your-eventhub-name>
```

#### Update Event Grid Reaction (`Reactions/azure-role-change-vmadminloginaction.yaml`)
```yaml
# Update these values with your Event Grid topic
spec:
  properties: 
    eventGridUri: https://<your-eventgrid-topic>.<region>.eventgrid.azure.net/api/events
    eventGridKey: <your-eventgrid-access-key>
```

### 4. Deploy the Drasi Components

Deploy the components in the correct order:

```bash
# 1. Deploy the Event Hub source
drasi apply -f Sources/eventhubsource.yaml

# 2. Deploy the continuous query
drasi apply -f Queries/azure-role-change-vmadminlogin.yaml

# 3. Deploy the Event Grid reaction
drasi apply -f Reactions/azure-role-change-vmadminloginaction.yaml
```

### 5. Verify Deployment

Check that all components are running:

```bash
# List all Drasi resources
drasi list source
drasi list query
drasi list reaction

# Check detailed status
drasi describe source azure-role-eventhub-source
drasi describe query azure-role-change-vmadminlogin
drasi describe reaction my-reactionvmlogin
```

### 6. Configure and Deploy the Azure Function

The Azure Function provides modular, configuration-driven automation for RBAC events:

#### Configuration
1. **Update `AzureFunction/config.json`** with your role-to-action mappings:
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

3. **Deploy the Function App** with PowerShell 7 runtime and configure Event Grid subscription

See `AzureFunction/README.md` for detailed configuration and deployment instructions.

## Understanding the Components

### Azure Function for Bastion Management (`AzureFunction/`)

**UPDATED**: This modular PowerShell-based Azure Function provides configuration-driven automation:

- **Modular Design**: Pattern for extensible automation
- **Configuration-Driven**: Simple JSON configuration maps RBAC roles to actions
- **Event-Driven**: Triggered by Event Grid events from the Drasi reaction
- **Beginner-Friendly**: Designed for first-time Azure and PowerShell users
- **Intelligent Logic**: Creates Bastion only when needed, removes when safe
- **Extensible Framework**: Easily add new roles and actions without code changes
- **Security-First**: Uses managed identity and follows least-privilege principles

Key features:
- **Simple Configuration**: JSON-based role-to-action mapping
- **Built-in Actions**: Azure Bastion creation/cleanup for VM admin roles
- **Dry Run Mode**: Test safely without making actual Azure changes
- **Comprehensive Logging**: Detailed logging for debugging and monitoring
- **Error Handling**: Robust error handling with graceful fallbacks
- **Sample Events**: Included test data for validation

#### Quick Start
1. Configure role mappings in `config.json`
2. Deploy Function App and configure Event Grid
3. Monitor logs for automation results

#### Adding New Roles/Actions
- **New Role**: Add role definition ID and actions to `config.json`
- **New Action**: Create action class in `ActionHandlers.ps1`
- **Test**: Use dry run mode and sample events for validation

See `AzureFunction/README.md` for detailed documentation.

### Event Hub Source (`Sources/eventhubsource.yaml`)
This source connects to an Azure Event Hub that receives Azure Activity Logs. It:
- Monitors specific Event Hub for role assignment events
- Provides a `bootstrapWindow` to catch recent events on startup

### Continuous Query (`Queries/azure-role-change-vmadminlogin.yaml`)

This query uses [Drasi Query Language (DQL)](https://drasi.io/reference/query-language/) to:
- Extract role assignment events from the Event Hub stream
- Filter for CREATE, UPDATE, and DELETE operations
- Transform the data into a structured format
- Continuously monitor for new events

Key features:
- **Event Filtering**: Only processes role assignment operations
- **Data Transformation**: Extracts relevant fields like correlation ID, timestamp, and operation type
- **Real-time Processing**: Processes events as they arrive

### Event Grid Reaction (`Reactions/azure-role-change-vmadminloginaction.yaml`)

This reaction:
- Subscribes to results from the continuous query
- Sends formatted notifications to Azure Event Grid
- Uses `unpacked` format for easy consumption by downstream systems

## Monitoring and Troubleshooting

### View Logs

```bash
# For Kubernetes deployments
kubectl logs -n drasi-system -l app=drasi-source --tail=100
kubectl logs -n drasi-system -l app=drasi-query --tail=100
kubectl logs -n drasi-system -l app=drasi-reaction --tail=100

# For Docker deployments
docker logs drasi-source
docker logs drasi-query
docker logs drasi-reaction
```

### Common Issues

1. **Authentication Errors**: Verify managed identity permissions and federated credentials
2. **Event Hub Connection**: Check network connectivity and Event Hub configuration
3. **Query Errors**: Validate DQL syntax against the [query language reference](https://drasi.io/reference/query-language/)

## Customization

### Modifying the Query

To monitor different events or change the data transformation, edit `Queries/azure-role-change-vmadminlogin.yaml`. Refer to the [Drasi Query Language documentation](https://drasi.io/reference/query-language/) for syntax and available functions.

### Adding More Reactions

You can add multiple reactions to the same query:
- Email notifications
- Slack messages
- Database updates
- Custom webhooks

## Resources

- **[Drasi Documentation](https://drasi.io/)** - Complete platform documentation
- **[Drasi Query Language Reference](https://drasi.io/reference/query-language/)** - DQL syntax and functions
- **[Drasi GitHub Organization](https://github.com/orgs/drasi-project/repositories)** - Source code and examples
- **[Azure Activity Log Schema](https://learn.microsoft.com/azure/azure-monitor/platform/activity-log-schema?WT.mc_id=AZ-MVP-5004796)** - Understanding Azure Activity Log events

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.
