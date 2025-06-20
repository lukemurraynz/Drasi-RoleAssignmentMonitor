
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
Lists entities from groups or get entity from groups by key
.Description
Lists entities from groups or get entity from groups by key
.Link
https://learn.microsoft.com/powershell/module/az.resources/get-azadgroup
#>
function Get-AzADGroup {
    [OutputType([Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphGroup])]
    [CmdletBinding(DefaultParameterSetName='EmptyParameterSet', PositionalBinding=$false)]
    param(
        [Parameter(ParameterSetName='ObjectIdParameterSet', Mandatory)]
        [System.Guid]
        # key: id of group
        ${ObjectId},

        [Parameter(ParameterSetName='SearchStringParameterSet', Mandatory)]
        [System.String]
        [Alias("SearchString")]
        # Used to find groups that begin with the provided string.
        ${DisplayNameStartsWith},

        [Parameter(ParameterSetName='DisplayNameParameterSet', Mandatory)]
        [System.String]
        # The display name of the group.
        ${DisplayName},

        [Parameter()]
        [AllowEmptyCollection()]
        [System.String[]]
        # Expand related entities
        ${Expand},

        [Parameter()]
        [AllowEmptyCollection()]
        [System.String[]]
        # Select properties to be returned
        ${Select},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Query')]
        [System.Management.Automation.SwitchParameter]
        # Include count of items
        ${Count},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [System.String]
        # Filter items by property values, for more detail about filter query please see: https://learn.microsoft.com/en-us/graph/filter-query-parameter
        ${Filter},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [AllowEmptyCollection()]
        [System.String[]]
        # Order items by property values
        ${Orderby},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [System.String]
        # Search items by search phrases
        ${Search},

        [Parameter()]
        [System.String]
        # Indicates the requested consistency level.
        # Documentation URL: https://developer.microsoft.com/en-us/office/blogs/microsoft-graph-advanced-queries-for-directory-objects-are-now-generally-available/
        ${ConsistencyLevel},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [Parameter(ParameterSetName='SearchStringParameterSet')]
        [Parameter(ParameterSetName='DisplayNameParameterSet')]
        [System.UInt64]
        # Gets only the first 'n' objects.
        ${First},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [Parameter(ParameterSetName='SearchStringParameterSet')]
        [Parameter(ParameterSetName='DisplayNameParameterSet')]
        [System.UInt64]
        # Ignores the first 'n' objects and then gets the remaining objects.
        ${Skip},

        [Parameter(HelpMessage = "Append properties selected with default properties when this switch is on, only works with parameter '-Select'.")]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Body')]
        [System.Management.Automation.SwitchParameter]
        ${AppendSelected},

        [Parameter(ParameterSetName='EmptyParameterSet')]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Runtime')]
        [System.String]
        # Specifies a count of the total number of items in a collection.
        # By default, this variable will be set in the global scope.
        ${CountVariable},

        [Parameter()]
        [Alias("AzContext", "AzureRmContext", "AzureCredential")]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Category('Azure')]
        [System.Management.Automation.PSObject]
        # The credentials, account, tenant, and subscription used for communication with Azure.
        ${DefaultProfile},

        [Parameter(DontShow)]
        [System.Management.Automation.SwitchParameter]
        # Wait for .NET debugger to attach
        ${Break},

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be appended to the front of the pipeline
        ${HttpPipelineAppend},

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Runtime.SendAsyncStep[]]
        # SendAsync Pipeline Steps to be prepended to the front of the pipeline
        ${HttpPipelinePrepend},

        [Parameter(DontShow)]
        [System.Uri]
        # The URI for the proxy server to use
        ${Proxy},

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        # Credentials for a proxy server to use for the remote call
        ${ProxyCredential},

        [Parameter(DontShow)]
        [System.Management.Automation.SwitchParameter]
        # Use the default credentials for the proxy
        ${ProxyUseDefaultCredentials}
    )

    process {
        if ($PSBoundParameters['AppendSelected'] -and $PSBoundParameters['Select']) {
            $PSBoundParameters['Select'] += @('DisplayName', 'Id', 'DeletedDateTime', 'SecurityEnabled', 'MailEnabled', 'MailNickname', 'Description')
            $null = $PSBoundParameters.Remove('AppendSelected')
        }

        if ($PSBoundParameters.ContainsKey('ObjectId')) {
            $PSBOundParameters['Id'] = $PSBoundParameters['ObjectId']
            $null = $PSBoundParameters.Remove('ObjectId')
        }

        switch ($PSCmdlet.ParameterSetName) {
            'SearchStringParameterSet' {
                $PSBOundParameters['Filter'] = "startsWith(displayName, '$($PSBOundParameters['DisplayNameStartsWith'])')"
                $null = $PSBoundParameters.Remove('DisplayNameStartsWith')
                break
            }
            'DisplayNameParameterSet' {
                $PSBOundParameters['Filter'] = "displayName eq '$($PSBOundParameters['DisplayName'])'"
                $null = $PSBoundParameters.Remove('DisplayName')
                break
            }
            default {
                break
            }
        }

        Az.MSGraph.internal\Get-AzAdGroup @PSBoundParameters
    }

}

# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD0TnxArb9mpJU6
# T5Dht4AQZsR3h5oAOlYCjLJ76fWXtaCCDXYwggX0MIID3KADAgECAhMzAAAEBGx0
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINaLdQn0CwK065y4tKXxP0jY
# wLFlWRoCP55lDcpZY0dMMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAe9nfGrK1WG25gFFbF3a5TdwYil2CkZKJclmrarAcz+ZRWPr9aKpi2tSC
# /zUckXWeUrYqLLL4XJzdYYckvNylHVY0R7SXyxn6OvFJcoCLE0RxSSBfFoNh66yU
# On43Jx2B8rXGccz0LnVWzoJJ6kUaKCut+8SKABywKXGXYfPKYx5+9rDYJgGoP5jL
# omj/5xvKj80fpquFkK88zWuH0CoSTJPjAZaBJ+IgJUrwGHLor5ic3q3FYutkXjiJ
# Ue4SbO+WV3p/EJ9hoTZ8x9AJRya8jpZezzs2QJeTwE6WNX8RPAhltFJuYm6FaepK
# 485gscamV1s1ha9You4f3QLFXkoKXaGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBGT7TovQCrjSc71sTYYxjTmqRR/MIRhFaqTCxCuw77QgIGaBKyIjbX
# GBMyMDI1MDUxNDA5MTkwOS45ODJaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046N0YwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAgbXvFE4mCPsLAABAAACBjANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNTAxMzAxOTQy
# NTBaFw0yNjA0MjIxOTQyNTBaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046N0YwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDpRIWbIM3Rlr397cjHaYx85l7I+ZVWGMCBCM911BpU
# 6+IGWCqksqgqefZFEjKzNVDYC9YcgITAz276NGgvECm4ZfNv/FPwcaSDz7xbDbsO
# oxbwQoHUNRro+x5ubZhT6WJeU97F06+vDjAw/Yt1vWOgRTqmP/dNr9oqIbE5oCLY
# dH3wI/noYmsJVc7966n+B7UAGAWU2se3Lz+xdxnNsNX4CR6zIMVJTSezP/2STNcx
# JTu9k2sl7/vzOhxJhCQ38rdaEoqhGHrXrmVkEhSv+S00DMJc1OIXxqfbwPjMqEVp
# 7K3kmczCkbum1BOIJ2wuDAbKuJelpteNZj/S58NSQw6khfuJAluqHK3igkS/Oux4
# 9qTP+rU+PQeNuD+GtrCopFucRmanQvxISGNoxnBq3UeDTqphm6aI7GMHtFD6DOjJ
# lllH1gVWXPTyivf+4tN8TmO6yIgB4uP00bH9jn/dyyxSjxPQ2nGvZtgtqnvq3h3T
# RjRnkc+e1XB1uatDa1zUcS7r3iodTpyATe2hgkVX3m4DhRzI6A4SJ6fbJM9isLH8
# AGKcymisKzYupAeFSTJ10JEFa6MjHQYYohoCF77R0CCwMNjvE4XfLHu+qKPY8GQf
# sZdigQ9clUAiydFmVt61hytoxZP7LmXbzjD0VecyzZoL4Equ1XszBsulAr5Ld2Kw
# cwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFO0wsLKdDGpT97cx3Iymyo/SBm4SMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQB23GZOfe9ThTUvD29i4t6lDpxJhpVRMme+
# UbyZhBFCZhoGTtjDdphAArU2Q61WYg3YVcl2RdJm5PUbZ2bA77zk+qtLxC+3dNxV
# sTcdtxPDSSWgwBHxTj6pCmoDNXolAYsWpvHQFCHDqEfAiBxX1dmaXbiTP1d0Xffv
# gR6dshUcqaH/mFfjDZAxLU1s6HcVgCvBQJlJ7xEG5jFKdtqapKWcbUHwTVqXQGbI
# lHVClNJ3yqW6Z3UJH/CFcYiLV/e68urTmGtiZxGSYb4SBSPArTrTYeHOlQIj/7lo
# VWmfWX2y4AGV/D+MzyZMyvFw4VyL0Vgq96EzQKyteiVeBaVEjxQKo3AcPULRF4Uz
# z98P2tCM5XbFZ3Qoj9PLg3rgFXr0oJEhfh2tqUrhTJd13+i4/fek9zWicoshlwXg
# Fu002ZWBVzASEFuqED48qyulZ/2jGJBcta+Fdk2loP2K3oSj4PQQe1MzzVZO52AX
# O42MHlhm3SHo3/RhQ+I1A0Ny+9uAehkQH6LrxkrVNvZG4f0PAKMbqUcXG7xznKJ0
# x0HYr5ayWGbHKZRcObU+/34ZpL9NrXOedVDXmSd2ylKSl/vvi1QwNJqXJl/+gJkQ
# EetqmHAUFQkFtemi8MUXQG2w/RDHXXwWAjE+qIDZLQ/k4z2Z216tWaR6RDKHGkwe
# CoDtQtzkHTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
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
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdGMDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQAE
# a0f118XHM/VNdqKBs4QXxNnN96CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA685TETAiGA8yMDI1MDUxMzIzMjQw
# MVoYDzIwMjUwNTE0MjMyNDAxWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDrzlMR
# AgEAMAcCAQACAileMAcCAQACAhNfMAoCBQDrz6SRAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAB/eYvDrdxUOHvixwq7f6+3U9BVTPYRcNmwjRsWr8hTfjhAA
# YE0v4aWk26NgCcDhmteTH7h52w6rpfWDbXWTdgL4Ec3NBK1nGLQpswO51s/CY30R
# o5Fe2lf+gCN111M4wtpr89hYotAMBvo/CaMGWm3hwVgC8tcmA4/Z97ZGzCxq8FKi
# B9P2vi8WifAVbkeTCUW79htwuoi50vip2H8NE+jygoTIcWaZex/+WP3e64DD+tNm
# 9xWQFZgMqEpZsRbi/c8xdhVXo7kyrI5DeA6eYN9LZl+4DnpbiFsecQc5mzuV1SL1
# zRz4YFhWNCgOm64bJSvLRJLhVT1RFaZW8D/UAu4xggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAgbXvFE4mCPsLAABAAACBjAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCCi7N9wL3800V//aR5rzZ8q/KNg63/S85+SX9Xh2v0GHTCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIODo9ZSIkZ6dVtKT+E/uZx2WAy7K
# iXM5R1JIOhNJf0vSMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAIG17xROJgj7CwAAQAAAgYwIgQgxZfKn5hFPe8bUCrsiGj1aEPn5sKC
# dPbelOe9FWt/r7swDQYJKoZIhvcNAQELBQAEggIAUlCRk5j3AkwNAfP5gV+heCYJ
# iWePpNWvmk9MsthN0tg3ToQqt3CE8tM0RPohzfa/XgvMmRfc7gWvc1C6TuJXii43
# mIInvduBfbu+3Tsz2PItVS+mpDqMkfsf/U4y37ltZ15CwL/CWz5j1CNMmltgcDS0
# wMJ8Gzc/Q9IUzQmw0v3u4SXEKlo4cb69E1pVaPoviFpA5hGXluhlv52gdPty2AeL
# iknoZz4Yc4eZOF9taHCZ58/OJ/G+Ctfr9QakPZ17O2yX15ZgTXlKKuTMoygZHJdp
# YrYh+wLNGbeDKQ2Gd5fQCvKuE1jNxuZMTu55cZ/rcZorhWATVIH/kZlvco/DzhUA
# QT7HoiIEyzBewS/j86UZX79uaKfyc46MTN109vnZtMP4ELBV4zfrwTG2guCV82kz
# Bmz0FYqmze4I1neU+l5QYQEk4DGjsgysQ+SPhJGMNUmdcakCZGbZNL0MrSSjIQMh
# UbXTA99Ny2gqqeJRUdhMK5CJ8fwpwYwN0SaddXXeyas4R0FBGltnM3zoB+GdI7g0
# +o1D07rHUzBU0TYsbqCnWwF+yPR8XMjzl+zoGAjDuaWgHv1NeGccl0xVYBPyIOJP
# O5onit95XE3V0rywpdGBTt+UVU0sa2EebGLx8IyGfeKFuXNO6QSQxIxkMFG2UTVl
# BWNX7hlqUKknuGjWFvQ=
# SIG # End signature block
