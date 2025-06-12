# Logger.ps1 - Centralized logging functions for the Azure Function

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARN] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" -ForegroundColor Red
}

function Write-LogDebug {
    param([string]$Message)
    if ($env:LOG_LEVEL -eq "Debug") {
        Write-Host "[DEBUG] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" -ForegroundColor Cyan
    }
}