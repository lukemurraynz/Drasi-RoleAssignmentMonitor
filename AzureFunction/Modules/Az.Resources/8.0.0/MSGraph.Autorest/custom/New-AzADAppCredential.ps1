
# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
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
Creates key credentials or password credentials for an application.
.Description
Creates key credentials or password credentials for an application.
.Link
https://learn.microsoft.com/powershell/module/az.resources/new-azadappcredential
#>

function New-AzADAppCredential {
    [OutputType([Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphKeyCredential], [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPasswordCredential])]
    [CmdletBinding(DefaultParameterSetName = 'ApplicationObjectIdWithPasswordParameterSet', PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithPasswordParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithCertValueParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithKeyCredentialParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "The object Id of application.")]
        [Alias('Id')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        ${ObjectId},

        [Parameter(ParameterSetName = 'ApplicationIdWithCertValueParameterSet', Mandatory, HelpMessage = "The application Id.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithPasswordParameterSet', Mandatory, HelpMessage = "The application Id.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithKeyCredentialParameterSet', Mandatory, HelpMessage = "The application Id.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "The application Id.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.Guid]
        ${ApplicationId},

        [Parameter(ParameterSetName = 'DisplayNameWithPasswordParameterSet', Mandatory, HelpMessage = "The display name of application.")]
        [Parameter(ParameterSetName = 'DisplayNameWithCertValueParameterSet', Mandatory, HelpMessage = "The display name of application.")]
        [Parameter(ParameterSetName = 'DisplayNameWithKeyCredentialParameterSet', Mandatory, HelpMessage = "The display name of application.")]
        [Parameter(ParameterSetName = 'DisplayNameWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "The display name of application.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        ${DisplayName},

        [Parameter(ParameterSetName = 'ApplicationObjectWithPasswordParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The application object, could be used as pipeline input.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithCertValueParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The application object, could be used as pipeline input.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithKeyCredentialParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The application object, could be used as pipeline input.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithPasswordCredentialParameterSet', Mandatory, ValueFromPipeline, HelpMessage = "The application object, could be used as pipeline input.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphApplication]
        ${ApplicationObject},

        [Parameter(ParameterSetName = 'ApplicationObjectIdWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Parameter(ParameterSetName = 'DisplayNameWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithCertValueParameterSet', Mandatory, HelpMessage = "The value of the 'asymmetric' credential type. It represents the base 64 encoded certificate.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        ${CertValue},

        [Parameter(ParameterSetName = 'ApplicationObjectIdWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the application.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the application.")]
        [Parameter(ParameterSetName = 'DisplayNameWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the application.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithKeyCredentialParameterSet', Mandatory, HelpMessage = "key credentials associated with the application.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphKeyCredential[]]
        ${KeyCredentials},

        [Parameter(ParameterSetName = 'ApplicationObjectIdWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the application.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the application.")]
        [Parameter(ParameterSetName = 'DisplayNameWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the application.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithPasswordCredentialParameterSet', Mandatory, HelpMessage = "Password credentials associated with the application.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential[]]
        ${PasswordCredentials},

        [Parameter(ParameterSetName = 'ApplicationObjectIdWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'DisplayNameWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithCertValueParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'DisplayNameWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithPasswordParameterSet', HelpMessage = "The effective start date of the credential usage. The default start date value is today. For an 'asymmetric' type credential, this must be set to on or after the date that the X509 certificate is valid from.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.DateTime]
        ${StartDate},

        [Parameter(ParameterSetName = 'ApplicationObjectIdWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'DisplayNameWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithCertValueParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'ApplicationIdWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'DisplayNameWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithPasswordParameterSet', HelpMessage = "The effective end date of the credential usage. The default end date value is one year from today. For an 'asymmetric' type credential, this must be set to on or before the date that the X509 certificate is valid.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.DateTime]
        ${EndDate},

        [Parameter(ParameterSetName = 'ApplicationObjectIdWithCertValueParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'ApplicationIdWithCertValueParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'DisplayNameWithCertValueParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithCertValueParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'ApplicationObjectIdWithPasswordParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'ApplicationIdWithPasswordParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'DisplayNameWithPasswordParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(ParameterSetName = 'ApplicationObjectWithPasswordParameterSet', HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Parameter(HelpMessage = "Custom Key Identifier. The format should be base64: ```$Bytes=[System.Text.Encoding]::Unicode.GetBytes(`$key);`$key=[Convert]::ToBase64String(`$Bytes)``")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.String]
        ${CustomKeyIdentifier},

        [Parameter()]
        [Alias("AzContext", "AzureRmContext", "AzureCredential")]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Azure')]
        [System.Management.Automation.PSObject]
        # The credentials, account, tenant, and subscription used for communication with Azure.
        ${DefaultProfile},
    
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        # Wait for .NET debugger to attach
        ${Break},
    
        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be appended to the front of the pipeline
        ${HttpPipelineAppend},
    
        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be prepended to the front of the pipeline
        ${HttpPipelinePrepend},
    
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Uri]
        # The URI for the proxy server to use
        ${Proxy},
    
        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Management.Automation.PSCredential]
        # Credentials for a proxy server to use for the remote call
        ${ProxyCredential},
    
        [Parameter(DontShow)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.Management.Automation.SwitchParameter]
        # Use the default credentials for the proxy
        ${ProxyUseDefaultCredentials}
    )
    
    process {
        if (!$PSBoundParameters['PasswordCredentials'] -and !$PSBoundParameters['KeyCredentials'] ) {
            if ($PSBoundParameters['CertValue']) {
                $credential = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphKeyCredential" `
                                         -Property @{'Key' = ([System.Convert]::FromBase64String($PSBoundParameters['CertValue']));
                                            'Usage'       = 'Verify'; 
                                            'Type'        = 'AsymmetricX509Cert'
                                         }
            } else {
                $credential = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential"
            }
            if ($PSBoundParameters['CustomKeyIdentifier']) {
                $credential.CustomKeyIdentifier = [System.Convert]::FromBase64String($PSBoundParameters['CustomKeyIdentifier'])
                $null = $PSBoundParameters.Remove('CustomKeyIdentifier')
            }
            if ($PSBoundParameters['StartDate']) {
                $credential.StartDateTime = $PSBoundParameters['StartDate']
                $null = $PSBoundParameters.Remove('StartDate')
            }
            if ($PSBoundParameters['EndDate']) {
                $credential.EndDateTime = $PSBoundParameters['EndDate']
                $null = $PSBoundParameters.Remove('EndDate')
            }
            $credential.KeyId = (New-Guid).ToString()
            if ($PSBoundParameters['CertValue']) {
                $kc = $credential
                $null = $PSBoundParameters.Remove('CertValue')
            } else {
                $pc = $credential
            }
        } elseif ($PSBoundParameters['PasswordCredentials']) {
            $pc = $PSBoundParameters['PasswordCredentials']
            $null = $PSBoundParameters.Remove('PasswordCredentials')
        } else {
            $kc = $PSBoundParameters['KeyCredentials']
            $null = $PSBoundParameters.Remove('KeyCredentials')
        }

        $param = @{}
        switch ($PSCmdlet.ParameterSetName) {
            { $_ -in 'ApplicationObjectIdWithPasswordParameterSet', 'ApplicationObjectIdWithKeyCredentialParameterSet', 'ApplicationObjectIdWithPasswordCredentialParameterSet', 'ApplicationObjectIdWithCertValueParameterSet'} {
                $id = $PSBoundParameters['ObjectId']
                if ($kc) {
                    $app = Get-AzADApplication -ObjectId $id
                }
                $null = $PSBoundParameters.Remove('ObjectId')
                break
            }
            { $_ -in 'ApplicationIdWithPasswordParameterSet', 'ApplicationIdWithKeyCredentialParameterSet', 'ApplicationIdWithPasswordCredentialParameterSet', 'ApplicationIdWithCertValueParameterSet'} {
                $param['ApplicationId'] = $PSBoundParameters['ApplicationId']
                $app = Get-AzADApplication @param
                if ($app) {
                    $id = $app.Id
                    $null = $PSBoundParameters.Remove('ApplicationId')  
                }
                else {
                    Write-Error "application with application id '$($PSBoundParameters['ApplicationId'])' does not exist."
                    return
                }
                break
            }
            { $_ -in 'DisplayNameWithPasswordParameterSet', 'DisplayNameWithKeyCredentialParameterSet', 'DisplayNameWithPasswordCredentialParameterSet', 'DisplayNameWithCertValueParameterSet'} {
                $param['DisplayName'] = $PSBoundParameters['DisplayName']
                [System.Array]$app = Get-AzADApplication @param
                if (0 -eq $app.Count) {
                    Write-Error "application with display name '$($PSBoundParameters['DisPlayName'])' does not exist."
                    return
                }
                elseif (1 -eq $app.Count) {
                    $id = $app[0].Id
                    $null = $PSBoundParameters.Remove('DisplayName')
                }
                else {
                    Write-Error "More than one application found with display name '$($PSBoundParameters['DisplayName'])'. Please use the Get-AzADApplication cmdlet to get the object id of the desired application."
                    return
                }
                break
            }
            { $_ -in 'ApplicationObjectWithPasswordParameterSet', 'ApplicationObjectWithKeyCredentialParameterSet', 'ApplicationObjectWithPasswordCredentialParameterSet', 'ApplicationObjectWithCertValueParameterSet'} {
                $id = $PSBoundParameters['ApplicationObject'].Id
                if ($kc) {
                    $app = Get-AzADApplication -ObjectId $id
                }
                $null = $PSBoundParameters.Remove('ApplicationObject')
                break
            }
            default {
                break
            }
        }  
        if ($pc) {
            $PSBoundParameters['ApplicationId'] = $id
            foreach ($credential in $pc) {
                $PSBoundParameters['PasswordCredential'] = $credential
                Az.MSGraph.internal\Add-AzADApplicationPassword @PSBoundParameters
            }
            $null = $PSBoundParameters.Remove('ApplicationId')
            if ($PSBoundParameters['PasswordCredential']) {
                $null = $PSBoundParameters.Remove('PasswordCredential')
            }
        }
        if ($kc) {
            [System.Array]$kcList = $app.KeyCredentials
            $PSBoundParameters['Id'] = $id
            foreach ($k in $kc) {
                $kcList += $k
            }
            $PSBoundParameters['KeyCredentials'] = $kcList
            Az.MSGraph.internal\Update-AzADApplication @PSBoundParameters
        }
    }
}
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB2j1DcN+UgXgfI
# yUjF68F71xHiVsbalZnP8WhiRAaimaCCDXYwggX0MIID3KADAgECAhMzAAAEBGx0
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKxyMTM28pWGEUM8lucc2GnW
# sex13uYauP7zpbF5QKM4MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAY0nPAv1qypfEeN13WPHiZtaSmhvgPgfDaQr9M8YTQ85mfWfdIJEt6D9C
# b8GNiW1BY+AxAFVwnr36GD68npk9cEDKxppmxLJ3A2SyIP355wX31WFDm3aAvvpU
# 0rrkkhZ2F9rzXgaSBBsfKSO53dg34F6NVF6DU0bqvo/gRd0dP9jYAhxwu82wzjqp
# QZKrKas5umw+lrpG4XW/h4IwPYFahfJ2Al8VW8cWD2upGLeAl23FEa4zWl6aCw4g
# ks2EgOh62MKVsi1dL+kfddM89gq6XFWh3AW4Swpm5JOmzL2JZqOQHxH0Om1upBuX
# Wl3/2USi+wICABvRRAsxT/qaiSKUQaGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCA3ZzM+ZzWctJGEmcnu3qFmqb5YNRbp9Yj2LCMqx7hwSwIGaBKnFKO3
# GBMyMDI1MDUxNDA5MTkxMC45NDlaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAgh4nVhdksfZUgABAAACCDANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNTAxMzAxOTQy
# NTNaFw0yNjA0MjIxOTQyNTNaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC1y3AI5lIz3Ip1nK5BMUUbGRsjSnCz/VGs33zvY0Ne
# shsPgfld3/Z3/3dS8WKBLlDlosmXJOZlFSiNXUd6DTJxA9ik/ZbCdWJ78LKjbN3t
# FkX2c6RRpRMpA8sq/oBbRryP3c8Q/gxpJAKHHz8cuSn7ewfCLznNmxqliTk3Q5LH
# qz2PjeYKD/dbKMBT2TAAWAvum4z/HXIJ6tFdGoNV4WURZswCSt6ROwaqQ1oAYGvE
# ndH+DXZq1+bHsgvcPNCdTSIpWobQiJS/UKLiR02KNCqB4I9yajFTSlnMIEMz/Ni5
# 38oGI64phcvNpUe2+qaKWHZ8d4T1KghvRmSSF4YF5DNEJbxaCUwsy7nULmsFnTaO
# jVOoTFWWfWXvBuOKkBcQKWGKvrki976j4x+5ezAP36fq3u6dHRJTLZAu4dEuOooU
# 3+kMZr+RBYWjTHQCKV+yZ1ST0eGkbHXoA2lyyRDlNjBQcoeZIxWCZts/d3+nf1ji
# SLN6f6wdHaUz0ADwOTQ/aEo1IC85eFePvyIKaxFJkGU2Mqa6Xzq3qCq5tokIHtjh
# ogsrEgfDKTeFXTtdhl1IPtLcCfMcWOGGAXosVUU7G948F6W96424f2VHD8L3FoyA
# I9+r4zyIQUmqiESzuQWeWpTTjFYwCmgXaGOuSDV8cNOVQB6IPzPneZhVTjwxbAZl
# aQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFKMx4vfOqcUTgYOVB9f18/mhegFNMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBRszKJKwAfswqdaQPFiaYB/ZNAYWDa040X
# TcQsCaCua5nsG1IslYaSpH7miTLr6eQEqXczZoqeOa/xvDnMGifGNda0CHbQwtpn
# IhsutrKO2jhjEaGwlJgOMql21r7Ik6XnBza0e3hBOu4UBkMl/LEX+AURt7i7+RTN
# sGN0cXPwPSbTFE+9z7WagGbY9pwUo/NxkGJseqGCQ/9K2VMU74bw5e7+8IGUhM2x
# spJPqnSeHPhYmcB0WclOxcVIfj/ZuQvworPbTEEYDVCzSN37c0yChPMY7FJ+HGFB
# NJxwd5lKIr7GYfq8a0gOiC2ljGYlc4rt4cCed1XKg83f0l9aUVimWBYXtfNebhpf
# r6Lc3jD8NgsrDhzt0WgnIdnTZCi7jxjsIBilH99pY5/h6bQcLKK/E6KCP9E1YN78
# fLaOXkXMyO6xLrvQZ+uCSi1hdTufFC7oSB/CU5RbfIVHXG0j1o2n1tne4eCbNfKq
# UPTE31tNbWBR23Yiy0r3kQmHeYE1GLbL4pwknqaip1BRn6WIUMJtgncawEN33f8A
# YGZ4a3NnHopzGVV6neffGVag4Tduy+oy1YF+shChoXdMqfhPWFpHe3uJGT4GJEiN
# s4+28a/wHUuF+aRaR0cN5P7XlOwU1360iUCJtQdvKQaNAwGI29KOwS3QGriR9F2j
# OGPUAlpeEzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
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
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCN
# kvu0NKcSjdYKyrhJZcsyXOUTNKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA685IADAiGA8yMDI1MDUxMzIyMzY0
# OFoYDzIwMjUwNTE0MjIzNjQ4WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDrzkgA
# AgEAMAcCAQACAhK+MAcCAQACAhNlMAoCBQDrz5mAAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAJh+NvtTcjbtoVg5jNLHH0k81Wa42Pep9aHWFpXBuoqvyoHP
# VQ1KVP6aiSV2Y9R9bXQcNRVcbsdfoDtbhmougMnAXfqJc3Cz8L2kB1hI52iA6PUf
# NgQBlUP7J1MOsFKnA/qbnRQNe2Lig3fEjeQYr1ZZh1olfNOepfc/cT1JhhHKxsDj
# Cx4z76SWZjqTVh1OB1YOQ010s2PCfsw72bD0m/Ovu7CV40eMubOn00ZEUScUIm4A
# TGc842ZcdVvR3QSZpLRNyNBwki1lKCdoQcY3/ONIIl9EUtp6p5Lx0VluuaxWC1am
# MMYuMvBNEJa+0M4fxNzYUY72we90wx5Jo2ZCbtAxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAgh4nVhdksfZUgABAAACCDAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCAj35P06+yVgAMHYycYEVlQx4WbTjgO5uT6Vt/gGtT0ZzCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EII//jm8JHa2W1O9778t9+Ft2Z5Nm
# KqttPk6Q+9RRpmepMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAIIeJ1YXZLH2VIAAQAAAggwIgQggHID5iUiJBKNOXPm5NaXBjcJIUWK
# rluPMs/yF7jvCAYwDQYJKoZIhvcNAQELBQAEggIAKv6GDwZUGoHqL7nKBeTcgIRp
# /BDP19MDjFqERski2gsrgQftJT5rRedbm3REPILg0JwYIKoPt9fmA/RaWhccjcaA
# gHUIMynq1JDimS+hgkj9ZG8uQtk04l9WcQH8ZjpNvarh/R64mcwBptujnMAPeqiH
# BQnI2LBxz2chly8TVwAK97/NYqlOnDUY6f8E6NXpGBDkyMdH/vkC9071rni/gNaA
# q5MSUwmnrsAkNdBQ0a1cyttR5ND5nAz+6qGRoYfBgvSnBElZjLVhE0x6IjtMlTSE
# Ca/seODsNXIzrIlISaZtzAPGj59zclbc5it+wSqxNIQxaomiuEff/oAx977ZH+Ri
# 5N3x7bU632NWZCSPuB5IcqFWQR0I117M97kOvX5k1wnmmm/7P4iz3b+eQnW6g/bR
# 0CvVKzi9QY6MZ/0fD+jtIupF68L/1QmHxph2da9zJdQXF/u+p3C8L2oMJTZmqlIp
# UGnXEnJ9gpt9BlrQH5s9Wx091rjMKWs6OwOc8YALxQMlhWTdwXL3OUv5SFkerKxJ
# Wd+8msPxGnVYouhqaT0yB9QYPpzCxWytdueQaZOMGhsUXg928TweP8NfmmeCPqvK
# E3wxBHWhvWB4DMcJI/Srg5OAaYyDRrzwnC9E6yo+cC8B57weoA/hinOaXkePDbFU
# N8OLP1CPQI/PjOHaG7o=
# SIG # End signature block
