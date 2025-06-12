# ConfigurationManager.ps1 - Configuration management for extensible resource operations

. "$PSScriptRoot\Logger.ps1"

function Get-FunctionConfiguration {
    param(
        [string]$ConfigurationScope = "Global"
    )
    
    Write-LogDebug "Loading configuration for scope: $ConfigurationScope"
    
    $config = @{
        # Global settings
        Global = @{
            MaxRetries = [int]($env:MAX_RETRIES ?? 3)
            RetryDelaySeconds = [int]($env:RETRY_DELAY_SECONDS ?? 30)
            EnableDetailedLogging = [bool]($env:ENABLE_DETAILED_LOGGING ?? $true)
            DryRunMode = [bool]($env:DRY_RUN_MODE ?? $false)
            OperationTimeoutMinutes = [int]($env:OPERATION_TIMEOUT_MINUTES ?? 10)
        }
        
        # Azure connection settings
        Azure = @{
            SubscriptionId = $env:AZURE_SUBSCRIPTION_ID
            TenantId = $env:AZURE_TENANT_ID
            ClientId = $env:AZURE_CLIENT_ID
            UseManagedIdentity = [bool]($env:USE_MANAGED_IDENTITY ?? $true)
            DefaultLocation = $env:DEFAULT_AZURE_LOCATION ?? "Australia East"
        }
        
        # Role-specific settings - Extensible configuration for multiple roles and actions
        Roles = @{
            VMAdminLogin = @{
                RoleId = $env:VM_ADMIN_ROLE_ID ?? "1c0163c0-47e6-4577-8991-ea5c82e286e4"
                Actions = @{
                    OnAssigned = @("CreateBastion", "LogAssignment")
                    OnRemoved = @("EvaluateBastionRemoval", "LogRemoval")
                }
                ResourceTypes = @("Microsoft.Compute/virtualMachines", "Microsoft.Resources/subscriptions", "Microsoft.Resources/resourceGroups")
            }
            StorageBlobContributor = @{
                RoleId = $env:STORAGE_BLOB_CONTRIBUTOR_ROLE_ID ?? "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
                Actions = @{
                    OnAssigned = @("CreateStorageAccount", "LogAssignment")
                    OnRemoved = @("EvaluateStorageRemoval", "LogRemoval")
                }
                ResourceTypes = @("Microsoft.Storage/storageAccounts", "Microsoft.Resources/subscriptions", "Microsoft.Resources/resourceGroups")
            }
            NetworkContributor = @{
                RoleId = $env:NETWORK_CONTRIBUTOR_ROLE_ID ?? "4d97b98b-1d4f-4787-a291-c67834d212e7"
                Actions = @{
                    OnAssigned = @("ConfigureNetworkRules", "LogAssignment")
                    OnRemoved = @("RemoveNetworkRules", "LogRemoval")
                }
                ResourceTypes = @("Microsoft.Network/virtualNetworks", "Microsoft.Network/networkSecurityGroups", "Microsoft.Resources/subscriptions", "Microsoft.Resources/resourceGroups")
            }
        }
        
        # Resource-specific settings
        Resources = @{
            Bastion = @{
                DefaultSku = $env:BASTION_SKU ?? "Basic"
                SubnetName = $env:BASTION_SUBNET_NAME ?? "AzureBastionSubnet"
                SubnetSize = [int]($env:BASTION_SUBNET_SIZE ?? 26)
                NamingPattern = $env:BASTION_NAMING_PATTERN ?? "bastion-{vmname}-{random}"
                EnableTunneling = [bool]($env:BASTION_ENABLE_TUNNELING ?? $false)
                EnableKerberos = [bool]($env:BASTION_ENABLE_KERBEROS ?? $false)
                EnableShareableLink = [bool]($env:BASTION_ENABLE_SHAREABLE_LINK ?? $false)
                ScaleUnits = [int]($env:BASTION_SCALE_UNITS ?? 2)
                AutoCleanup = [bool]($env:BASTION_AUTO_CLEANUP ?? $true)
                CleanupDelayHours = [int]($env:BASTION_CLEANUP_DELAY_HOURS ?? 1)
            }
            
            NetworkSecurity = @{
                EnableAutomaticRules = [bool]($env:NSG_ENABLE_AUTOMATIC_RULES ?? $false)
                RulePrefix = $env:NSG_RULE_PREFIX ?? "Drasi-Auto"
                DefaultPriority = [int]($env:NSG_DEFAULT_PRIORITY ?? 1000)
            }
        }
        
        # Event processing settings
        EventProcessing = @{
            MaxProcessingTime = [int]($env:MAX_PROCESSING_TIME_SECONDS ?? 300)
            EnableEventValidation = [bool]($env:ENABLE_EVENT_VALIDATION ?? $true)
            RequireCorrelationId = [bool]($env:REQUIRE_CORRELATION_ID ?? $true)
            IgnoreTestEvents = [bool]($env:IGNORE_TEST_EVENTS ?? $true)
        }
        
        # Monitoring and alerts
        Monitoring = @{
            EnableApplicationInsights = [bool]($env:ENABLE_APPLICATION_INSIGHTS ?? $true)
            EnableCustomMetrics = [bool]($env:ENABLE_CUSTOM_METRICS ?? $true)
            AlertOnFailures = [bool]($env:ALERT_ON_FAILURES ?? $true)
            HealthCheckIntervalMinutes = [int]($env:HEALTH_CHECK_INTERVAL_MINUTES ?? 5)
        }
        
        # Security settings
        Security = @{
            ValidateEventSource = [bool]($env:VALIDATE_EVENT_SOURCE ?? $true)
            RequireSecureTransport = [bool]($env:REQUIRE_SECURE_TRANSPORT ?? $true)
            EnableEventEncryption = [bool]($env:ENABLE_EVENT_ENCRYPTION ?? $false)
            AllowedSubscriptions = ($env:ALLOWED_SUBSCRIPTIONS ?? "").Split(',') | Where-Object { $_ }
            AllowedResourceGroups = ($env:ALLOWED_RESOURCE_GROUPS ?? "").Split(',') | Where-Object { $_ }
        }
    }
    
    if ($ConfigurationScope -eq "Global") {
        return $config
    } else {
        return $config[$ConfigurationScope]
    }
}

