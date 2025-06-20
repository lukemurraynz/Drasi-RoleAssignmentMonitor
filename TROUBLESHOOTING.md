# Troubleshooting Guide for Drasi Azure Role Monitor

## Quick Diagnostics

### 🔍 Check System Status

```bash
# Check if Drasi is running
drasi version

# Check deployed components
drasi list sources
drasi list queries  
drasi list reactions

# Check Azure CLI authentication
az account show
```

## Common Issues and Solutions

### ❌ Issue: "Drasi components not deploying"

**Symptoms:**
- `drasi apply` commands fail
- Error messages about connectivity

**Solutions:**
1. **Check Drasi installation:**
   ```bash
   drasi version
   # Should show version info, not errors
   ```

2. **Verify cluster connectivity:**
   ```bash
   kubectl get pods -n drasi-system
   # Should show running Drasi pods
   ```

3. **Check configuration files:**
   - Ensure YAML files have correct indentation
   - Verify all placeholder values are replaced

### ❌ Issue: "Azure Function not triggering"

**Symptoms:**
- Role assignments happen but no Bastion is created
- No logs in Azure Function

**Solutions:**
1. **Check Event Grid subscription:**
   - Verify it points to your Function App
   - Ensure the endpoint URL is correct
   - Check if events are being delivered

2. **Verify Function App configuration:**
   ```bash
   # Check if Function App exists and is running
   az functionapp show --name YOUR-FUNCTION-APP --resource-group YOUR-RG
   ```

3. **Check Managed Identity:**
   ```bash
   # Verify managed identity is enabled
   az functionapp identity show --name YOUR-FUNCTION-APP --resource-group YOUR-RG
   ```

### ❌ Issue: "Permission denied errors in Azure Function"

**Symptoms:**
- Function triggers but fails with permission errors
- "Insufficient privileges" messages in logs

**Solutions:**
1. **Assign required roles to Managed Identity:**
   ```bash
   # Get the Function App's managed identity
   PRINCIPAL_ID=$(az functionapp identity show --name YOUR-FUNCTION-APP --resource-group YOUR-RG --query principalId -o tsv)
   
   # Assign Network Contributor role
   az role assignment create --assignee $PRINCIPAL_ID --role "Network Contributor" --scope "/subscriptions/YOUR-SUBSCRIPTION-ID"
   
   # Assign Virtual Machine Contributor role  
   az role assignment create --assignee $PRINCIPAL_ID --role "Virtual Machine Contributor" --scope "/subscriptions/YOUR-SUBSCRIPTION-ID"
   
   # Assign Reader role
   az role assignment create --assignee $PRINCIPAL_ID --role "Reader" --scope "/subscriptions/YOUR-SUBSCRIPTION-ID"
   ```

### ❌ Issue: "Bastion creation fails"

**Symptoms:**
- Function triggers successfully but Bastion creation fails
- VNet or subnet errors

**Solutions:**
1. **Check subnet availability:**
   ```bash
   # List existing subnets in your VNet
   az network vnet subnet list --vnet-name YOUR-VNET --resource-group YOUR-RG
   ```

2. **Verify IP address space:**
   - Ensure your `subnetAddressPrefix` doesn't overlap with existing subnets
   - AzureBastionSubnet requires minimum /26 CIDR

3. **Check resource quotas:**
   ```bash
   # Check available quota for Public IPs
   az vm list-usage --location YOUR-REGION --query "[?name.value=='PublicIPAddresses']"
   ```

### ❌ Issue: "Configuration not loading"

**Symptoms:**
- Function runs but uses default values
- "Configuration not found" errors

**Solutions:**
1. **Verify config.json syntax:**
   ```bash
   # Test JSON syntax
   cat AzureFunction/config.json | jq .
   # Should output formatted JSON, not errors
   ```

2. **Check file paths in Function App:**
   - Ensure config.json is in the root of your Function App
   - Verify file was uploaded correctly

3. **Validate placeholder replacement:**
   - All `<your-*>` placeholders should be replaced with actual values
   - No angle brackets should remain in the file

## Debug Mode

### Enable Detailed Logging

1. **Update config.json:**
   ```json
   {
     "global": {
       "enableLogging": true
     }
   }
   ```

2. **Check Azure Function logs:**
   - Go to Azure Portal → Function App → Monitor → Logs
   - Look for detailed execution information

### Test Function Locally

1. **Use sample event:**
   ```bash
   # Upload sample-events.json as test data
   # Trigger function manually in Azure Portal
   ```

2. **Validate event parsing:**
   - Check if events are being parsed correctly
   - Verify role definition IDs match your configuration

## Network Troubleshooting

### Event Hub Connectivity

```bash
# Test Event Hub connection
az eventhubs eventhub show --resource-group YOUR-RG --namespace-name YOUR-NAMESPACE --name YOUR-EVENTHUB
```

### Event Grid Connectivity  

```bash
# Test Event Grid topic
az eventgrid topic show --name YOUR-TOPIC --resource-group YOUR-RG
```

### Function App Connectivity

```bash
# Test Function App endpoint
curl -X POST "https://YOUR-FUNCTION-APP.azurewebsites.net/runtime/webhooks/eventgrid?functionName=EventGridTrigger1" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## Performance Issues

### Slow Bastion Creation

**Causes:**
- Network latency
- Resource provider throttling
- Large VNet configurations

**Solutions:**
1. **Optimize subnet creation:**
   - Pre-create VNets with AzureBastionSubnet
   - Use consistent IP addressing schemes

2. **Monitor throttling:**
   ```bash
   # Check for throttling events
   az monitor activity-log list --max-events 50 --query "[?contains(status.value, 'Throttled')]"
   ```

## Monitoring and Alerting

### Set up Azure Monitor Alerts

1. **Function execution failures:**
   ```bash
   az monitor metrics alert create \
     --name "Function-Execution-Failures" \
     --resource-group YOUR-RG \
     --scopes "/subscriptions/YOUR-SUB/resourceGroups/YOUR-RG/providers/Microsoft.Web/sites/YOUR-FUNCTION-APP" \
     --condition "count FunctionExecutionCount < 1" \
     --description "Function not executing"
   ```

2. **Bastion creation failures:**
   - Monitor for specific error patterns in Function logs
   - Set up custom log queries for failure detection

### Health Checks

Create a simple health check function:

```powershell
# Add to your Function App
function Test-SystemHealth {
    $results = @{
        Drasisource = Test-DrasiConnection
        EventGrid = Test-EventGridConnection  
        AzureAuth = Test-AzureAuthentication
        Configuration = Test-Configuration
    }
    return $results
}
```

## Getting Help

### Log Analysis

When reporting issues, include:
1. **Function execution logs** (last 10-20 entries)
2. **Configuration file** (sanitized, no secrets)
3. **Error messages** (full stack traces)
4. **Azure resource details** (subscription, region, etc.)

### Useful Commands for Support

```bash
# Gather system information
echo "=== Drasi Version ==="
drasi version

echo "=== Drasi Components ==="
drasi list sources
drasi list queries
drasi list reactions

echo "=== Azure Context ==="
az account show
az group list --query "[].{Name:name, Location:location}"

echo "=== Function App Status ==="
az functionapp list --query "[].{Name:name, State:state, Location:location}"
```

### Community Support

- [Drasi GitHub Discussions](https://github.com/orgs/drasi-project/discussions)
- [Azure Functions Community](https://github.com/Azure/azure-functions)
- [PowerShell Community](https://github.com/PowerShell/PowerShell)

---

**Remember:** When in doubt, enable debug logging and check the Azure Portal for detailed error messages!
