# End-to-end validation test for the modular Azure Function
# This script tests the complete flow from event reception to action execution

Write-Host "=== Drasi RBAC Automation Validation Test ==="

try {
    # Test 1: Module Loading
    Write-Host "`n[TEST 1] Loading modules..."
    $functionRoot = $PSScriptRoot
    . (Join-Path $functionRoot "ActionHandlers.ps1")
    . (Join-Path $functionRoot "EventProcessor.ps1")
    Write-Host "✅ Modules loaded successfully"
    
    # Test 2: Configuration Loading
    Write-Host "`n[TEST 2] Loading configuration..."
    $configPath = Join-Path $functionRoot "config.json"
    $configManager = [ConfigurationManager]::new($configPath)
    $roleCount = $configManager.Config.roleActions.Count
    $actionCount = $configManager.Config.actionConfiguration.Count
    Write-Host "✅ Configuration loaded: $roleCount roles, $actionCount actions"
    
    # Test 3: Event Parsing
    Write-Host "`n[TEST 3] Testing event parsing..."
    $testEvent = @{
        type = "Drasi.ChangeEvent"
        data = @{
            payload = @{
                op = "i"
                after = @{
                    properties = @{
                        requestbody = '{"Properties":{"RoleDefinitionId":"/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4","PrincipalId":"test-principal","Scope":"/subscriptions/test-subscription"}}'
                    }
                    correlationId = "test-correlation-id"
                    timestamp = "2024-01-01T00:00:00Z"
                    callerIpAddress = "203.0.113.1"
                }
            }
        }
    }
    
    $parsedEvent = [EventParser]::ParseDrasiEvent($testEvent)
    if ($parsedEvent.isValid) {
        Write-Host "✅ Event parsing successful"
        Write-Host "   - Role: $($configManager.GetRoleName($parsedEvent.roleDefinitionId))"
        Write-Host "   - Operation: $($parsedEvent.operationType)"
        Write-Host "   - Scope: $($parsedEvent.scope)"
    } else {
        throw "Event parsing failed"
    }
    
    # Test 4: Action Resolution
    Write-Host "`n[TEST 4] Testing action resolution..."
    $actions = $configManager.GetActionsForRole($parsedEvent.roleDefinitionId, $parsedEvent.operationType)
    if ($actions.Count -gt 0) {
        Write-Host "✅ Actions resolved: $($actions -join ', ')"
    } else {
        throw "No actions found for role"
    }
    
    # Test 5: Dry Run Execution
    Write-Host "`n[TEST 5] Testing dry run execution..."
    
    # Temporarily enable dry run
    $originalDryRun = $configManager.Config.global.dryRun
    $configManager.Config.global.dryRun = $true
    
    $orchestrator = [ActionOrchestrator]::new($configManager)
    $results = $orchestrator.ProcessEvent($parsedEvent)
    
    # Restore original setting
    $configManager.Config.global.dryRun = $originalDryRun
    
    $successCount = ($results | Where-Object { $_.success }).Count
    if ($successCount -gt 0) {
        Write-Host "✅ Dry run execution successful: $successCount/$($results.Count) actions completed"
        foreach ($result in $results) {
            $status = if ($result.success) { "SUCCESS" } else { "FAILED" }
            Write-Host "   - [$status] $($result.action): $($result.message)"
        }
    } else {
        throw "No actions executed successfully"
    }
    
    # Test 6: Delete Operation
    Write-Host "`n[TEST 6] Testing delete operation..."
    $deleteEvent = @{
        type = "Drasi.ChangeEvent"
        data = @{
            payload = @{
                op = "d"
                before = @{
                    properties = @{
                        requestbody = '{"Properties":{"RoleDefinitionId":"/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4","PrincipalId":"test-principal","Scope":"/subscriptions/test-subscription"}}'
                    }
                    correlationId = "test-correlation-id"
                    timestamp = "2024-01-01T00:00:00Z"
                }
            }
        }
    }
    
    $parsedDeleteEvent = [EventParser]::ParseDrasiEvent($deleteEvent)
    $deleteActions = $configManager.GetActionsForRole($parsedDeleteEvent.roleDefinitionId, $parsedDeleteEvent.operationType)
    
    if ($deleteActions.Count -gt 0) {
        Write-Host "✅ Delete operation actions resolved: $($deleteActions -join ', ')"
    } else {
        Write-Host "⚠️  No delete actions configured (this may be intentional)"
    }
    
    # Test 7: Invalid Event Handling
    Write-Host "`n[TEST 7] Testing invalid event handling..."
    $invalidEvent = @{
        type = "NotDrasi.Event"
        data = @{}
    }
    
    $parsedInvalid = [EventParser]::ParseDrasiEvent($invalidEvent)
    if (-not $parsedInvalid.isValid) {
        Write-Host "✅ Invalid event correctly rejected"
    } else {
        throw "Invalid event was incorrectly accepted"
    }
    
    # Test 8: Unknown Role Handling
    Write-Host "`n[TEST 8] Testing unknown role handling..."
    $unknownRoleEvent = @{
        type = "Drasi.ChangeEvent"
        data = @{
            payload = @{
                op = "i"
                after = @{
                    properties = @{
                        requestbody = '{"Properties":{"RoleDefinitionId":"/providers/Microsoft.Authorization/roleDefinitions/unknown-role-id","PrincipalId":"test","Scope":"/subscriptions/test"}}'
                    }
                    correlationId = "test-correlation-id"
                    timestamp = "2024-01-01T00:00:00Z"
                }
            }
        }
    }
    
    $parsedUnknown = [EventParser]::ParseDrasiEvent($unknownRoleEvent)
    $unknownActions = $configManager.GetActionsForRole($parsedUnknown.roleDefinitionId, $parsedUnknown.operationType)
    
    if ($unknownActions.Count -eq 0) {
        Write-Host "✅ Unknown role correctly ignored"
    } else {
        throw "Unknown role incorrectly processed"
    }
    
    Write-Host "`n🎉 ALL TESTS PASSED!"
    Write-Host "`nThe modular Azure Function is ready for deployment."
    Write-Host "- Enable dry run mode for safe testing in production"
    Write-Host "- Monitor function logs for automation results"
    Write-Host "- See README.md for deployment instructions"
    
} catch {
    Write-Error "`n❌ TEST FAILED: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}