function Test-ConfigurationValidity {
    param(
        [hashtable]$Configuration
    )
    
    $validationResults = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        # Validate required Azure settings
        if (-not $Configuration.Azure.SubscriptionId) {
            $validationResults.Errors += "Azure Subscription ID is required"
            $validationResults.IsValid = $false
        }
        
        # Validate role configuration
        if (-not $Configuration.Roles.VMAdminLogin.RoleId) {
            $validationResults.Errors += "VM Admin Role ID is required"
            $validationResults.IsValid = $false
        }
        
        # Validate numeric ranges
        if ($Configuration.Global.MaxRetries -lt 0 -or $Configuration.Global.MaxRetries -gt 10) {
            $validationResults.Warnings += "MaxRetries should be between 0 and 10"
        }
        
        if ($Configuration.Resources.Bastion.SubnetSize -lt 26 -or $Configuration.Resources.Bastion.SubnetSize -gt 29) {
            $validationResults.Errors += "Bastion subnet size must be between /26 and /29"
            $validationResults.IsValid = $false
        }
        
        # Validate security settings
        if ($Configuration.Security.AllowedSubscriptions.Count -eq 0 -and $Configuration.Security.ValidateEventSource) {
            $validationResults.Warnings += "Event source validation is enabled but no allowed subscriptions specified"
        }
        
        Write-LogInfo "Configuration validation completed. Valid: $($validationResults.IsValid)"
        if ($validationResults.Errors.Count -gt 0) {
            Write-LogError "Configuration errors: $($validationResults.Errors -join ', ')"
        }
        if ($validationResults.Warnings.Count -gt 0) {
            Write-LogWarning "Configuration warnings: $($validationResults.Warnings -join ', ')"
        }
        
        return $validationResults
    }
    catch {
        Write-LogError "Error validating configuration: $($_.Exception.Message)"
        return @{
            IsValid = $false
            Errors = @("Configuration validation failed: $($_.Exception.Message)")
            Warnings = @()
        }
    }
}

