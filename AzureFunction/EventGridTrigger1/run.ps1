param($eventGridEvent, $TriggerMetadata)

# Log the full event structure with better formatting
Write-Host "=== Event Grid Event Data ==="
$eventGridEvent | ConvertTo-Json -Depth 10 | Write-Host

# Log specific properties if they exist
if ($eventGridEvent.data) {
    Write-Host "=== Event Data ==="
    $eventGridEvent.data | ConvertTo-Json -Depth 10 | Write-Host
}

# Log the trigger metadata
Write-Host "=== Trigger Metadata ==="
$TriggerMetadata | ConvertTo-Json -Depth 10 | Write-Host

# If you need to access specific properties from the payload
if ($eventGridEvent.data.payload) {
    Write-Host "=== Payload Details ==="
    $eventGridEvent.data.payload | Out-String | Write-Host
}