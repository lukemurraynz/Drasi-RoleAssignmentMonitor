#!/bin/bash

# Azure Function App Deployment Script for Drasi Bastion Manager
# This script deploys the Azure Function App and related resources

set -e

# Configuration
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID=""
LOCATION="Australia East"
FUNCTION_APP_NAME=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Azure CLI is installed
check_prerequisites() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    if ! command -v func &> /dev/null; then
        log_warning "Azure Functions Core Tools not found. Installing..."
        npm install -g azure-functions-core-tools@4 --unsafe-perm true
    fi
}

# Get configuration from user
get_configuration() {
    if [ -z "$RESOURCE_GROUP_NAME" ]; then
        read -p "Enter Resource Group Name: " RESOURCE_GROUP_NAME
    fi

    if [ -z "$SUBSCRIPTION_ID" ]; then
        read -p "Enter Subscription ID: " SUBSCRIPTION_ID
    fi

    if [ -z "$FUNCTION_APP_NAME" ]; then
        read -p "Enter Function App Name: " FUNCTION_APP_NAME
    fi

    log_info "Configuration:"
    log_info "  Resource Group: $RESOURCE_GROUP_NAME"
    log_info "  Subscription: $SUBSCRIPTION_ID"
    log_info "  Function App: $FUNCTION_APP_NAME"
    log_info "  Location: $LOCATION"
}

# Login and set subscription
setup_azure_context() {
    log_info "Setting up Azure context..."
    
    # Check if already logged in
    if ! az account show &> /dev/null; then
        log_info "Logging into Azure..."
        az login
    fi

    # Set subscription
    log_info "Setting subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
}

# Create resource group if it doesn't exist
create_resource_group() {
    log_info "Checking if resource group exists..."
    
    if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        log_info "Creating resource group $RESOURCE_GROUP_NAME..."
        az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    else
        log_info "Resource group $RESOURCE_GROUP_NAME already exists"
    fi
}

# Deploy Azure resources using Bicep
deploy_infrastructure() {
    log_info "Deploying Azure infrastructure..."
    
    # Update parameters file with actual values
    cat > Deployment/function-app.parameters.json << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "functionAppName": {
      "value": "$FUNCTION_APP_NAME"
    },
    "location": {
      "value": "$LOCATION"
    },
    "storageAccountName": {
      "value": "st$(echo $FUNCTION_APP_NAME | tr '[:upper:]' '[:lower:]' | tr -d '-')"
    },
    "appServicePlanName": {
      "value": "asp-$FUNCTION_APP_NAME"
    },
    "appInsightsName": {
      "value": "ai-$FUNCTION_APP_NAME"
    },
    "logAnalyticsWorkspaceName": {
      "value": "log-$FUNCTION_APP_NAME"
    }
  }
}
EOF

    # Deploy using Azure CLI
    az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "Deployment/function-app.bicep" \
        --parameters "@Deployment/function-app.parameters.json" \
        --verbose

    if [ $? -eq 0 ]; then
        log_info "Infrastructure deployment completed successfully"
    else
        log_error "Infrastructure deployment failed"
        exit 1
    fi
}

# Deploy function code
deploy_function_code() {
    log_info "Deploying function code..."
    
    cd AzureFunction
    
    # Zip the function files
    zip -r ../function-app.zip . -x "*.git*" "local.settings.json"
    
    cd ..
    
    # Deploy the zip file
    az functionapp deployment source config-zip \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$FUNCTION_APP_NAME" \
        --src "function-app.zip"

    if [ $? -eq 0 ]; then
        log_info "Function code deployment completed successfully"
        rm -f function-app.zip
    else
        log_error "Function code deployment failed"
        exit 1
    fi
}

# Configure Event Grid subscription
configure_event_grid() {
    log_info "Configuring Event Grid subscription..."
    
    # Get the function app's Event Grid trigger URL
    FUNCTION_KEY=$(az functionapp keys list --resource-group "$RESOURCE_GROUP_NAME" --name "$FUNCTION_APP_NAME" --query "functionKeys.default" -o tsv)
    WEBHOOK_URL="https://$FUNCTION_APP_NAME.azurewebsites.net/runtime/webhooks/eventgrid?functionName=ProcessRoleAssignment&code=$FUNCTION_KEY"
    
    log_info "Event Grid webhook URL: $WEBHOOK_URL"
    log_warning "Please configure your Event Grid subscription to use this webhook URL"
    log_warning "You may need to update your Drasi reaction configuration to point to the correct Event Grid topic"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check if function app is running
    FUNCTION_STATUS=$(az functionapp show --resource-group "$RESOURCE_GROUP_NAME" --name "$FUNCTION_APP_NAME" --query "state" -o tsv)
    
    if [ "$FUNCTION_STATUS" = "Running" ]; then
        log_info "Function app is running successfully"
    else
        log_warning "Function app status: $FUNCTION_STATUS"
    fi
    
    # Get function app URL
    FUNCTION_URL=$(az functionapp show --resource-group "$RESOURCE_GROUP_NAME" --name "$FUNCTION_APP_NAME" --query "defaultHostName" -o tsv)
    log_info "Function app URL: https://$FUNCTION_URL"
}

# Main execution
main() {
    log_info "Starting Azure Function App deployment for Drasi Bastion Manager"
    
    check_prerequisites
    get_configuration
    setup_azure_context
    create_resource_group
    deploy_infrastructure
    deploy_function_code
    configure_event_grid
    verify_deployment
    
    log_info "Deployment completed successfully!"
    log_info "Next steps:"
    log_info "1. Configure your Event Grid subscription to use the webhook URL provided above"
    log_info "2. Update your Drasi reaction if needed"
    log_info "3. Test the solution by creating/removing VM Administrator Login role assignments"
}

# Run main function
main "$@"