function Get-ResourceActionConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleId,
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        [Parameter(Mandatory = $true)]
        [string]$Action
    )
    
    $config = Get-FunctionConfiguration
    
    # Find the role configuration
    $roleConfig = $null
    foreach ($role in $config.Roles.GetEnumerator()) {
        if ($role.Value.RoleId -eq $RoleId) {
            $roleConfig = $role.Value
            break
        }
    }
    
    if (-not $roleConfig) {
        Write-LogWarning "No configuration found for role: $RoleId"
        return $null
    }
    
    # Check if the resource type is supported for this role
    if ($roleConfig.ResourceTypes -notcontains $ResourceType) {
        Write-LogWarning "Resource type $ResourceType not supported for role $RoleId"
        return $null
    }
    
    # Get the specific action configuration
    $actionConfig = @{
        Role = $roleConfig
        Action = $Action
        ResourceType = $ResourceType
        GlobalConfig = $config.Global
        SecurityConfig = $config.Security
    }
    
    # Add resource-specific configuration
    switch ($ResourceType) {
        "Microsoft.Compute/virtualMachines" {
            if ($Action -like "*Bastion*") {
                $actionConfig.ResourceConfig = $config.Resources.Bastion
            }
        }
        "Microsoft.Network/networkSecurityGroups" {
            $actionConfig.ResourceConfig = $config.Resources.NetworkSecurity
        }
    }
    
    return $actionConfig
}

function Set-ConfigurationValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [string]$Scope = "Process"
    )
    
    try {
        switch ($Scope) {
            "Process" {
                [Environment]::SetEnvironmentVariable($Key, $Value, [EnvironmentVariableTarget]::Process)
                Write-LogInfo "Set configuration value: $Key = $Value (Process scope)"
            }
            "User" {
                [Environment]::SetEnvironmentVariable($Key, $Value, [EnvironmentVariableTarget]::User)
                Write-LogInfo "Set configuration value: $Key = $Value (User scope)"
            }
            "Machine" {
                [Environment]::SetEnvironmentVariable($Key, $Value, [EnvironmentVariableTarget]::Machine)
                Write-LogInfo "Set configuration value: $Key = $Value (Machine scope)"
            }
            default {
                Write-LogError "Invalid scope: $Scope. Use Process, User, or Machine"
                return $false
            }
        }
        return $true
    }
    catch {
        Write-LogError "Error setting configuration value: $($_.Exception.Message)"
        return $false
    }
}

function Get-ConfigurationFromKeyVault {
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string[]]$SecretNames
    )
    
    try {
        Write-LogInfo "Loading configuration from Key Vault: $KeyVaultName"
        
        $config = @{}
        
        foreach ($secretName in $SecretNames) {
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName -AsPlainText
                $config[$secretName] = $secret
                Write-LogDebug "Loaded secret: $secretName"
            }
            catch {
                Write-LogWarning "Could not load secret $secretName from Key Vault: $($_.Exception.Message)"
            }
        }
        
        return $config
    }
    catch {
        Write-LogError "Error loading configuration from Key Vault: $($_.Exception.Message)"
        return @{}
    }
}

function Export-ConfigurationTemplate {
    param(
        [string]$OutputPath = "configuration-template.json"
    )
    
    try {
        $template = Get-FunctionConfiguration
        $json = $template | ConvertTo-Json -Depth 10
        
        $json | Out-File -FilePath $OutputPath -Encoding UTF8
        
        Write-LogInfo "Configuration template exported to: $OutputPath"
        return $true
    }
    catch {
        Write-LogError "Error exporting configuration template: $($_.Exception.Message)"
        return $false
    }
}