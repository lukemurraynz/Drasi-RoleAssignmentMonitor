@description('The name of the function app')
param functionAppName string = 'func-drasi-bastion-${uniqueString(resourceGroup().id)}'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The Azure subscription ID where the function will operate')
param subscriptionId string = subscription().subscriptionId

@description('The managed identity client ID for authentication')
param managedIdentityClientId string

@description('The storage account name for the function app')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('The App Service plan name')
param appServicePlanName string = 'asp-drasi-bastion-${uniqueString(resourceGroup().id)}'

@description('The Application Insights name')
param appInsightsName string = 'ai-drasi-bastion-${uniqueString(resourceGroup().id)}'

@description('VM Administrator Role ID')
param vmAdminRoleId string = '1c0163c0-47e6-4577-8991-ea5c82e286e4'

@description('Log Analytics workspace name')
param logAnalyticsWorkspaceName string = 'log-drasi-bastion-${uniqueString(resourceGroup().id)}'

// Storage Account for Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan (Consumption plan for cost efficiency)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {
    reserved: false
  }
}

// Managed Identity for the Function App
resource functionAppManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${functionAppName}-identity'
  location: location
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionAppManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '7.2'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscriptionId
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: functionAppManagedIdentity.properties.clientId
        }
        {
          name: 'VM_ADMIN_ROLE_ID'
          value: vmAdminRoleId
        }
        {
          name: 'BASTION_SUBNET_NAME'
          value: 'AzureBastionSubnet'
        }
        {
          name: 'BASTION_SKU'
          value: 'Basic'
        }
        {
          name: 'LOG_LEVEL'
          value: 'Information'
        }
      ]
      powerShellVersion: '7.2'
      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: []
      }
    }
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    clientAffinityEnabled: false
  }
  dependsOn: [
    appInsights
    storageAccount
  ]
}

// Role assignments for the managed identity
// Contributor role to manage Bastion and related resources
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionAppManagedIdentity.id, 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: functionAppManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Reader role at subscription level to check role assignments across VMs
resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionAppManagedIdentity.id, 'acdd72a7-3385-48ef-bd42-f606fba81ae7', subscription().id)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalId: functionAppManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Output values
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output managedIdentityId string = functionAppManagedIdentity.id
output managedIdentityClientId string = functionAppManagedIdentity.properties.clientId
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name