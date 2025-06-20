
# ----------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

<#
.Synopsis
Creates or updates a policy definition.
.Description
The **New-AzPolicyDefinition** cmdlet creates or updates a policy definition that includes a policy rule JSON format.
.Notes
## RELATED LINKS

[Get-AzPolicyDefinition](./Get-AzPolicyDefinition.md)

[Remove-AzPolicyDefinition](./Remove-AzPolicyDefinition.md)

[Update-AzPolicyDefinition](./Update-AzPolicyDefinition.md)
.Link
https://learn.microsoft.com/powershell/module/az.resources/new-azpolicydefinition
#>
function New-AzPolicyDefinition {
[OutputType([Microsoft.Azure.PowerShell.Cmdlets.Policy.Models.IPolicyDefinition])]
[CmdletBinding(DefaultParameterSetName='Name', SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Alias('PolicyDefinitionName')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The name of the policy definition to create.
    ${Name},

    [Parameter(ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [System.String]
    # The display name of the policy definition.
    ${DisplayName},

    [Parameter(ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [System.String]
    # The policy definition description.
    ${Description},

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [System.String]
    # The policy rule.
    ${Policy},

    [Parameter(ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.Info(PossibleTypes=([Microsoft.Azure.PowerShell.Cmdlets.Policy.Models.IPolicyDefinitionPropertiesMetadata]))]
    [System.String]
    # The policy definition metadata.
    # Metadata is an open ended object and is typically a collection of key value pairs.
    ${Metadata},

    [Parameter(ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.Info(PossibleTypes=([Microsoft.Azure.PowerShell.Cmdlets.Policy.Models.IParameterDefinitions]))]
    [System.String]
    # The parameter definitions for parameters used in the policy rule.
    # The keys are the parameter names.
    ${Parameter},

    [Parameter(ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [System.String]
    # The policy definition mode.
    # Some examples are All, Indexed, Microsoft.KeyVault.Data.
    ${Mode},

    [Parameter(ParameterSetName='ManagementGroupName', Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The ID of the management group.
    ${ManagementGroupName},

    [Parameter(ParameterSetName='SubscriptionId', Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The ID of the target subscription.
    ${SubscriptionId},

    [Parameter()]
    [Obsolete('This parameter is a temporary bridge to new types and formats and will be removed in a future release.')]
    [System.Management.Automation.SwitchParameter]
    # Causes cmdlet to return artifacts using legacy format placing policy-specific properties in a property bag object.
    ${BackwardCompatible} = $false,

    [Parameter()]
    [Alias('AzureRMContext', 'AzureCredential')]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Azure')]
    [System.Management.Automation.PSObject]
    # The DefaultProfile parameter is not functional.
    # Use the SubscriptionId parameter when available if executing the cmdlet against a different subscription.
    ${DefaultProfile},

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Management.Automation.SwitchParameter]
    # Wait for .NET debugger to attach
    ${Break},

    [Parameter(DontShow)]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.SendAsyncStep[]]
    # SendAsync Pipeline Steps to be appended to the front of the pipeline
    ${HttpPipelineAppend},

    [Parameter(DontShow)]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.SendAsyncStep[]]
    # SendAsync Pipeline Steps to be prepended to the front of the pipeline
    ${HttpPipelinePrepend},

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Uri]
    # The URI for the proxy server to use
    ${Proxy},

    [Parameter(DontShow)]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Management.Automation.PSCredential]
    # Credentials for a proxy server to use for the remote call
    ${ProxyCredential},

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Management.Automation.SwitchParameter]
    # Use the default credentials for the proxy
    ${ProxyUseDefaultCredentials}
)

begin {
    # turn on console debug messages
    $writeln = ($PSCmdlet.MyInvocation.BoundParameters.Debug -as [bool]) -or ($PSCmdlet.MyInvocation.BoundParameters.Verbose -as [bool])

    if ($writeln) {
        Write-Host -ForegroundColor Cyan "begin:New-AzPolicyDefinition(" $PSBoundParameters ") - (ParameterSet: $($PSCmdlet.ParameterSetName))"
    }

    # mapping table of generated cmdlet parameter sets
    $mapping = @{
        CreateExpanded = 'Az.Policy.private\New-AzPolicyDefinition_CreateExpanded';
        CreateExpanded1 = 'Az.Policy.private\New-AzPolicyDefinition_CreateExpanded1';
        CreateViaIdentityExpanded1 = 'Az.Policy.private\New-AzPolicyDefinition_CreateViaIdentityExpanded1';
    }
}

process {
    if ($writeln) {
        Write-Host -ForegroundColor Cyan "process:New-AzPolicyDefinition(" $PSBoundParameters ") - (ParameterSet: $($PSCmdlet.ParameterSetName))"
    }

    # parameters hash table for called cmdlet
    $calledParameters = $PSBoundParameters

    # convert input/legacy policy parameter to correct set of parameters and remove
    if ($Policy) {
        $resolved = ResolvePolicyParameter -ParameterName 'Policy' -ParameterValue $Policy -Debug $writeln
        if ($resolved.policyRule) {
            foreach ($key in $resolved.Keys) {

                if ($key -eq 'name' -or $key -eq 'type' -or $key -eq 'id') {
                    continue
                }

                $value = $resolved.($key)

                if ($key -eq 'parameters') {
                    $key = 'Parameter'
                }

                if (!($calledParameters.($key))) {
                    $calledParameters.($key) = $value
                }
            }
        } else {
            $calledParameters.PolicyRule = $resolved
        }

        $null = $calledParameters.Remove('Policy')
    }

    # preserve default mode behavior of previous SDK-based cmdlets
    if (!$calledParameters.Mode) {
        $calledParameters.Mode = 'All'
    }

    # resolve [string] 'metadata' input parameter to [hashtable]
    if ($Metadata) {
        $calledParameters.MetadataTable = (ResolvePolicyMetadataParameter -MetadataValue $Metadata -Debug $writeln)
    }
    elseif ($calledParameters.Metadata) {
        $calledParameters.MetadataTable = (ResolvePolicyMetadataParameter -MetadataValue $calledParameters.Metadata -Debug $writeln)
    }

    $null = $calledParameters.Remove('Metadata')

    # resolve [string] 'parameter' input parameter (could be a path)
    if ($Parameter) {
        $calledParameters.Parameter = (ResolvePolicyParameter -ParameterName 'Parameter' -ParameterValue $Parameter -Debug $writeln)
    }

    # rename [string] 'parameter' parameter to 'parametertable' (needs to be string to construct properly)
    if ($calledParameters.Parameter) {
        $calledParameters.ParameterTable = $calledParameters.Parameter
        $null = $calledParameters.Remove('Parameter')
    }

    # determine called parameterset and convert ManagementGroupName parameter to ManagementGroupId if needed
    if ($calledParameters.ManagementGroupName) {
        $calledParameterSet = 'CreateExpanded1'
        $calledParameters.ManagementGroupId = $calledParameters.ManagementGroupName
        $null = $calledParameters.Remove('ManagementGroupName')
    } else {
        $calledParameterSet = 'CreateExpanded'
        if (!$SubscriptionId) {
            $calledParameters.SubscriptionId = (Get-SubscriptionId)
        }
    }

    # remove switch unknown to generated cmdlets
    if ($calledParameters.BackwardCompatible) {
        $null = $calledParameters.Remove('BackwardCompatible')
    }

    if ($writeln) {
        Write-Host -ForegroundColor Blue -> $mapping[$calledParameterSet]'(' $calledParameters ')'
    }

    # call internal generated cmdlet, convert generic JSON output properties to PSCustomObject
    $cmdInfo = Get-Command -Name $mapping[$calledParameterSet]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.MessageAttributeHelper]::ProcessCustomAttributesAtRuntime($cmdInfo, $MyInvocation, $calledParameterSet, $PSCmdlet)
    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(($mapping[$calledParameterSet]), [System.Management.Automation.CommandTypes]::Cmdlet)
    $scriptCmd = {& $wrappedCmd @calledParameters}
    $item = Invoke-Command -ScriptBlock $scriptCmd

    # add property bag for backward compatibility with previous SDK cmdlets
    if ($BackwardCompatible) {
        $propertyBag = @{
            Description = $item.Description;
            DisplayName = $item.DisplayName;
            Metadata = (ConvertObjectToPSObject $item.Metadata);
            Mode = $item.Mode;
            Parameters = (ConvertObjectToPSObject $item.Parameter);
            PolicyRule = (ConvertObjectToPSObject $item.PolicyRule);
            PolicyType = $item.PolicyType
        }

        $item | Add-Member -MemberType NoteProperty -Name 'Properties' -Value ([PSCustomObject]($propertyBag))
        $item | Add-Member -MemberType NoteProperty -Name 'ResourceId' -Value $item.Id
        $item | Add-Member -MemberType NoteProperty -Name 'ResourceName' -Value $item.Name
        $item | Add-Member -MemberType NoteProperty -Name 'ResourceType' -Value $item.Type
        $item | Add-Member -MemberType NoteProperty -Name 'PolicyDefinitionId' -Value $item.Id
    }

    $item | Add-Member -MemberType NoteProperty -Name 'Metadata' -Value (ConvertObjectToPSObject $item.Metadata) -Force
    $item | Add-Member -MemberType NoteProperty -Name 'Parameter' -Value (ConvertObjectToPSObject $item.Parameter) -Force
    $item | Add-Member -MemberType NoteProperty -Name 'PolicyRule' -Value (ConvertObjectToPSObject $item.PolicyRule) -Force
    $item | Add-Member -MemberType NoteProperty -Name 'Versions' -Value ([array]($item.Versions)) -Force
    $PSCmdlet.WriteObject($item)
}

end {
}
}
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCYAsfReKPk6+gd
# +BvWfQf0vOEAzabD4NlQBLJK8GUyqqCCDXYwggX0MIID3KADAgECAhMzAAAEBGx0
# Bv9XKydyAAAAAAQEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjQwOTEyMjAxMTE0WhcNMjUwOTExMjAxMTE0WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC0KDfaY50MDqsEGdlIzDHBd6CqIMRQWW9Af1LHDDTuFjfDsvna0nEuDSYJmNyz
# NB10jpbg0lhvkT1AzfX2TLITSXwS8D+mBzGCWMM/wTpciWBV/pbjSazbzoKvRrNo
# DV/u9omOM2Eawyo5JJJdNkM2d8qzkQ0bRuRd4HarmGunSouyb9NY7egWN5E5lUc3
# a2AROzAdHdYpObpCOdeAY2P5XqtJkk79aROpzw16wCjdSn8qMzCBzR7rvH2WVkvF
# HLIxZQET1yhPb6lRmpgBQNnzidHV2Ocxjc8wNiIDzgbDkmlx54QPfw7RwQi8p1fy
# 4byhBrTjv568x8NGv3gwb0RbAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU8huhNbETDU+ZWllL4DNMPCijEU4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMjkyMzAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAIjmD9IpQVvfB1QehvpC
# Ge7QeTQkKQ7j3bmDMjwSqFL4ri6ae9IFTdpywn5smmtSIyKYDn3/nHtaEn0X1NBj
# L5oP0BjAy1sqxD+uy35B+V8wv5GrxhMDJP8l2QjLtH/UglSTIhLqyt8bUAqVfyfp
# h4COMRvwwjTvChtCnUXXACuCXYHWalOoc0OU2oGN+mPJIJJxaNQc1sjBsMbGIWv3
# cmgSHkCEmrMv7yaidpePt6V+yPMik+eXw3IfZ5eNOiNgL1rZzgSJfTnvUqiaEQ0X
# dG1HbkDv9fv6CTq6m4Ty3IzLiwGSXYxRIXTxT4TYs5VxHy2uFjFXWVSL0J2ARTYL
# E4Oyl1wXDF1PX4bxg1yDMfKPHcE1Ijic5lx1KdK1SkaEJdto4hd++05J9Bf9TAmi
# u6EK6C9Oe5vRadroJCK26uCUI4zIjL/qG7mswW+qT0CW0gnR9JHkXCWNbo8ccMk1
# sJatmRoSAifbgzaYbUz8+lv+IXy5GFuAmLnNbGjacB3IMGpa+lbFgih57/fIhamq
# 5VhxgaEmn/UjWyr+cPiAFWuTVIpfsOjbEAww75wURNM1Imp9NJKye1O24EspEHmb
# DmqCUcq7NqkOKIG4PVm3hDDED/WQpzJDkvu4FrIbvyTGVU01vKsg4UfcdiZ0fQ+/
# V0hf8yrtq9CkB8iIuk5bBxuPMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAQEbHQG/1crJ3IAAAAABAQwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIH0GbDDy7KqKLHdReMEIx6sk
# 02wK75LsKucMjH/qEpPJMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAM5Mq/2p1fh6zYCor3NC8BCFqynsxLExKKvtR5DUNXDxMErfjdID6cRrR
# yZ8kBQQ0irb+wM0n3uXHlAl+RPex3T7dbt1lpDu+XdeuZDC7xO7ONk57q5Yhymsd
# CHnzQdScFswfHrpKXhaMoftIArsBzDLuz8J1OmQLznCuyFKLScd4R721yW/w9Cdn
# 04P+3jX5+twGMsEELUZeainrb3oU7iDoWiLrOfu/tk7KKsFB4q1E8iXM1H1TXZg1
# t7WVlK5sgeI/ezb4TK14kcjYYfjffONxfxq83/ZlcQ3AsvKjrErTDMFQAo6UZyIV
# Kj3BXfaqKK32bn90mTL/Nd3hgFy/RaGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCk+hzUaXaTuwZzCmdPblSlQprVJRHLrdOSWx9CFWaAUQIGaBKxZdOV
# GBMyMDI1MDUxNDA5MTkwOS42OTJaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046REMwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAgO7HlwAOGx0ygABAAACAzANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNTAxMzAxOTQy
# NDZaFw0yNjA0MjIxOTQyNDZaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046REMwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQChl0MH5wAnOx8Uh8RtidF0J0yaFDHJYHTpPvRR16X1
# KxGDYfT8PrcGjCLCiaOu3K1DmUIU4Rc5olndjappNuOgzwUoj43VbbJx5PFTY/a1
# Z80tpqVP0OoKJlUkfDPSBLFgXWj6VgayRCINtLsUasy0w5gysD7ILPZuiQjace5K
# xASjKf2MVX1qfEzYBbTGNEijSQCKwwyc0eavr4Fo3X/+sCuuAtkTWissU64k8rK6
# 0jsGRApiESdfuHr0yWAmc7jTOPNeGAx6KCL2ktpnGegLDd1IlE6Bu6BSwAIFHr7z
# OwIlFqyQuCe0SQALCbJhsT9y9iy61RJAXsU0u0TC5YYmTSbEI7g10dYx8Uj+vh9I
# nLoKYC5DpKb311bYVd0bytbzlfTRslRTJgotnfCAIGMLqEqk9/2VRGu9klJi1j9n
# VfqyYHYrMPOBXcrQYW0jmKNjOL47CaEArNzhDBia1wXdJANKqMvJ8pQe2m8/ciby
# DM+1BVZquNAov9N4tJF4ACtjX0jjXNDUMtSZoVFQH+FkWdfPWx1uBIkc97R+xRLu
# PjUypHZ5A3AALSke4TaRBvbvTBYyW2HenOT7nYLKTO4jw5Qq6cw3Z9zTKSPQ6D5l
# yiYpes5RR2MdMvJS4fCcPJFeaVOvuWFSQ/EGtVBShhmLB+5ewzFzdpf1UuJmuOQT
# TwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFLIpWUB+EeeQ29sWe0VdzxWQGJJ9MB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQCQEMbesD6TC08R0oYCdSC452AQrGf/O89G
# Q54CtgEsbxzwGDVUcmjXFcnaJSTNedBKVXkBgawRonP1LgxH4bzzVj2eWNmzGIwO
# 1FlhldAPOHAzLBEHRoSZ4pddFtaQxoabU/N1vWyICiN60It85gnF5JD4MMXyd6pS
# 8eADIi6TtjfgKPoumWa0BFQ/aEzjUrfPN1r7crK+qkmLztw/ENS7zemfyx4kGRgw
# Y1WBfFqm/nFlJDPQBicqeU3dOp9hj7WqD0Rc+/4VZ6wQjesIyCkv5uhUNy2LhNDi
# 2leYtAiIFpmjfNk4GngLvC2Tj9IrOMv20Srym5J/Fh7yWAiPeGs3yA3QapjZTtfr
# 7NfzpBIJQ4xT/ic4WGWqhGlRlVBI5u6Ojw3ZxSZCLg3vRC4KYypkh8FdIWoKirji
# dEGlXsNOo+UP/YG5KhebiudTBxGecfJCuuUspIdRhStHAQsjv/dAqWBLlhorq2OC
# aP+wFhE3WPgnnx5pflvlujocPgsN24++ddHrl3O1FFabW8m0UkDHSKCh8QTwTkYO
# wu99iExBVWlbYZRz2qOIBjL/ozEhtCB0auKhfTLLeuNGBUaBz+oZZ+X9UAECoMhk
# ETjb6YfNaI1T7vVAaiuhBoV/JCOQT+RYZrgykyPpzpmwMNFBD1vdW/29q9nkTWoE
# hcEOO0L9NzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkRDMDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQDN
# rxRX/iz6ss1lBCXG8P1LFxD0e6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA685SVTAiGA8yMDI1MDUxMzIzMjA1
# M1oYDzIwMjUwNTE0MjMyMDUzWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDrzlJV
# AgEAMAcCAQACAhQhMAcCAQACAhIxMAoCBQDrz6PVAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAIatFdQGyFjXtsCFG46bK62pAT5N+cdvokES3Se5v6S8itdJ
# ZZK24bgnvK1h+vtqQyYy+3to6XcytqOKd4MnqF9sBDkQw1Oxwrw5I6GD4DPDHzmr
# 00bxhsddqhP9FG2CPETboX6hX3X3t7PinWnOhnRB7JdsmqL9oWPLS82M46r1avz4
# MuD7ixa6Rp+doDBfmniLos8Fq1Z0E3bUQp6nQf6GaMJaqF4WW5sHbs+i+MDy13j0
# i4iaSAPX23d3SQfqRtkxIB53jVMWziwZ9PFf/ZSaGqIyPI7o7bqyzb/bvGtur5u7
# m0OX6fmI+/8vNFHO0wh4tyimO7M+PdB/RBTcB54xggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAgO7HlwAOGx0ygABAAACAzAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCA9fvkADcJgK33g6Wei4t/uNFZOq0oxKMmEe3xAdaLE3TCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIEsD3RtxlvaTxFOZZnpQw0DksPmV
# duo5SyK9h9w++hMtMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAIDux5cADhsdMoAAQAAAgMwIgQgTrJAuh3T5m6hlleyqxz4eUHxL9L0
# jlkEN8Ue4wAAq4EwDQYJKoZIhvcNAQELBQAEggIASzwOOR/BQzdlt4JS6v+C87cn
# HU5CJAlmpwFz057cEn8jXGstU21y9tPQUH89AGPEWHDTOMMViuis2qvIeknYB+r/
# cjiHi8ZBLzv/jCwNV6yaP/8Mw8oWWr7Wy5SZKfPEm5bt1LHO/TpJRLEGD+tCifP/
# tbsMzQwU0S0jOEteScH458FMQUUNZE9vwp7Xy+jBnDS8gSVsjMOwiQgFVnZDkYQL
# TN0SCY4vyFU23K0Dh/4HpnIXQfgYVRT0YukK35qgmA0QTtc/qhAKD7WxQoqj5THJ
# weWmcl2UzRECnajQgZjgZMU9tWlyGlEV7XtGHCKHi0pnWgWKNaBFkPzNomdzgTD2
# NydhPLViuU9pU/THs3DWywABkGcO1uUYknE5TJcglgjAres9YveVSjzyge+tlTqd
# IxgKDdC1z+6wFA2x9laZgJT7e6mJCOzYDfhTOAchUghsehcSdyiaNdPF/wR3pq2h
# jRGrZ0+BMm5s2EG/bnmiJU+i3Hj5XTtqST2x9t9ccY/Gnif85sCUEImPEofCe35n
# jSCwwoPiNZRnBn/C5Ts+peHqU3ZK/LMVz8b1XirHIzNZWHz53da8rQRuklZ3Emoy
# sGXYexgUzgypvwovkige4k+CaOmosrs9JzjZjRB7cXkesslO8fNp2RCDX4VFCZOi
# YW2Dc0bDkfy9aGxvbDg=
# SIG # End signature block
